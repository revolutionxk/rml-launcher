mod api;
mod installer;
mod model;
mod paths;
mod storage;

use std::path::Path;

use anyhow::Result;
use tauri::{AppHandle, State};
use tokio::sync::Mutex;
use tracing::info;

use crate::studio::installed_studio_target;

use self::{
    installer::{install_release, remove_from_install_dir},
    storage::{load_manifest, remove_manifest},
};

pub use self::model::{ModLoaderInstalled, ModLoaderRelease};

#[derive(Default)]
pub struct ModLoaderState {
    install_lock: Mutex<()>,
}

#[tauri::command]
pub async fn list_modloader_releases() -> Result<Vec<ModLoaderRelease>, String> {
    api::fetch_releases().await.map_err(|error| error.to_string())
}

#[tauri::command]
pub async fn get_modloader_status(
    app: AppHandle,
    version_guid: String,
) -> Result<Option<ModLoaderInstalled>, String> {
    let install_dir = installed_studio_target(&app, &version_guid).map_err(|error| error.to_string())?;

    load_manifest(&install_dir).map_err(|error| error.to_string())
}

#[tauri::command]
pub async fn install_modloader(
    app: AppHandle,
    state: State<'_, ModLoaderState>,
    version_guid: String,
    tag: String,
) -> Result<ModLoaderInstalled, String> {
    let _guard = state
        .install_lock
        .try_lock()
        .map_err(|_| "A mod loader operation is already in progress.".to_string())?;

    info!(version_guid, tag, "installing mod loader release into Studio version");

    let install_dir = installed_studio_target(&app, &version_guid).map_err(|error| error.to_string())?;
    let release = api::fetch_release(&tag).await.map_err(|error| error.to_string())?;

    let manifest = install_release(&app, &release, &version_guid, &install_dir)
        .await
        .map_err(|error| error.to_string())?;

    set_vinegar_dwmapi_override(&version_guid, true);

    Ok(manifest)
}

#[tauri::command]
pub async fn uninstall_modloader(
    app: AppHandle,
    state: State<'_, ModLoaderState>,
    version_guid: String,
) -> Result<(), String> {
    let _guard = state
        .install_lock
        .try_lock()
        .map_err(|_| "A mod loader operation is already in progress.".to_string())?;

    let install_dir = installed_studio_target(&app, &version_guid).map_err(|error| error.to_string())?;

    let Some(manifest) = load_manifest(&install_dir).map_err(|error| error.to_string())? else {
        return Ok(());
    };

    remove_from_install_dir(&install_dir, &manifest.artifacts)
        .await
        .map_err(|error| error.to_string())?;
    remove_manifest(&install_dir)
        .await
        .map_err(|error| error.to_string())?;

    set_vinegar_dwmapi_override(&version_guid, false);

    info!(version_guid, tag = %manifest.tag, "mod loader uninstalled from Studio version");

    Ok(())
}

pub(crate) fn installed_manifest(install_dir: &Path) -> Option<ModLoaderInstalled> {
    load_manifest(install_dir).ok().flatten()
}

fn set_vinegar_dwmapi_override(version_guid: &str, enabled: bool) {
    #[cfg(target_os = "linux")]
    if version_guid == crate::vinegar::INSTANCE_ID {
        if let Err(error) = crate::vinegar::set_dwmapi_override(enabled) {
            tracing::warn!(error = %error, "failed to update the Vinegar dwmapi override");
        }
    }

    let _ = (version_guid, enabled);
}
