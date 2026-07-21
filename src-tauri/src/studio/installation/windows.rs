use std::fs;
use std::path::{Path, PathBuf};

use anyhow::Result;

use crate::Paths;

use super::{Capabilities, InstallationProvider, InstallationSource, StudioInstallation};

const STUDIO_EXECUTABLE: &str = "RobloxStudioBeta.exe";

#[cfg_attr(not(target_os = "windows"), allow(dead_code))]
pub(crate) struct WindowsProvider;

impl InstallationProvider for WindowsProvider {
    fn source(&self) -> InstallationSource {
        InstallationSource::RobloxOfficial
    }

    fn discover(&self, _paths: &Paths) -> Result<Vec<StudioInstallation>> {
        Ok(known_roots()
            .into_iter()
            .flat_map(|(source, root)| scan_root(source, &root))
            .collect())
    }
}

fn known_roots() -> Vec<(InstallationSource, PathBuf)> {
    let local = std::env::var_os("LOCALAPPDATA").map(PathBuf::from);
    let program_files = std::env::var_os("ProgramFiles(x86)").map(PathBuf::from);

    [
        (
            InstallationSource::RobloxOfficial,
            local.as_ref().map(|base| base.join("Roblox/Versions")),
        ),
        (
            InstallationSource::RobloxOfficial,
            program_files.map(|base| base.join("Roblox/Versions")),
        ),
        (
            InstallationSource::Bloxstrap,
            local.as_ref().map(|base| base.join("Bloxstrap/Versions")),
        ),
    ]
    .into_iter()
    .filter_map(|(source, root)| root.map(|root| (source, root)))
    .collect()
}

fn scan_root(source: InstallationSource, root: &Path) -> Vec<StudioInstallation> {
    let Ok(entries) = fs::read_dir(root) else {
        return Vec::new();
    };

    entries
        .flatten()
        .filter_map(|entry| {
            let install_dir = entry.path();
            let executable = install_dir.join(STUDIO_EXECUTABLE);

            if !executable.is_file() {
                return None;
            }

            let guid = install_dir.file_name()?.to_string_lossy().into_owned();
            let mut installation = StudioInstallation::new(source, &guid, install_dir, executable);
            installation.version_guid = Some(guid);
            installation.capabilities = Capabilities::DETECTED;

            Some(installation)
        })
        .collect()
}

#[cfg(test)]
mod tests {
    use super::*;

    fn scratch(name: &str) -> PathBuf {
        let dir = std::env::temp_dir().join(format!("rml-windows-{name}-{}", std::process::id()));
        let _ = fs::remove_dir_all(&dir);
        fs::create_dir_all(&dir).unwrap();
        dir
    }

    #[test]
    fn a_directory_holding_the_studio_executable_is_an_installation() {
        let root = scratch("valid");
        let version = root.join("version-abc123");
        fs::create_dir_all(&version).unwrap();
        fs::write(version.join(STUDIO_EXECUTABLE), b"").unwrap();

        let found = scan_root(InstallationSource::Bloxstrap, &root);

        assert_eq!(found.len(), 1);
        assert_eq!(found[0].version_guid.as_deref(), Some("version-abc123"));
        assert_eq!(found[0].id.as_str(), "bloxstrap:version-abc123");
        assert_eq!(found[0].executable, version.join(STUDIO_EXECUTABLE));
        assert!(!found[0].capabilities.contains(Capabilities::UNINSTALL));

        fs::remove_dir_all(&root).ok();
    }

    #[test]
    fn directories_without_the_studio_executable_are_skipped() {
        let root = scratch("player-only");
        let version = root.join("version-def456");
        fs::create_dir_all(&version).unwrap();
        fs::write(version.join("RobloxPlayerBeta.exe"), b"").unwrap();

        assert!(scan_root(InstallationSource::RobloxOfficial, &root).is_empty());

        fs::remove_dir_all(&root).ok();
    }

    #[test]
    fn a_missing_root_yields_nothing() {
        assert!(scan_root(InstallationSource::RobloxOfficial, Path::new("/definitely/not/here")).is_empty());
    }
}
