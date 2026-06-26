use std::{
    collections::BTreeSet,
    fs,
    io::{self, BufReader, Read},
    path::{Path, PathBuf},
};

use anyhow::{bail, Context, Result};
use chrono::Utc;
use futures_util::StreamExt;
use sha2::{Digest, Sha256};
use tauri::{AppHandle, Emitter};
use tokio::{fs as tokio_fs, io::AsyncWriteExt};
use tracing::{info, warn};

use super::{
    api::{ensure_trusted_download, http_client, send_download_request},
    model::{ModLoaderInstallProgress, ModLoaderInstalled, ModLoaderPhase, ModLoaderRelease},
    paths::release_cache_dir,
    storage::save_manifest,
};

const INSTALL_EVENT: &str = "modloader-install-progress";

pub async fn install_release(
    app: &AppHandle,
    release: &ModLoaderRelease,
    version_guid: &str,
    install_dir: &Path,
) -> Result<ModLoaderInstalled> {
    let reporter = ProgressReporter::new(app, version_guid, &release.tag, release.asset.size);

    let result: Result<ModLoaderInstalled> = async {
        reporter.emit(ModLoaderPhase::Resolving, 0, None);

        let cache_dir = release_cache_dir(app, &release.tag)?;
        tokio_fs::create_dir_all(&cache_dir)
            .await
            .with_context(|| format!("failed to create {}", cache_dir.display()))?;
        let bundle_path = cache_dir.join(&release.asset.name);

        download_bundle(&bundle_path, release, &reporter).await?;

        let artifacts = read_top_level_entries(&bundle_path).await?;

        reporter.emit(ModLoaderPhase::Applying, release.asset.size, None);
        extract_bundle(&bundle_path, install_dir).await?;

        reporter.emit(ModLoaderPhase::Finalizing, release.asset.size, None);

        let manifest = ModLoaderInstalled {
            version_guid: version_guid.to_string(),
            tag: release.tag.clone(),
            name: release.name.clone(),
            channel: release.channel,
            asset_name: release.asset.name.clone(),
            asset_size: release.asset.size,
            asset_sha256: release.asset.sha256.clone(),
            asset_updated_at: release.asset.updated_at.clone(),
            installed_at: Utc::now().to_rfc3339(),
            artifacts,
        };

        save_manifest(install_dir, &manifest).await?;

        Ok(manifest)
    }
    .await;

    match result {
        Ok(manifest) => {
            info!(version_guid, tag = %manifest.tag, "mod loader installation completed");
            reporter.emit(ModLoaderPhase::Completed, release.asset.size, None);
            Ok(manifest)
        }
        Err(error) => {
            warn!(version_guid, tag = %release.tag, error = %error, "mod loader installation failed");
            reporter.emit(ModLoaderPhase::Failed, 0, Some(error.to_string()));
            Err(error)
        }
    }
}

pub async fn remove_from_install_dir(install_dir: &Path, artifacts: &[String]) -> Result<()> {
    for artifact in artifacts {
        let target = install_dir.join(artifact);

        if target.is_dir() {
            tokio_fs::remove_dir_all(&target)
                .await
                .with_context(|| format!("failed to remove {}", target.display()))?;
        } else if target.exists() {
            tokio_fs::remove_file(&target)
                .await
                .with_context(|| format!("failed to remove {}", target.display()))?;
        }
    }

    Ok(())
}

