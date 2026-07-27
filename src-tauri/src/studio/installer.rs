use std::{
    fs,
    io::{self, BufReader, Read},
    path::Path,
};

use anyhow::{bail, Context, Result};
use chrono::Utc;
use futures_util::StreamExt;
use md5::{Digest, Md5};
use std::path::PathBuf;
use tokio::{fs as tokio_fs, io::AsyncWriteExt};
use tracing::{error, info, warn};

use super::{
    api::{fetch_package_manifest, http_client, package_url, send_get_request_with_retry},
    config::{binary_target, package_extract_root, APP_SETTINGS_XML, OAUTH2_CONFIG_JSON},
    model::{InstallPhase, InstalledStudioManifest, PackageManifestEntry},
    paths::{version_executable_path, version_manifest_path},
    storage::{read_installed_manifest, write_installed_manifest},
};
use super::progress::{ProgressReporter, StudioProgressSink};

pub async fn install_version<S: StudioProgressSink + Send + Sync>(
    sink: &S,
    install_dir: PathBuf,
    download_dir: PathBuf,
    version_guid: &str,
    version: &str,
    channel: &str,
    published_at: Option<&str>,
) -> Result<InstalledStudioManifest> {
    info!(version_guid, version, channel, "starting Studio installation");

    let version_guid = version_guid.to_string();
    let version = version.to_string();
    let failed_version_guid = version_guid.clone();
    let failed_version = version.clone();
    let manifest_path = version_manifest_path(&install_dir);

    if manifest_path.exists() {
        return read_installed_manifest(&manifest_path);
    }

    let reporter = ProgressReporter::new(sink, &version_guid, &version, channel);

    let install_result: Result<InstalledStudioManifest> = async {
        reporter.emit(InstallPhase::Resolving, None, 0, 0, 0, 0, None);

        let packages = fetch_package_manifest(&version_guid).await?;
        let total_download_bytes = packages.iter().map(|package| package.packed_size).sum::<u64>();
        let version_major = parse_version_major(&version)?;

        info!(
            version_guid,
            package_count = packages.len(),
            total_download_bytes,
            "resolved Studio package manifest"
        );

        tokio_fs::create_dir_all(&download_dir)
            .await
            .with_context(|| format!("failed to create {}", download_dir.display()))?;
        tokio_fs::create_dir_all(&install_dir)
            .await
            .with_context(|| format!("failed to create {}", install_dir.display()))?;

        let mut downloaded_bytes = 0_u64;

        for package in &packages {
            reporter.emit(
                InstallPhase::Downloading,
                Some(package.name.clone()),
                downloaded_bytes,
                total_download_bytes,
                0,
                packages.len(),
                None,
            );

            let archive_path = download_dir.join(&package.name);
            download_package(
                package,
                &version_guid,
                &archive_path,
                &reporter,
                &mut downloaded_bytes,
                total_download_bytes,
                packages.len(),
            )
            .await?;
        }

        let mut extracted_packages = 0_usize;

        for package in &packages {
            let archive_path = download_dir.join(&package.name);
            extract_package(package, &archive_path, &install_dir, version_major).await?;
            extracted_packages += 1;

            reporter.emit(
                InstallPhase::Extracting,
                Some(package.name.clone()),
                downloaded_bytes,
                total_download_bytes,
                extracted_packages,
                packages.len(),
                None,
            );
        }

        reporter.emit(
            InstallPhase::Finalizing,
            None,
            downloaded_bytes,
            total_download_bytes,
            extracted_packages,
            packages.len(),
            None,
        );

        write_runtime_files(&install_dir, &version, &version_guid).await?;

        let manifest = InstalledStudioManifest {
            version_guid,
            version,
            channel: channel.to_string(),
            binary_target: binary_target().to_string(),
            installed_at: Utc::now().to_rfc3339(),
            published_at: published_at.map(str::to_string),
            integrity_verified_at: Some(Utc::now().to_rfc3339()),
        };

        write_installed_manifest(&manifest_path, &manifest).await?;

        Ok(manifest)
    }
    .await;

    match install_result {
        Ok(manifest) => {
            info!(version_guid = %manifest.version_guid, version = %manifest.version, "Studio installation completed");
            reporter.emit(InstallPhase::Completed, None, 0, 0, 0, 0, None);
            Ok(manifest)
        }
        Err(error) => {
            error!(version_guid = %failed_version_guid, version = %failed_version, error = %error, "Studio installation failed");
            reporter.emit(
                InstallPhase::Failed,
                None,
                0,
                0,
                0,
                0,
                Some(error.to_string()),
            );

            if !manifest_path.exists() {
                let _ = tokio_fs::remove_dir_all(&install_dir).await;
            }

            Err(error)
        }
    }
}

