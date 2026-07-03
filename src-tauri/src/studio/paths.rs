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

pub fn version_executable_path(version_dir: &Path) -> PathBuf {
    version_dir.join("RobloxStudioBeta.exe")
}

pub fn version_launcher_path(version_dir: &Path) -> PathBuf {
    version_dir.join("RobloxStudioLauncherBeta.exe")
}
