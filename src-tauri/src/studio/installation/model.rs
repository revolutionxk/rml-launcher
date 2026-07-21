use std::fmt;
use std::path::PathBuf;

use serde::Serialize;

#[derive(Debug, Clone, PartialEq, Eq, Hash, Serialize)]
#[serde(transparent)]
pub struct InstallationId(String);

impl InstallationId {
    pub fn new(source: &str, key: &str) -> Self {
        Self(format!("{source}:{key}"))
    }

    pub fn as_str(&self) -> &str {
        &self.0
    }
}

impl From<String> for InstallationId {
    fn from(value: String) -> Self {
        Self(value)
    }
}

impl fmt::Display for InstallationId {
    fn fmt(&self, formatter: &mut fmt::Formatter<'_>) -> fmt::Result {
        formatter.write_str(&self.0)
    }
}

#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize)]
#[serde(rename_all = "camelCase")]
pub enum InstallationSource {
    Managed,
    RobloxOfficial,
    Bloxstrap,
    MacBundle,
    Vinegar,
}

impl InstallationSource {
    pub fn slug(self) -> &'static str {
        match self {
            Self::Managed => "managed",
            Self::RobloxOfficial => "roblox-official",
            Self::Bloxstrap => "bloxstrap",
            Self::MacBundle => "mac-bundle",
            Self::Vinegar => "vinegar",
        }
    }
}

#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize)]
#[serde(transparent)]
pub struct Capabilities(u8);

impl Capabilities {
    pub const LAUNCH: Self = Self(1 << 0);
    pub const MODS: Self = Self(1 << 1);
    pub const ENGINE_FLAGS: Self = Self(1 << 2);
    pub const UNINSTALL: Self = Self(1 << 3);
    pub const REVALIDATE: Self = Self(1 << 4);

    pub const DETECTED: Self = Self(Self::LAUNCH.0 | Self::MODS.0 | Self::ENGINE_FLAGS.0);
    pub const MANAGED: Self = Self(Self::DETECTED.0 | Self::UNINSTALL.0 | Self::REVALIDATE.0);

    pub fn contains(self, other: Self) -> bool {
        self.0 & other.0 == other.0
    }

    pub fn remove(self, other: Self) -> Self {
        Self(self.0 & !other.0)
    }
}

#[derive(Debug, Clone)]
pub struct StudioInstallation {
    pub id: InstallationId,
    pub source: InstallationSource,
    pub install_dir: PathBuf,
    pub executable: PathBuf,
    pub version: Option<String>,
    pub version_guid: Option<String>,
    pub installed_at: Option<String>,
    pub capabilities: Capabilities,
}

impl StudioInstallation {
    pub fn new(
        source: InstallationSource,
        key: &str,
        install_dir: PathBuf,
        executable: PathBuf,
    ) -> Self {
        Self {
            id: InstallationId::new(source.slug(), key),
            source,
            install_dir,
            executable,
            version: None,
            version_guid: None,
            installed_at: None,
            capabilities: Capabilities::DETECTED,
        }
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn installation_id_is_namespaced_by_source() {
        let id = InstallationId::new("roblox-official", "version-abc123");

        assert_eq!(id.as_str(), "roblox-official:version-abc123");
    }

    #[test]
    fn sources_have_distinct_slugs() {
        let slugs = [
            InstallationSource::Managed.slug(),
            InstallationSource::RobloxOfficial.slug(),
            InstallationSource::Bloxstrap.slug(),
            InstallationSource::MacBundle.slug(),
            InstallationSource::Vinegar.slug(),
        ];

        let unique: std::collections::HashSet<_> = slugs.iter().collect();
        assert_eq!(unique.len(), slugs.len());
    }

    #[test]
    fn detected_installations_cannot_be_uninstalled_or_revalidated() {
        assert!(!Capabilities::DETECTED.contains(Capabilities::UNINSTALL));
        assert!(!Capabilities::DETECTED.contains(Capabilities::REVALIDATE));
        assert!(Capabilities::DETECTED.contains(Capabilities::LAUNCH));
        assert!(Capabilities::MANAGED.contains(Capabilities::UNINSTALL));
    }

    #[test]
    fn removing_a_capability_leaves_the_others() {
        let reduced = Capabilities::DETECTED.remove(Capabilities::MODS);

        assert!(!reduced.contains(Capabilities::MODS));
        assert!(reduced.contains(Capabilities::LAUNCH));
    }
}
