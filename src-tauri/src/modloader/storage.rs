use std::path::Path;

use anyhow::{Context, Result};
use tokio::fs as tokio_fs;

use super::{model::ModLoaderInstalled, paths::version_manifest_path};

pub fn load_manifest(install_dir: &Path) -> Result<Option<ModLoaderInstalled>> {
    let path = version_manifest_path(install_dir);

    if !path.exists() {
        return Ok(None);
    }

    let bytes = std::fs::read(&path).with_context(|| format!("failed to read {}", path.display()))?;
    let manifest = serde_json::from_slice(&bytes)
        .with_context(|| format!("failed to parse {}", path.display()))?;

    Ok(Some(manifest))
}

pub async fn save_manifest(install_dir: &Path, manifest: &ModLoaderInstalled) -> Result<()> {
    let path = version_manifest_path(install_dir);

    if let Some(parent) = path.parent() {
        tokio_fs::create_dir_all(parent)
            .await
            .with_context(|| format!("failed to create {}", parent.display()))?;
    }

    let bytes = serde_json::to_vec_pretty(manifest).context("failed to serialize the mod loader manifest")?;
    tokio_fs::write(&path, bytes)
        .await
        .with_context(|| format!("failed to write {}", path.display()))?;

    Ok(())
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