pub async fn revalidate_version(
    install_dir: PathBuf,
    downloads_root: PathBuf,
    version_guid: &str,
) -> Result<InstalledStudioManifest> {
    info!(version_guid, "starting Studio revalidation");

    let manifest_path = version_manifest_path(&install_dir);

    if !manifest_path.exists() {
        bail!("The selected Studio version is not installed.");
    }

    let mut manifest = read_installed_manifest(&manifest_path)?;
    let version_major = parse_version_major(&manifest.version)?;
    let download_dir = downloads_root.join(&manifest.version_guid);
    let packages = fetch_package_manifest(&manifest.version_guid).await?;

    tokio_fs::create_dir_all(&download_dir)
        .await
        .with_context(|| format!("failed to create {}", download_dir.display()))?;

    for package in &packages {
        let archive_path = download_dir.join(&package.name);
        let _ = download_package_archive(package, &manifest.version_guid, &archive_path, |_| {}).await?;
    }

    validate_install_layout(&install_dir, &download_dir, &manifest, &packages, version_major).await?;

    manifest.integrity_verified_at = Some(Utc::now().to_rfc3339());
    write_installed_manifest(&manifest_path, &manifest).await?;

    info!(version_guid = %manifest.version_guid, version = %manifest.version, "Studio revalidation completed");

    Ok(manifest)
}

async fn download_package<S: StudioProgressSink>(
    package: &PackageManifestEntry,
    version_guid: &str,
    archive_path: &Path,
    reporter: &ProgressReporter<'_, S>,
    downloaded_bytes: &mut u64,
    total_download_bytes: u64,
    total_packages: usize,
) -> Result<()> {
    let used_cache = download_package_archive(package, version_guid, archive_path, |chunk_len| {
        *downloaded_bytes += chunk_len;

        reporter.emit(
            InstallPhase::Downloading,
            Some(package.name.clone()),
            *downloaded_bytes,
            total_download_bytes,
            0,
            total_packages,
            None,
        );
    })
    .await?;

    if used_cache {
        *downloaded_bytes += package.packed_size;

        reporter.emit(
            InstallPhase::Downloading,
            Some(package.name.clone()),
            *downloaded_bytes,
            total_download_bytes,
            0,
            total_packages,
            None,
        );
    }

    Ok(())
}

async fn download_package_archive<F>(
    package: &PackageManifestEntry,
    version_guid: &str,
    archive_path: &Path,
    mut on_chunk: F,
) -> Result<bool>
where
    F: FnMut(u64),
{
    if let Some(parent) = archive_path.parent() {
        tokio_fs::create_dir_all(parent)
            .await
            .with_context(|| format!("failed to create {}", parent.display()))?;
    }

    if archive_path.exists() {
        match verify_package_archive(package, archive_path).await {
            Ok(()) => return Ok(true),
            Err(error) => {
                warn!(
                    package = %package.name,
                    archive_path = %archive_path.display(),
                    error = %error,
                    "discarding invalid cached package archive"
                );
                tokio_fs::remove_file(archive_path)
                    .await
                    .with_context(|| format!("failed to remove invalid cache {}", archive_path.display()))?;
            }
        }
    }

    let partial_archive_path = archive_path.with_extension("partial");
    if partial_archive_path.exists() {
        let _ = tokio_fs::remove_file(&partial_archive_path).await;
    }

    let package_download_url = package_url(version_guid, &package.name);
    info!(package = %package.name, url = %package_download_url, "downloading Studio package archive");

    let response = send_get_request_with_retry(
        &http_client()?,
        &package_download_url,
        &format!("package archive {}", package.name),
    )
        .await
        .with_context(|| format!("failed to download {}", package.name))?;

    let mut stream = response.bytes_stream();
    let mut file = tokio_fs::File::create(&partial_archive_path)
        .await
        .with_context(|| format!("failed to create {}", partial_archive_path.display()))?;
    let mut package_bytes = 0_u64;
    let mut hasher = Md5::new();

    while let Some(chunk) = stream.next().await {
        let chunk = chunk.with_context(|| format!("failed while downloading {}", package.name))?;
        file.write_all(&chunk)
            .await
            .with_context(|| format!("failed to write {}", partial_archive_path.display()))?;

        let chunk_len = chunk.len() as u64;
        package_bytes += chunk_len;
        hasher.update(&chunk);
        on_chunk(chunk_len);
    }

    file.flush()
        .await
        .with_context(|| format!("failed to flush {}", partial_archive_path.display()))?;

    if package_bytes != package.packed_size {
        bail!(
            "{} expected {} bytes but received {} bytes",
            package.name,
            package.packed_size,
            package_bytes,
        );
    }

    let digest = format!("{:x}", hasher.finalize());
    if !digest.eq_ignore_ascii_case(&package.signature) {
        bail!(
            "{} failed integrity verification: expected MD5 {} but received {}",
            package.name,
            package.signature,
            digest,
        );
    }

    verify_archive_structure(package, &partial_archive_path).await?;

    tokio_fs::rename(&partial_archive_path, archive_path)
        .await
        .with_context(|| {
            format!(
                "failed to move {} to {}",
                partial_archive_path.display(),
                archive_path.display()
            )
        })?;

    info!(package = %package.name, archive_path = %archive_path.display(), bytes = package_bytes, "downloaded Studio package archive");

    Ok(false)
}

