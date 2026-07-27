use serde::{Deserialize, Serialize};

#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "lowercase")]
pub enum ModLoaderChannel {
    Stable,
    Beta,
    Nightly,
    Experimental,
    Prerelease,
}

impl ModLoaderChannel {
    pub fn classify(tag: &str, name: &str, prerelease: bool) -> Self {
        let haystack = format!("{} {}", tag, name).to_ascii_lowercase();

        if haystack.contains("nightly") {
            ModLoaderChannel::Nightly
        } else if haystack.contains("experimental") {
            ModLoaderChannel::Experimental
        } else if haystack.contains("beta") || haystack.contains("alpha") {
            ModLoaderChannel::Beta
        } else if prerelease {
            ModLoaderChannel::Prerelease
        } else {
            ModLoaderChannel::Stable
        }
    }
}

#[derive(Debug, Clone, Serialize)]
#[serde(rename_all = "camelCase")]
pub struct ModLoaderAsset {
    pub name: String,
    pub size: u64,
    pub download_url: String,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub sha256: Option<String>,
    pub updated_at: String,
}

#[derive(Debug, Clone, Serialize)]
#[serde(rename_all = "camelCase")]
pub struct ModLoaderRelease {
    pub tag: String,
    pub name: String,
    pub channel: ModLoaderChannel,
    pub prerelease: bool,
    pub published_at: Option<String>,
    pub html_url: String,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub notes: Option<String>,
    pub asset: ModLoaderAsset,
    pub is_installed: bool,
    pub update_available: bool,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct ModLoaderInstalled {
    #[serde(default, alias = "versionGuid")]
    pub installation_id: String,
    pub tag: String,
    pub name: String,
    pub channel: ModLoaderChannel,
    pub asset_name: String,
    pub asset_size: u64,
    #[serde(default, skip_serializing_if = "Option::is_none")]
    pub asset_sha256: Option<String>,
    pub asset_updated_at: String,
    pub installed_at: String,
    pub artifacts: Vec<String>,
}

#[derive(Debug, Clone, Copy, Serialize)]
#[serde(rename_all = "camelCase")]
pub enum ModLoaderPhase {
    Resolving,
    Downloading,
    Applying,
    Finalizing,
    Completed,
    Failed,
}

#[derive(Debug, Clone, Serialize)]
#[serde(rename_all = "camelCase")]
pub struct ModLoaderInstallProgress {
    pub installation_id: String,
    pub tag: String,
    pub phase: ModLoaderPhase,
    pub downloaded_bytes: u64,
    pub total_bytes: u64,
    pub progress: f64,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub error: Option<String>,
}

#[derive(Debug, Clone, Deserialize)]
pub struct GithubRelease {
    pub tag_name: String,
    #[serde(default)]
    pub name: Option<String>,
    #[serde(default)]
    pub prerelease: bool,
    #[serde(default)]
    pub draft: bool,
    #[serde(default)]
    pub published_at: Option<String>,
    pub html_url: String,
    #[serde(default)]
    pub body: Option<String>,
    #[serde(default)]
    pub assets: Vec<GithubAsset>,
}

#[derive(Debug, Clone, Deserialize)]
pub struct GithubAsset {
    pub name: String,
    pub size: u64,
    pub browser_download_url: String,
    #[serde(default)]
    pub digest: Option<String>,
    pub updated_at: String,
}

#[cfg(test)]
mod tests {
    use super::ModLoaderChannel;

    #[test]
    fn classifies_channels_dynamically() {
        assert_eq!(ModLoaderChannel::classify("nightly", "Nightly build", true), ModLoaderChannel::Nightly);
        assert_eq!(ModLoaderChannel::classify("v1.2.0", "Stable", false), ModLoaderChannel::Stable);
        assert_eq!(ModLoaderChannel::classify("v1.2.0-beta.1", "Beta", true), ModLoaderChannel::Beta);
        assert_eq!(
            ModLoaderChannel::classify("experimental", "Experimental", true),
            ModLoaderChannel::Experimental
        );
        assert_eq!(ModLoaderChannel::classify("v2.0.0-rc.1", "Release candidate", true), ModLoaderChannel::Prerelease);
    }
}
