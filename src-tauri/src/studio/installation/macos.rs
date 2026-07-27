#![cfg_attr(not(target_os = "macos"), allow(dead_code))]

use std::path::{Path, PathBuf};
use std::process::Command;

use anyhow::Result;
use plist::Value;

use crate::Paths;

use super::{Capabilities, InstallationProvider, InstallationSource, StudioInstallation};

const BUNDLE_IDENTIFIER: &str = "com.roblox.RobloxStudio";
const BUNDLE_EXECUTABLE: &str = "Contents/MacOS/RobloxStudio";

pub(crate) struct MacBundleProvider;

impl InstallationProvider for MacBundleProvider {
    fn source(&self) -> InstallationSource {
        InstallationSource::MacBundle
    }

    fn discover(&self, _paths: &Paths) -> Result<Vec<StudioInstallation>> {
        let mut candidates = fixed_roots();
        candidates.extend(spotlight_bundles());

        Ok(candidates
            .iter()
            .filter_map(|bundle| inspect_bundle(bundle))
            .collect())
    }
}

fn fixed_roots() -> Vec<PathBuf> {
    let mut roots = vec![PathBuf::from("/Applications/RobloxStudio.app")];

    if let Some(home) = std::env::var_os("HOME").map(PathBuf::from) {
        roots.push(home.join("Applications/RobloxStudio.app"));
    }

    roots
}

fn spotlight_bundles() -> Vec<PathBuf> {
    let query = format!("kMDItemCFBundleIdentifier ==[c] '{BUNDLE_IDENTIFIER}'");

    let Ok(output) = Command::new("mdfind").arg(&query).output() else {
        return Vec::new();
    };

    if !output.status.success() {
        return Vec::new();
    }

    String::from_utf8_lossy(&output.stdout)
        .lines()
        .map(|line| PathBuf::from(line.trim()))
        .filter(|path| !path.as_os_str().is_empty())
        .collect()
}

fn inspect_bundle(bundle: &Path) -> Option<StudioInstallation> {
    let executable = bundle.join(BUNDLE_EXECUTABLE);

    if !executable.is_file() {
        return None;
    }

    let info: Value = plist::from_file(bundle.join("Contents/Info.plist")).ok()?;
    let dictionary = info.as_dictionary()?;

    if !dictionary
        .get("CFBundleIdentifier")?
        .as_string()?
        .eq_ignore_ascii_case(BUNDLE_IDENTIFIER)
    {
        return None;
    }

    let mut installation = StudioInstallation::new(
        InstallationSource::MacBundle,
        &bundle.to_string_lossy(),
        bundle.to_path_buf(),
        executable,
    );
    installation.version = dictionary
        .get("CFBundleShortVersionString")
        .and_then(Value::as_string)
        .map(str::to_owned);
    installation.capabilities = Capabilities::LAUNCH;

    Some(installation)
}

#[cfg(test)]
mod tests {
    use super::*;
    use std::fs;

    fn scratch(name: &str) -> PathBuf {
        let dir = std::env::temp_dir().join(format!("rml-macos-{name}-{}", std::process::id()));
        let _ = fs::remove_dir_all(&dir);
        fs::create_dir_all(&dir).unwrap();
        dir
    }

    fn write_bundle(root: &Path, identifier: &str, version: &str) -> PathBuf {
        let bundle = root.join("RobloxStudio.app");
        fs::create_dir_all(bundle.join("Contents/MacOS")).unwrap();
        fs::write(bundle.join("Contents/MacOS/RobloxStudio"), b"").unwrap();
        fs::write(
            bundle.join("Contents/Info.plist"),
            format!(
                r#"<?xml version="1.0" encoding="UTF-8"?>
<plist version="1.0"><dict>
<key>CFBundleIdentifier</key><string>{identifier}</string>
<key>CFBundleShortVersionString</key><string>{version}</string>
</dict></plist>"#
            ),
        )
        .unwrap();
        bundle
    }

    #[test]
    fn a_studio_bundle_is_recognised_with_its_version() {
        let root = scratch("valid");
        let bundle = write_bundle(&root, BUNDLE_IDENTIFIER, "0.700.1");

        let installation = inspect_bundle(&bundle).unwrap();

        assert_eq!(installation.version.as_deref(), Some("0.700.1"));
        assert_eq!(
            installation.executable,
            bundle.join("Contents/MacOS/RobloxStudio")
        );
        assert!(installation.version_guid.is_none());
        assert_eq!(installation.install_dir, bundle);
        assert!(installation.capabilities.contains(Capabilities::LAUNCH));
        assert!(!installation.capabilities.contains(Capabilities::MODS));
        assert!(!installation.capabilities.contains(Capabilities::UNINSTALL));

        fs::remove_dir_all(&root).ok();
    }

    #[test]
    fn the_identifier_shipped_by_roblox_is_matched_regardless_of_case() {
        let root = scratch("case");
        let bundle = write_bundle(&root, "com.Roblox.RobloxStudio", "0.730.0");

        assert!(inspect_bundle(&bundle).is_some());

        fs::remove_dir_all(&root).ok();
    }

    #[test]
    fn the_nested_protocol_handler_bundle_is_rejected() {
        let root = scratch("nested");
        let bundle = write_bundle(&root, "com.Roblox.StudioProtocolHandler", "0.730.0");

        assert!(inspect_bundle(&bundle).is_none());

        fs::remove_dir_all(&root).ok();
    }

    #[test]
    fn a_bundle_with_a_foreign_identifier_is_rejected() {
        let root = scratch("foreign");
        let bundle = write_bundle(&root, "com.example.NotStudio", "1.0");

        assert!(inspect_bundle(&bundle).is_none());

        fs::remove_dir_all(&root).ok();
    }

    #[test]
    fn a_bundle_without_the_executable_is_rejected() {
        let root = scratch("no-exe");
        let bundle = write_bundle(&root, BUNDLE_IDENTIFIER, "1.0");
        fs::remove_file(bundle.join("Contents/MacOS/RobloxStudio")).unwrap();

        assert!(inspect_bundle(&bundle).is_none());

        fs::remove_dir_all(&root).ok();
    }

    #[test]
    fn two_bundles_at_different_paths_get_different_ids() {
        let root = scratch("ids");
        let first = write_bundle(&root.join("a"), BUNDLE_IDENTIFIER, "1.0");
        let second = write_bundle(&root.join("b"), BUNDLE_IDENTIFIER, "1.0");

        assert_ne!(
            inspect_bundle(&first).unwrap().id.as_str(),
            inspect_bundle(&second).unwrap().id.as_str()
        );

        fs::remove_dir_all(&root).ok();
    }
}
