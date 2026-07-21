use std::path::PathBuf;

use std::future::Future;

use anyhow::Result;

use super::super::installer::install_version;
use super::super::progress::StudioProgressSink;
use super::super::model::InstalledStudioManifest;
use super::StudioDeployment;

pub struct WindowsDeployment;

impl StudioDeployment for WindowsDeployment {
    fn install<S: StudioProgressSink + Send + Sync>(
        &self,
        sink: &S,
        install_dir: PathBuf,
        download_dir: PathBuf,
        version_guid: &str,
        version: &str,
        channel: &str,
        published_at: Option<&str>,
    ) -> impl Future<Output = Result<InstalledStudioManifest>> + Send {
        install_version(sink, install_dir, download_dir, version_guid, version, channel, published_at)
    }
}