async fn download_bundle(
    bundle_path: &Path,
    release: &ModLoaderRelease,
    reporter: &ProgressReporter<'_>,
) -> Result<()> {
    if bundle_path.exists() && verify_bundle(bundle_path, release).await.is_ok() {
        info!(tag = %release.tag, "reusing verified cached mod loader bundle");
        reporter.emit(ModLoaderPhase::Downloading, release.asset.size, None);
        return Ok(());
    }

    ensure_trusted_download(&release.asset.download_url)?;

    let partial_path = bundle_path.with_extension("partial");
    if partial_path.exists() {
        let _ = tokio_fs::remove_file(&partial_path).await;
    }

    let response = send_download_request(&http_client()?, &release.asset.download_url).await?;
    let mut stream = response.bytes_stream();
    let mut file = tokio_fs::File::create(&partial_path)
        .await
        .with_context(|| format!("failed to create {}", partial_path.display()))?;
    let mut downloaded = 0_u64;
    let mut hasher = Sha256::new();

    reporter.emit(ModLoaderPhase::Downloading, 0, None);

    while let Some(chunk) = stream.next().await {
        let chunk = chunk.with_context(|| format!("failed while downloading {}", release.asset.name))?;
        file.write_all(&chunk)
            .await
            .with_context(|| format!("failed to write {}", partial_path.display()))?;

        downloaded += chunk.len() as u64;
        hasher.update(&chunk);
        reporter.emit(ModLoaderPhase::Downloading, downloaded, None);
    }

    file.flush()
        .await
        .with_context(|| format!("failed to flush {}", partial_path.display()))?;

    if release.asset.size != 0 && downloaded != release.asset.size {
        bail!(
            "{} expected {} bytes but received {} bytes",
            release.asset.name,
            release.asset.size,
            downloaded,
        );
    }

    if let Some(expected) = release.asset.sha256.as_deref() {
        let digest = format!("{:x}", hasher.finalize());
        if !digest.eq_ignore_ascii_case(expected) {
            bail!(
                "{} failed integrity verification: expected SHA-256 {} but received {}",
                release.asset.name,
                expected,
                digest,
            );
        }
    }

    tokio_fs::rename(&partial_path, bundle_path)
        .await
        .with_context(|| format!("failed to move {} to {}", partial_path.display(), bundle_path.display()))?;

    info!(tag = %release.tag, bytes = downloaded, "downloaded mod loader bundle");

    Ok(())
}

async fn verify_bundle(bundle_path: &Path, release: &ModLoaderRelease) -> Result<()> {
    let bundle_path = bundle_path.to_path_buf();
    let expected_size = release.asset.size;
    let expected_sha = release.asset.sha256.clone();

    tokio::task::spawn_blocking(move || verify_bundle_blocking(&bundle_path, expected_size, expected_sha.as_deref()))
        .await
        .context("the bundle verification task failed to join")?
}

fn verify_bundle_blocking(bundle_path: &Path, expected_size: u64, expected_sha: Option<&str>) -> Result<()> {
    let metadata = fs::metadata(bundle_path)
        .with_context(|| format!("failed to stat {}", bundle_path.display()))?;

    if expected_size != 0 && metadata.len() != expected_size {
        bail!("cached bundle size mismatch for {}", bundle_path.display());
    }

    let Some(expected_sha) = expected_sha else {
        return Ok(());
    };

    let file = fs::File::open(bundle_path)
        .with_context(|| format!("failed to open {}", bundle_path.display()))?;
    let mut reader = BufReader::new(file);
    let mut buffer = [0_u8; 64 * 1024];
    let mut hasher = Sha256::new();

    loop {
        let read = reader
            .read(&mut buffer)
            .with_context(|| format!("failed to read {}", bundle_path.display()))?;
        if read == 0 {
            break;
        }
        hasher.update(&buffer[..read]);
    }

    let digest = format!("{:x}", hasher.finalize());
    if !digest.eq_ignore_ascii_case(expected_sha) {
        bail!("cached bundle digest mismatch for {}", bundle_path.display());
    }

    Ok(())
}

async fn read_top_level_entries(bundle_path: &Path) -> Result<Vec<String>> {
    let bundle_path = bundle_path.to_path_buf();

    tokio::task::spawn_blocking(move || read_top_level_entries_blocking(&bundle_path))
        .await
        .context("the bundle inspection task failed to join")?
}