async fn extract_package(
    package: &PackageManifestEntry,
    archive_path: &Path,
    install_dir: &Path,
    version_major: u32,
) -> Result<()> {
    let package_stem = package.name.trim_end_matches(".zip").to_string();
    let extraction_root = package_extract_root(&package_stem, version_major).to_string();
    let archive_path = archive_path.to_path_buf();
    let install_dir = install_dir.to_path_buf();
    let expected_unpacked_size = package.unpacked_size;

    tokio::task::spawn_blocking(move || {
        extract_package_blocking(
            &archive_path,
            &install_dir,
            &extraction_root,
            expected_unpacked_size,
        )
    })
        .await
        .context("the package extraction task failed to join")??;

    Ok(())
}

fn extract_package_blocking(
    archive_path: &Path,
    install_dir: &Path,
    extraction_root: &str,
    expected_unpacked_size: u64,
) -> Result<()> {
    let file = fs::File::open(archive_path)
        .with_context(|| format!("failed to open {}", archive_path.display()))?;
    let mut archive = zip::ZipArchive::new(file)
        .with_context(|| format!("failed to read {}", archive_path.display()))?;
    let mut extracted_bytes = 0_u64;

    for index in 0..archive.len() {
        let mut entry = archive.by_index(index).with_context(|| {
            format!("failed to read archive entry {index} from {}", archive_path.display())
        })?;

        let Some(enclosed_name) = entry.enclosed_name().map(|path| path.to_path_buf()) else {
            continue;
        };

        let destination = if extraction_root.is_empty() {
            install_dir.join(&enclosed_name)
        } else {
            install_dir.join(extraction_root).join(&enclosed_name)
        };

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
        let expected_entry_size = entry.size();
        let copied_bytes = io::copy(&mut entry, &mut output)
            .with_context(|| format!("failed to extract {}", destination.display()))?;

        if copied_bytes != expected_entry_size {
            bail!(
                "{} extracted {} bytes from {} but expected {}",
                destination.display(),
                copied_bytes,
                archive_path.display(),
                expected_entry_size,
            );
        }

        extracted_bytes += copied_bytes;
    }

    if extracted_bytes != expected_unpacked_size {
        bail!(
            "{} expected {} unpacked bytes but extracted {}",
            archive_path.display(),
            expected_unpacked_size,
            extracted_bytes,
        );
    }

    Ok(())
}

async fn verify_package_archive(package: &PackageManifestEntry, archive_path: &Path) -> Result<()> {
    let archive_path = archive_path.to_path_buf();
    let package = package.clone();

    tokio::task::spawn_blocking(move || verify_package_archive_blocking(&package, &archive_path))
        .await
        .context("the package verification task failed to join")??;

    Ok(())
}

