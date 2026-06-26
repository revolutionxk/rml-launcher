use std::path::PathBuf;

use anyhow::Result;
use serde::Serialize;
use tauri::AppHandle;

use crate::{
    modloader::{installed_manifest, ModLoaderInstalled},
    mods::count_mods,
    studio::{installed_instances, StudioVersionEntry},
};

#[derive(Debug, Clone, Serialize)]
#[serde(rename_all = "camelCase")]
pub struct InstanceSummary {
    #[serde(flatten)]
    pub studio: StudioVersionEntry,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub modloader: Option<ModLoaderInstalled>,
    pub mods_total: usize,
    pub mods_enabled: usize,
}

#[tauri::command]
pub async fn list_instances(app: AppHandle) -> Result<Vec<InstanceSummary>, String> {
    let versions = installed_instances(&app).map_err(|error| error.to_string())?;

    Ok(versions.into_iter().map(build_summary).collect())
}

fn build_summary(studio: StudioVersionEntry) -> InstanceSummary {
    let install_dir = studio.install_dir.as_deref().map(PathBuf::from);

    let (modloader, mods_enabled, mods_total) = match install_dir.as_deref() {
        Some(dir) => {
            let (enabled, total) = count_mods(dir);
            (installed_manifest(dir), enabled, total)
        }
        None => (None, 0, 0),
    };

    InstanceSummary {
        studio,
        modloader,
        mods_total,
        mods_enabled,
    }
}
