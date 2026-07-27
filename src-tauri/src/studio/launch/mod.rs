use std::path::Path;

use anyhow::Result;

#[cfg(target_os = "linux")]
mod linux;
#[cfg(target_os = "macos")]
mod macos;
#[cfg(target_os = "windows")]
mod windows;

pub trait StudioLauncher {
    fn launch(&self, install_dir: &Path, uri: Option<&str>) -> Result<()>;
}

#[cfg(target_os = "windows")]
pub fn active_launcher() -> impl StudioLauncher {
    windows::WindowsLauncher
}

#[cfg(target_os = "macos")]
pub fn active_launcher() -> impl StudioLauncher {
    macos::MacosLauncher
}

#[cfg(target_os = "linux")]
pub fn active_launcher() -> impl StudioLauncher {
    linux::LinuxLauncher
}