fn read_top_level_entries_blocking(bundle_path: &Path) -> Result<Vec<String>> {
    let file = fs::File::open(bundle_path)
        .with_context(|| format!("failed to open {}", bundle_path.display()))?;
    let mut archive = zip::ZipArchive::new(file)
        .with_context(|| format!("failed to read {}", bundle_path.display()))?;
    let mut roots = BTreeSet::new();

    for index in 0..archive.len() {
        let entry = archive
            .by_index(index)
            .with_context(|| format!("failed to read archive entry {index} from {}", bundle_path.display()))?;

        let Some(enclosed) = entry.enclosed_name() else {
            continue;
        };

        if let Some(first) = enclosed.components().next() {
            let root = first.as_os_str().to_string_lossy().to_string();
            if !root.is_empty() {
                roots.insert(root);
            }
        }
    }

    if roots.is_empty() {
        bail!("the mod loader bundle is empty");
    }

    Ok(roots.into_iter().collect())
}

async fn extract_bundle(bundle_path: &Path, install_dir: &Path) -> Result<()> {
    let bundle_path = bundle_path.to_path_buf();
    let install_dir = install_dir.to_path_buf();

    tokio::task::spawn_blocking(move || extract_bundle_blocking(&bundle_path, &install_dir))
        .await
        .context("the bundle extraction task failed to join")?
}

fn extract_bundle_blocking(bundle_path: &Path, install_dir: &Path) -> Result<()> {
    if !install_dir.exists() {
        bail!("the Studio installation directory is missing: {}", install_dir.display());
    }

    let file = fs::File::open(bundle_path)
        .with_context(|| format!("failed to open {}", bundle_path.display()))?;
    let mut archive = zip::ZipArchive::new(file)
        .with_context(|| format!("failed to read {}", bundle_path.display()))?;

    for index in 0..archive.len() {
        let mut entry = archive
            .by_index(index)
            .with_context(|| format!("failed to read archive entry {index} from {}", bundle_path.display()))?;
        
        let Some(enclosed) = entry.enclosed_name().map(PathBuf::from) else {
            continue;
        };
        let destination = install_dir.join(&enclosed);

        if entry.is_dir() {
            fs::create_dir_all(&destination)
                .with_context(|| format!("failed to create {}", destination.display()))?;
            continue;
        }

        if let Some(parent) = destination.parent() {
            fs::create_dir_all(parent)
                .with_context(|| format!("failed to create {}", parent.display()))?;
        }

        let mut output = fs::File::create(&destination)
            .with_context(|| format!("failed to create {}", destination.display()))?;
        io::copy(&mut entry, &mut output)
            .with_context(|| format!("failed to extract {}", destination.display()))?;
    }

    Ok(())
}

struct ProgressReporter<'a> {
    app: &'a AppHandle,
    version_guid: String,
    tag: String,
    total_bytes: u64,
}

impl<'a> ProgressReporter<'a> {
    fn new(app: &'a AppHandle, version_guid: &str, tag: &str, total_bytes: u64) -> Self {
        Self {
            app,
            version_guid: version_guid.to_string(),
            tag: tag.to_string(),
            total_bytes,
        }
    }

    fn emit(&self, phase: ModLoaderPhase, downloaded_bytes: u64, error: Option<String>) {
        let payload = ModLoaderInstallProgress {
            version_guid: self.version_guid.clone(),
            tag: self.tag.clone(),
            progress: compute_progress(&phase, downloaded_bytes, self.total_bytes),
            phase,
            downloaded_bytes,
            total_bytes: self.total_bytes,
            error,
        };

        let _ = self.app.emit(INSTALL_EVENT, payload);
    }
}

fn compute_progress(phase: &ModLoaderPhase, downloaded_bytes: u64, total_bytes: u64) -> f64 {
    let download_ratio = if total_bytes == 0 {
        0.0
    } else {
        downloaded_bytes as f64 / total_bytes as f64
    };

    match phase {
        ModLoaderPhase::Resolving => 2.0,
        ModLoaderPhase::Downloading => (download_ratio * 80.0).clamp(0.0, 80.0),
        ModLoaderPhase::Applying => 92.0,
        ModLoaderPhase::Finalizing => 99.0,
        ModLoaderPhase::Completed => 100.0,
        ModLoaderPhase::Failed => (download_ratio * 80.0).clamp(0.0, 99.0),
    }
}