async fn verify_archive_structure(package: &PackageManifestEntry, archive_path: &Path) -> Result<()> {
    let archive_path = archive_path.to_path_buf();
    let package = package.clone();

    tokio::task::spawn_blocking(move || verify_archive_structure_blocking(&package, &archive_path))
        .await
        .context("the archive structure verification task failed to join")??;

    Ok(())
}

async fn validate_install_layout(
    install_dir: &Path,
    download_dir: &Path,
    manifest: &InstalledStudioManifest,
    packages: &[PackageManifestEntry],
    version_major: u32,
) -> Result<()> {
    let install_dir = install_dir.to_path_buf();
    let download_dir = download_dir.to_path_buf();
    let manifest = manifest.clone();
    let packages = packages.to_vec();

    tokio::task::spawn_blocking(move || {
        validate_install_layout_blocking(&install_dir, &download_dir, &manifest, &packages, version_major)
    })
    .await
    .context("the install validation task failed to join")??;

    Ok(())
}

fn validate_install_layout_blocking(
    install_dir: &Path,
    download_dir: &Path,
    manifest: &InstalledStudioManifest,
    packages: &[PackageManifestEntry],
    version_major: u32,
) -> Result<()> {
    if !install_dir.exists() {
        bail!("the Studio installation directory is missing: {}", install_dir.display());
    }

    let executable_path = version_executable_path(install_dir);
    if !executable_path.exists() {
        bail!("RobloxStudioBeta.exe was not found in {}", install_dir.display());
    }

    validate_text_file(&install_dir.join("AppSettings.xml"), APP_SETTINGS_XML)?;
    validate_text_file(
        &install_dir.join("ApplicationConfig").join("OAuth2Config.json"),
        OAUTH2_CONFIG_JSON,
    )?;
    validate_trimmed_file(&install_dir.join("version.txt"), &manifest.version)?;
    validate_trimmed_file(&install_dir.join("version-guid.txt"), &manifest.version_guid)?;

    for package in packages {
        let package_stem = package.name.trim_end_matches(".zip");
        let extraction_root = package_extract_root(package_stem, version_major);

        validate_installed_package_blocking(
            package,
            &download_dir.join(&package.name),
            install_dir,
            extraction_root,
            &manifest.version_guid,
        )?;
    }

    Ok(())
}

fn validate_installed_package_blocking(
    package: &PackageManifestEntry,
    archive_path: &Path,
    install_dir: &Path,
    extraction_root: &str,
    version_guid: &str,
) -> Result<()> {
    let file = fs::File::open(archive_path)
        .with_context(|| format!("failed to open cached archive {}", archive_path.display()))?;
    let mut archive = zip::ZipArchive::new(file)
        .with_context(|| format!("failed to read {}", archive_path.display()))?;
    let mut validated_bytes = 0_u64;

    for index in 0..archive.len() {
        let entry = archive.by_index(index).with_context(|| {
            format!("failed to inspect archive entry {index} from {}", archive_path.display())
        })?;
        let Some(enclosed_name) = entry.enclosed_name().map(|path| path.to_path_buf()) else {
            continue;
        };

        let destination = if extraction_root.is_empty() {
            install_dir.join(&enclosed_name)
        } else {
            install_dir.join(extraction_root).join(&enclosed_name)
        };

        if entry.is_dir() {
            if !destination.is_dir() {
                bail!(
                    "{} is missing expected directory {} for {}",
                    version_guid,
                    destination.display(),
                    package.name,
                );
            }

            continue;
        }

        let metadata = fs::metadata(&destination)
            .with_context(|| format!("failed to stat {}", destination.display()))?;

        if !metadata.is_file() {
            bail!(
                "{} expected file {} for {} but found something else",
                version_guid,
                destination.display(),
                package.name,
            );
        }

        if metadata.len() != entry.size() {
            bail!(
                "{} expected {} bytes for {} but found {}",
                destination.display(),
                entry.size(),
                package.name,
                metadata.len(),
            );
        }

        validated_bytes += metadata.len();
    }

    if validated_bytes != package.unpacked_size {
        bail!(
            "{} expected {} installed bytes for {} but validated {}",
            version_guid,
            package.unpacked_size,
            package.name,
            validated_bytes,
        );
    }

    Ok(())
}

