use std::path::Path;

use anyhow::{Context, Result};
use tokio::fs as tokio_fs;

use crate::store::{read_json, write_json};

use super::{model::ModLoaderInstalled, paths::version_manifest_path};

pub fn load_manifest(install_dir: &Path) -> Result<Option<ModLoaderInstalled>> {
    read_json(&version_manifest_path(install_dir))
}

pub async fn save_manifest(install_dir: &Path, manifest: &ModLoaderInstalled) -> Result<()> {
    write_json(&version_manifest_path(install_dir), manifest).await
}

pub async fn remove_manifest(install_dir: &Path) -> Result<()> {
    let path = version_manifest_path(install_dir);

    if path.exists() {
        tokio_fs::remove_file(&path)
            .await
            .with_context(|| format!("failed to remove {}", path.display()))?;
    }

    Ok(())
}
