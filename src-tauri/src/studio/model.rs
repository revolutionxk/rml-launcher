use serde::{Deserialize, Serialize};

use super::config::CURRENT_CHANNEL;
use super::installation::{Capabilities, InstallationSource, StudioInstallation};

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
    #[serde(
        default,
        alias = "defaultVersionGuid",
        skip_serializing_if = "Option::is_none"
    )]
    pub default_installation_id: Option<String>,
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
    pub source: InstallationSource,
    pub capabilities: Capabilities,
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
            id: format!("remote:{version_guid}"),
            version_guid,
            version,
            channel: channel.to_string(),
            installed_at: None,
            published_at,
            integrity_verified_at: None,
            is_default: false,
            is_latest: false,
            is_installed: false,
            source: InstallationSource::Managed,
            capabilities: Capabilities::MANAGED,
            executable_path: None,
            install_dir: None,
        }
    }

    pub fn from_installation(installation: &StudioInstallation) -> Self {
        Self {
            id: installation.id.to_string(),
            version_guid: installation.version_guid.clone().unwrap_or_default(),
            version: installation.version.clone().unwrap_or_default(),
            channel: installation
                .channel
                .clone()
                .unwrap_or_else(|| CURRENT_CHANNEL.to_string()),
            installed_at: installation.installed_at.clone(),
            published_at: installation.published_at.clone(),
            integrity_verified_at: installation.integrity_verified_at.clone(),
            is_default: false,
            is_latest: false,
            is_installed: true,
            source: installation.source,
            capabilities: installation.capabilities,
            executable_path: installation
                .executable
                .exists()
                .then(|| installation.executable.to_string_lossy().into_owned()),
            install_dir: Some(installation.install_dir.to_string_lossy().into_owned()),
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
#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn legacy_preferences_keyed_by_version_guid_still_load() {
        let preferences: StudioPreferences =
            serde_json::from_str(r#"{"defaultVersionGuid":"version-abc123"}"#).unwrap();

        assert_eq!(
            preferences.default_installation_id.as_deref(),
            Some("version-abc123")
        );
    }

    #[test]
    fn preferences_are_written_back_under_the_new_key() {
        let preferences = StudioPreferences {
            default_installation_id: Some("managed:version-abc123".into()),
        };

        let json = serde_json::to_string(&preferences).unwrap();

        assert_eq!(json, r#"{"defaultInstallationId":"managed:version-abc123"}"#);
    }

    #[test]
    fn the_serialized_shape_matches_the_frontend_contract() {
        let installation = StudioInstallation::new(
            InstallationSource::Bloxstrap,
            "version-abc123",
            std::path::PathBuf::from("/root/version-abc123"),
            std::path::PathBuf::from("/root/version-abc123/RobloxStudioBeta.exe"),
        );

        let json = serde_json::to_value(StudioVersionEntry::from_installation(&installation)).unwrap();

        assert_eq!(json["id"], "bloxstrap:version-abc123");
        assert_eq!(json["source"], "bloxstrap");
        assert_eq!(json["capabilities"], 0b0000_0111);
        assert_eq!(json["isInstalled"], true);
    }

    #[test]
    fn remote_entries_are_namespaced_so_they_never_collide_with_installations() {
        let entry = StudioVersionEntry::available(
            "version-abc123".into(),
            "0.730.0".into(),
            "LIVE",
            None,
        );

        assert_eq!(entry.id, "remote:version-abc123");
        assert!(!entry.is_installed);
    }
}
