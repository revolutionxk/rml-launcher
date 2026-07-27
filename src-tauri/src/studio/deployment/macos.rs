use std::fs;
use std::future::Future;
use std::io;
use std::os::unix::fs::PermissionsExt;
use std::path::{Path, PathBuf};

use anyhow::{bail, Context, Result};
use chrono::Utc;
use futures_util::StreamExt;
use tokio::{fs as tokio_fs, io::AsyncWriteExt};
use tracing::{error, info};

use super::super::api::{http_client, mac_studio_url, send_get_request_with_retry};
use super::super::config::{binary_target, MAC_STUDIO_ZIP};
use super::super::progress::{ProgressReporter, StudioProgressSink};
use super::super::model::{InstallPhase, InstalledStudioManifest};
use super::super::paths::version_manifest_path;
use super::super::storage::{read_installed_manifest, write_installed_manifest};
use super::StudioDeployment;

const S_IFMT: u32 = 0o170000;
const S_IFLNK: u32 = 0o120000;

pub struct MacDeployment;

impl StudioDeployment for MacDeployment {
    fn install<S: StudioProgressSink + Send + Sync>(
        &self,
        sink: &S,
        install_dir: PathBuf,
        download_dir: PathBuf,
        version_guid: &str,
        version: &str,
        channel: &str,
        published_at: Option<&str>,
    ) -> impl Future<Output = Result<InstalledStudioManifest>> + Send {
        async move {
            let manifest_path = version_manifest_path(&install_dir);
            if manifest_path.exists() {
                return read_installed_manifest(&manifest_path);
            }

            let reporter = ProgressReporter::new(sink, version_guid, version, channel);

            let result = acquire(&reporter, &install_dir, &download_dir, version_guid, version, channel, published_at).await;

            match result {
                Ok(manifest) => {
                    info!(version_guid, version, "macOS Studio installation completed");
                    reporter.emit(InstallPhase::Completed, None, 0, 0, 0, 0, None);
                    Ok(manifest)
                }
                Err(error) => {
                    error!(version_guid, version, error = %error, "macOS Studio installation failed");
                    reporter.emit(InstallPhase::Failed, None, 0, 0, 0, 0, Some(error.to_string()));

                    if !manifest_path.exists() {
                        let _ = tokio_fs::remove_dir_all(&install_dir).await;
                    }

                    Err(error)
                }
            }
        }
    }
}

async fn acquire<S: StudioProgressSink>(
    reporter: &ProgressReporter<'_, S>,
    install_dir: &Path,
    download_dir: &Path,
    version_guid: &str,
    version: &str,
    channel: &str,
    published_at: Option<&str>,
) -> Result<InstalledStudioManifest> {
    reporter.emit(InstallPhase::Resolving, None, 0, 0, 0, 0, None);

    tokio_fs::create_dir_all(download_dir)
        .await
        .with_context(|| format!("failed to create {}", download_dir.display()))?;
    tokio_fs::create_dir_all(install_dir)
        .await
        .with_context(|| format!("failed to create {}", install_dir.display()))?;

    let archive_path = download_dir.join(MAC_STUDIO_ZIP);
    download_archive(reporter, version_guid, &archive_path).await?;

    reporter.emit(InstallPhase::Extracting, Some(MAC_STUDIO_ZIP.to_string()), 0, 0, 0, 1, None);
    extract_archive(&archive_path, install_dir).await?;

    reporter.emit(InstallPhase::Finalizing, None, 0, 0, 1, 1, None);
    write_version_markers(install_dir, version, version_guid).await?;

    let manifest = InstalledStudioManifest {
        version_guid: version_guid.to_string(),
        version: version.to_string(),
        channel: channel.to_string(),
        binary_target: binary_target().to_string(),
        installed_at: Utc::now().to_rfc3339(),
        published_at: published_at.map(str::to_string),
        integrity_verified_at: Some(Utc::now().to_rfc3339()),
    };

    write_installed_manifest(&version_manifest_path(install_dir), &manifest).await?;

    Ok(manifest)
}

