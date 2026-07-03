use std::path::{Path, PathBuf};

use crate::Paths;

pub fn engine_root_dir(paths: &Paths) -> PathBuf {
    paths.data_dir().join("engine")
}

pub fn preferences_path(paths: &Paths) -> PathBuf {
    engine_root_dir(paths).join("settings.json")
}

pub fn scan_cache_dir(paths: &Paths) -> PathBuf {
    engine_root_dir(paths).join("scans")
}

pub fn scan_cache_path(paths: &Paths, version_guid: &str) -> PathBuf {
    scan_cache_dir(paths).join(format!("{version_guid}.json"))
}

pub fn client_settings_dir(install_dir: &Path) -> PathBuf {
    install_dir.join("ClientSettings")
}

pub fn client_app_settings_path(install_dir: &Path) -> PathBuf {
    client_settings_dir(install_dir).join("ClientAppSettings.json")
}

pub fn extra_content_dir(install_dir: &Path) -> PathBuf {
    install_dir.join("ExtraContent")
}