fn validate_text_file(path: &Path, expected: &str) -> Result<()> {
    let contents = fs::read_to_string(path)
        .with_context(|| format!("failed to read {}", path.display()))?;

    if contents != expected {
        bail!("{} does not match the expected runtime file contents", path.display());
    }

    Ok(())
}

fn validate_trimmed_file(path: &Path, expected: &str) -> Result<()> {
    let contents = fs::read_to_string(path)
        .with_context(|| format!("failed to read {}", path.display()))?;

    if contents.trim() != expected {
        bail!("{} does not match the expected value", path.display());
    }

    Ok(())
}

fn verify_package_archive_blocking(package: &PackageManifestEntry, archive_path: &Path) -> Result<()> {
    let metadata = fs::metadata(archive_path)
        .with_context(|| format!("failed to stat {}", archive_path.display()))?;

    if metadata.len() != package.packed_size {
        bail!(
            "{} expected {} bytes but found {}",
            package.name,
            package.packed_size,
            metadata.len(),
        );
    }

    let file = fs::File::open(archive_path)
        .with_context(|| format!("failed to open {}", archive_path.display()))?;
    let mut reader = BufReader::new(file);
    let mut buffer = [0_u8; 64 * 1024];
    let mut hasher = Md5::new();

    loop {
        let bytes_read = reader
            .read(&mut buffer)
            .with_context(|| format!("failed to read {}", archive_path.display()))?;

        if bytes_read == 0 {
            break;
        }

        hasher.update(&buffer[..bytes_read]);
    }

    let digest = format!("{:x}", hasher.finalize());
    if !digest.eq_ignore_ascii_case(&package.signature) {
        bail!(
            "{} expected MD5 {} but found {}",
            package.name,
            package.signature,
            digest,
        );
    }

    verify_archive_structure_blocking(package, archive_path)
}

fn verify_archive_structure_blocking(package: &PackageManifestEntry, archive_path: &Path) -> Result<()> {
    let file = fs::File::open(archive_path)
        .with_context(|| format!("failed to open {}", archive_path.display()))?;
    let mut archive = zip::ZipArchive::new(file)
        .with_context(|| format!("failed to read {}", archive_path.display()))?;
    let mut unpacked_size = 0_u64;

    for index in 0..archive.len() {
        let entry = archive.by_index(index).with_context(|| {
            format!("failed to inspect archive entry {index} from {}", archive_path.display())
        })?;

        if entry.is_dir() {
            continue;
        }

        unpacked_size += entry.size();
    }

    if unpacked_size != package.unpacked_size {
        bail!(
            "{} expected {} unpacked bytes but found {}",
            package.name,
            package.unpacked_size,
            unpacked_size,
        );
    }

    Ok(())
}

async fn write_runtime_files(install_dir: &Path, version: &str, version_guid: &str) -> Result<()> {
    tokio_fs::write(install_dir.join("AppSettings.xml"), APP_SETTINGS_XML.as_bytes())
        .await
        .with_context(|| format!("failed to write {}", install_dir.join("AppSettings.xml").display()))?;

    let application_config_dir = install_dir.join("ApplicationConfig");
    tokio_fs::create_dir_all(&application_config_dir)
        .await
        .with_context(|| format!("failed to create {}", application_config_dir.display()))?;

    tokio_fs::write(
        application_config_dir.join("OAuth2Config.json"),
        OAUTH2_CONFIG_JSON.as_bytes(),
    )
    .await
    .with_context(|| {
        format!(
            "failed to write {}",
            application_config_dir.join("OAuth2Config.json").display()
        )
    })?;

    tokio_fs::write(install_dir.join("version.txt"), version.as_bytes())
        .await
        .with_context(|| format!("failed to write {}", install_dir.join("version.txt").display()))?;
    tokio_fs::write(install_dir.join("version-guid.txt"), version_guid.as_bytes())
        .await
        .with_context(|| {
            format!(
                "failed to write {}",
                install_dir.join("version-guid.txt").display()
            )
        })?;

    Ok(())
}

fn parse_version_major(version: &str) -> Result<u32> {
    let mut segments = version.split('.');
    let _major = segments.next();
    let Some(raw_version_major) = segments.next() else {
        bail!("invalid Roblox version format: {version}");
    };

    raw_version_major
        .parse::<u32>()
        .with_context(|| format!("invalid Roblox version format: {version}"))
}

