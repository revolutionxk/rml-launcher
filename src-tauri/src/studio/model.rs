use std::path::{Path, PathBuf};

use serde::{Deserialize, Serialize};

#[derive(Debug, Clone, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct CurrentVersionResponse {
    pub version: String,
    pub client_version_upload: String,
}

#[cfg(not(target_os = "macos"))]
#[derive(Debug, Clone)]
pub struct PackageManifestEntry {
    pub name: String,
    pub signature: String,
    pub packed_size: u64,
    pub unpacked_size: u64,
}

#[derive(Debug, Clone)]
pub struct StudioBuild {
    pub version_guid: String,
    pub version: String,
    pub published_at: String,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct InstalledStudioManifest {
    pub version_guid: String,
    pub version: String,
    pub channel: String,
    pub binary_target: String,
    pub installed_at: String,
    #[serde(default, skip_serializing_if = "Option::is_none")]
    pub published_at: Option<String>,
    #[serde(default, skip_serializing_if = "Option::is_none")]
    pub integrity_verified_at: Option<String>,
}

#[derive(Debug, Clone, Serialize, Deserialize, Default)]
#[serde(rename_all = "camelCase")]
pub struct StudioPreferences {
    #[serde(default, skip_serializing_if = "Option::is_none")]
    pub default_version_guid: Option<String>,
}

#[derive(Debug, Clone, Serialize)]
#[serde(rename_all = "camelCase")]
pub struct StudioVersionEntry {
    pub id: String,
    pub version_guid: String,
    pub version: String,
    pub channel: String,
    pub installed_at: Option<String>,
    pub published_at: Option<String>,
    pub integrity_verified_at: Option<String>,
    pub is_default: bool,
    pub is_latest: bool,
    pub is_installed: bool,
    pub executable_path: Option<String>,
    pub install_dir: Option<String>,
}

impl StudioVersionEntry {
    pub fn available(
        version_guid: String,
        version: String,
        channel: &str,
        published_at: Option<String>,
    ) -> Self {
        Self {
            id: version_guid.clone(),
            version_guid,
            version,
            channel: channel.to_string(),
            installed_at: None,
            published_at,
            integrity_verified_at: None,
            is_default: false,
            is_latest: false,
            is_installed: false,
            executable_path: None,
            install_dir: None,
        }
    }

    pub fn from_installed(
        manifest: InstalledStudioManifest,
        install_dir: &Path,
        executable_path: Option<PathBuf>,
    ) -> Self {
        Self {
            id: manifest.version_guid.clone(),
            version_guid: manifest.version_guid,
            version: manifest.version,
            channel: manifest.channel,
            installed_at: Some(manifest.installed_at),
            published_at: manifest.published_at,
            integrity_verified_at: manifest.integrity_verified_at,
            is_default: false,
            is_latest: false,
            is_installed: true,
            executable_path: executable_path.map(|path| path.to_string_lossy().into_owned()),
            install_dir: Some(install_dir.to_string_lossy().into_owned()),
        }
    }
}

#[derive(Debug, Clone, Serialize)]
#[serde(rename_all = "camelCase")]
pub struct StudioVersionsResponse {
    pub versions: Vec<StudioVersionEntry>,
}

#[derive(Debug, Clone, Serialize)]
#[serde(rename_all = "camelCase")]
pub enum InstallPhase {
    Resolving,
    Downloading,
    Extracting,
    Finalizing,
    Completed,
    Failed,
}

#[derive(Debug, Clone, Serialize)]
#[serde(rename_all = "camelCase")]
pub struct StudioInstallProgress {
    pub version_guid: String,
    pub version: String,
    pub channel: String,
    pub phase: InstallPhase,
    pub current_package: Option<String>,
    pub downloaded_bytes: u64,
    pub total_download_bytes: u64,
    pub extracted_packages: usize,
    pub total_packages: usize,
    pub progress: f64,
    pub error: Option<String>,
}