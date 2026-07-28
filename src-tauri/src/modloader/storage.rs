use std::path::Path;

use anyhow::{Context, Result};
use tokio::fs as tokio_fs;

use crate::store::{read_json, write_json};
use crate::Paths;

use super::{
    model::{ModLoaderInstalled, ModLoaderSubscriptions},
    paths::{subscriptions_path, version_manifest_path},
};

pub fn load_manifest(payload_dir: &Path) -> Result<Option<ModLoaderInstalled>> {
    read_json(&version_manifest_path(payload_dir))
}

pub fn load_subscriptions(paths: &Paths) -> Result<ModLoaderSubscriptions> {
    Ok(read_json(&subscriptions_path(paths))?.unwrap_or_default())
}

pub async fn save_subscriptions(paths: &Paths, subscriptions: &ModLoaderSubscriptions) -> Result<()> {
    write_json(&subscriptions_path(paths), subscriptions).await
}

pub async fn save_manifest(payload_dir: &Path, manifest: &ModLoaderInstalled) -> Result<()> {
    write_json(&version_manifest_path(payload_dir), manifest).await
}

pub async fn remove_manifest(payload_dir: &Path) -> Result<()> {
    let path = version_manifest_path(payload_dir);

    if path.exists() {
        tokio_fs::remove_file(&path)
            .await
            .with_context(|| format!("failed to remove {}", path.display()))?;
    }

    Ok(())
}
