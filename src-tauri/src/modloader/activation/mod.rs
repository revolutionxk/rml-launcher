use std::path::Path;

use anyhow::Result;

#[cfg(target_os = "macos")]
mod codesign;
#[cfg(target_os = "macos")]
mod macho;

#[cfg(target_os = "linux")]
mod linux;
#[cfg(target_os = "macos")]
mod macos;
#[cfg(target_os = "windows")]
mod windows;

pub struct ActivationContext<'a> {
    pub installation_id: &'a str,
    pub install_dir: &'a Path,
}

pub trait LoaderActivation {
    fn activate(&self, context: &ActivationContext<'_>) -> Result<()>;
    fn deactivate(&self, context: &ActivationContext<'_>) -> Result<()>;
}

pub fn activation() -> Box<dyn LoaderActivation> {
    #[cfg(target_os = "macos")]
    {
        Box::new(macos::MacosActivation)
    }
    #[cfg(target_os = "windows")]
    {
        Box::new(windows::WindowsActivation)
    }
    #[cfg(target_os = "linux")]
    {
        Box::new(linux::LinuxActivation)
    }
}
