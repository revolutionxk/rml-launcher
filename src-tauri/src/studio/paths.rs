use std::path::{Path, PathBuf};

use crate::Paths;

pub fn studio_root_dir(paths: &Paths) -> PathBuf {
    paths.data_dir().join("studio")
}

pub fn versions_dir(paths: &Paths) -> PathBuf {
    studio_root_dir(paths).join("versions")
}

pub fn downloads_dir(paths: &Paths) -> PathBuf {
    studio_root_dir(paths).join("downloads")
}

pub fn settings_path(paths: &Paths) -> PathBuf {
    studio_root_dir(paths).join("settings.json")
}

pub fn version_install_dir(paths: &Paths, version_guid: &str) -> PathBuf {
    versions_dir(paths).join(version_guid)
}

pub fn version_download_dir(paths: &Paths, version_guid: &str) -> PathBuf {
    downloads_dir(paths).join(version_guid)
}

pub fn version_manifest_path(version_dir: &Path) -> PathBuf {
    version_dir.join("rml-studio.json")
}

#[cfg(target_os = "macos")]
pub fn version_bundle_path(version_dir: &Path) -> PathBuf {
    version_dir.join("RobloxStudio.app")
}

#[cfg(target_os = "macos")]
pub fn version_executable_path(version_dir: &Path) -> PathBuf {
    version_bundle_path(version_dir).join("Contents/MacOS/RobloxStudio")
}

#[cfg(not(target_os = "macos"))]
pub fn version_executable_path(version_dir: &Path) -> PathBuf {
    version_dir.join("RobloxStudioBeta.exe")
}

#[cfg(not(target_os = "macos"))]
pub fn version_launcher_path(version_dir: &Path) -> PathBuf {
    version_dir.join("RobloxStudioLauncherBeta.exe")
}

#[cfg(test)]
mod tests {
    use super::*;
    use std::path::Path;

    #[cfg(target_os = "macos")]
    #[test]
    fn macos_executable_lives_inside_the_app_bundle() {
        let version_dir = Path::new("/data/studio/versions/abc123");

        assert_eq!(
            version_executable_path(version_dir),
            Path::new("/data/studio/versions/abc123/RobloxStudio.app/Contents/MacOS/RobloxStudio")
        );
        assert_eq!(
            version_bundle_path(version_dir),
            Path::new("/data/studio/versions/abc123/RobloxStudio.app")
        );
    }

    #[cfg(not(target_os = "macos"))]
    #[test]
    fn non_macos_executable_is_a_bare_exe() {
        let version_dir = Path::new("/data/studio/versions/abc123");

        assert_eq!(
            version_executable_path(version_dir),
            Path::new("/data/studio/versions/abc123/RobloxStudioBeta.exe")
        );
    }
}