async fn download_archive<S: StudioProgressSink>(
    reporter: &ProgressReporter<'_, S>,
    version_guid: &str,
    archive_path: &Path,
) -> Result<()> {
    let url = mac_studio_url(version_guid);
    info!(version_guid, url, "downloading macOS Studio archive");

    let response = send_get_request_with_retry(&http_client()?, &url, "macOS Studio archive").await?;
    let total_bytes = response.content_length().unwrap_or(0);

    if archive_path.exists() {
        if let Ok(metadata) = fs::metadata(archive_path) {
            if total_bytes != 0 && metadata.len() == total_bytes {
                info!(archive_path = %archive_path.display(), "reusing cached macOS Studio archive");
                reporter.emit(InstallPhase::Downloading, Some(MAC_STUDIO_ZIP.to_string()), total_bytes, total_bytes, 0, 1, None);
                return Ok(());
            }
        }
        let _ = tokio_fs::remove_file(archive_path).await;
    }

    let partial_path = archive_path.with_extension("partial");
    let _ = tokio_fs::remove_file(&partial_path).await;

    let mut stream = response.bytes_stream();
    let mut file = tokio_fs::File::create(&partial_path)
        .await
        .with_context(|| format!("failed to create {}", partial_path.display()))?;
    let mut downloaded = 0_u64;

    reporter.emit(InstallPhase::Downloading, Some(MAC_STUDIO_ZIP.to_string()), 0, total_bytes, 0, 1, None);

    while let Some(chunk) = stream.next().await {
        let chunk = chunk.context("failed while downloading the macOS Studio archive")?;
        file.write_all(&chunk).await.with_context(|| format!("failed to write {}", partial_path.display()))?;

        downloaded += chunk.len() as u64;
        reporter.emit(InstallPhase::Downloading, Some(MAC_STUDIO_ZIP.to_string()), downloaded, total_bytes, 0, 1, None);
    }

    file.flush().await.with_context(|| format!("failed to flush {}", partial_path.display()))?;

    if total_bytes != 0 && downloaded != total_bytes {
        bail!("expected {total_bytes} bytes but received {downloaded}");
    }

    tokio_fs::rename(&partial_path, archive_path)
        .await
        .with_context(|| format!("failed to move {} to {}", partial_path.display(), archive_path.display()))?;

    info!(bytes = downloaded, "downloaded macOS Studio archive");
    Ok(())
}

async fn extract_archive(archive_path: &Path, install_dir: &Path) -> Result<()> {
    let archive_path = archive_path.to_path_buf();
    let install_dir = install_dir.to_path_buf();

    tokio::task::spawn_blocking(move || extract_archive_blocking(&archive_path, &install_dir))
        .await
        .context("the archive extraction task failed to join")?
}

fn extract_archive_blocking(archive_path: &Path, install_dir: &Path) -> Result<()> {
    let file = fs::File::open(archive_path).with_context(|| format!("failed to open {}", archive_path.display()))?;
    let mut archive = zip::ZipArchive::new(file).with_context(|| format!("failed to read {}", archive_path.display()))?;

    for index in 0..archive.len() {
        let mut entry = archive
            .by_index(index)
            .with_context(|| format!("failed to read archive entry {index}"))?;

        let Some(relative) = entry.enclosed_name() else {
            continue;
        };
        let destination = install_dir.join(&relative);
        let mode = entry.unix_mode();

        if is_symlink(mode) {
            write_symlink(&mut entry, &destination)?;
        } else if entry.is_dir() {
            fs::create_dir_all(&destination).with_context(|| format!("failed to create {}", destination.display()))?;
        } else {
            write_file(&mut entry, &destination, mode)?;
        }
    }

    Ok(())
}

fn is_symlink(mode: Option<u32>) -> bool {
    mode.is_some_and(|mode| mode & S_IFMT == S_IFLNK)
}

fn write_symlink(entry: &mut zip::read::ZipFile<'_>, destination: &Path) -> Result<()> {
    let mut target = String::new();
    io::Read::read_to_string(entry, &mut target).with_context(|| format!("failed to read the symlink target for {}", destination.display()))?;

    if let Some(parent) = destination.parent() {
        fs::create_dir_all(parent).with_context(|| format!("failed to create {}", parent.display()))?;
    }
    let _ = fs::remove_file(destination);

    std::os::unix::fs::symlink(&target, destination)
        .with_context(|| format!("failed to create symlink {} -> {target}", destination.display()))
}

fn write_file(entry: &mut zip::read::ZipFile<'_>, destination: &Path, mode: Option<u32>) -> Result<()> {
    if let Some(parent) = destination.parent() {
        fs::create_dir_all(parent).with_context(|| format!("failed to create {}", parent.display()))?;
    }

    let mut output = fs::File::create(destination).with_context(|| format!("failed to create {}", destination.display()))?;
    io::copy(entry, &mut output).with_context(|| format!("failed to extract {}", destination.display()))?;

    if let Some(mode) = mode {
        fs::set_permissions(destination, fs::Permissions::from_mode(mode))
            .with_context(|| format!("failed to set permissions on {}", destination.display()))?;
    }

    Ok(())
}

async fn write_version_markers(install_dir: &Path, version: &str, version_guid: &str) -> Result<()> {
    tokio_fs::write(install_dir.join("version.txt"), version.as_bytes())
        .await
        .with_context(|| format!("failed to write {}", install_dir.join("version.txt").display()))?;
    tokio_fs::write(install_dir.join("version-guid.txt"), version_guid.as_bytes())
        .await
        .with_context(|| format!("failed to write {}", install_dir.join("version-guid.txt").display()))?;
    Ok(())
}
