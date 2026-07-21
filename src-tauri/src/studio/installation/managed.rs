use std::fs;

use anyhow::Result;

use crate::studio::paths::{version_executable_path, version_manifest_path, versions_dir};
use crate::studio::storage::read_installed_manifest;
use crate::Paths;

use super::{Capabilities, InstallationProvider, InstallationSource, StudioInstallation};

pub(crate) struct ManagedProvider;

impl InstallationProvider for ManagedProvider {
    fn source(&self) -> InstallationSource {
        InstallationSource::Managed
    }

    fn discover(&self, paths: &Paths) -> Result<Vec<StudioInstallation>> {
        let versions = versions_dir(paths);

        if !versions.exists() {
            return Ok(Vec::new());
        }

        let mut installations = Vec::new();

        for entry in fs::read_dir(&versions)? {
            let install_dir = entry?.path();

            if !install_dir.is_dir() {
                continue;
            }

            let Ok(manifest) = read_installed_manifest(&version_manifest_path(&install_dir)) else {
                continue;
            };

            let mut installation = StudioInstallation::new(
                InstallationSource::Managed,
                &manifest.version_guid,
                install_dir.clone(),
                version_executable_path(&install_dir),
            );
            installation.version = Some(manifest.version);
            installation.version_guid = Some(manifest.version_guid);
            installation.channel = Some(manifest.channel);
            installation.installed_at = Some(manifest.installed_at);
            installation.published_at = manifest.published_at;
            installation.integrity_verified_at = manifest.integrity_verified_at;
            installation.capabilities = Capabilities::MANAGED;

            installations.push(installation);
        }

        Ok(installations)
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use std::path::{Path, PathBuf};

    fn scratch(name: &str) -> PathBuf {
        let dir = std::env::temp_dir().join(format!("rml-managed-{name}-{}", std::process::id()));
        let _ = fs::remove_dir_all(&dir);
        fs::create_dir_all(&dir).unwrap();
        dir
    }

    fn write_managed_version(versions: &Path, guid: &str) {
        let dir = versions.join(guid);
        fs::create_dir_all(&dir).unwrap();
        fs::write(
            dir.join("rml-studio.json"),
            format!(
                r#"{{"versionGuid":"{guid}","version":"1.2.3","channel":"LIVE","binaryTarget":"WindowsStudio64","installedAt":"2026-01-01T00:00:00Z"}}"#
            ),
        )
        .unwrap();
    }

    #[test]
    fn discovers_managed_versions_with_full_capabilities() {
        let data_dir = scratch("full");
        let versions = data_dir.join("studio/versions");
        write_managed_version(&versions, "version-aaa");

        let found = ManagedProvider
            .discover(&Paths::for_test(data_dir.clone()))
            .unwrap();

        assert_eq!(found.len(), 1);
        assert_eq!(found[0].version_guid.as_deref(), Some("version-aaa"));
        assert_eq!(found[0].version.as_deref(), Some("1.2.3"));
        assert_eq!(found[0].id.as_str(), "managed:version-aaa");
        assert!(found[0].capabilities.contains(Capabilities::UNINSTALL));

        fs::remove_dir_all(&data_dir).ok();
    }

    #[test]
    fn ignores_directories_without_a_manifest() {
        let data_dir = scratch("nomanifest");
        fs::create_dir_all(data_dir.join("studio/versions/version-bbb")).unwrap();

        let found = ManagedProvider
            .discover(&Paths::for_test(data_dir.clone()))
            .unwrap();

        assert!(found.is_empty());

        fs::remove_dir_all(&data_dir).ok();
    }

    #[test]
    fn a_missing_versions_root_is_not_an_error() {
        let data_dir = scratch("missing");

        assert!(ManagedProvider
            .discover(&Paths::for_test(data_dir.clone()))
            .unwrap()
            .is_empty());

        fs::remove_dir_all(&data_dir).ok();
    }
}
