use std::future::Future;
use std::path::PathBuf;

use anyhow::Result;

use super::progress::StudioProgressSink;
use super::model::InstalledStudioManifest;

#[cfg(target_os = "macos")]
mod macos;
#[cfg(not(target_os = "macos"))]
mod windows;

pub trait StudioDeployment {
    #[allow(clippy::too_many_arguments)]
    fn install<S: StudioProgressSink + Send + Sync>(
        &self,
        sink: &S,
        install_dir: PathBuf,
        download_dir: PathBuf,
        version_guid: &str,
        version: &str,
        channel: &str,
        published_at: Option<&str>,
    ) -> impl Future<Output = Result<InstalledStudioManifest>> + Send;
}

#[cfg(target_os = "macos")]
pub fn active_deployment() -> impl StudioDeployment {
    macos::MacDeployment
}

#[cfg(not(target_os = "macos"))]
pub fn active_deployment() -> impl StudioDeployment {
    windows::WindowsDeployment
}
