mod api;
mod installer;
mod model;
mod paths;
mod storage;

use std::path::Path;

use tauri::{AppHandle, Emitter, State};
use tokio::sync::Mutex;
use tracing::info;

use crate::{studio::installed_studio_target, AppError, CommandResult, Paths};

use self::{
    installer::{install_release, remove_from_install_dir, InstallProgressSink, INSTALL_EVENT},
    model::ModLoaderInstallProgress,
    paths::release_cache_dir,
    storage::{load_manifest, remove_manifest},
};

pub use self::model::{ModLoaderInstalled, ModLoaderRelease};

struct EventSink<'a> {
    app: &'a AppHandle,
}

impl InstallProgressSink for EventSink<'_> {
    fn report(&self, progress: ModLoaderInstallProgress) {
        let _ = self.app.emit(INSTALL_EVENT, progress);
    }
}

#[derive(Default)]
pub struct ModLoaderState {
    install_lock: Mutex<()>,
}

#[tauri::command]
pub async fn list_modloader_releases() -> CommandResult<Vec<ModLoaderRelease>> {
    Ok(api::fetch_releases().await?)
}

#[tauri::command]
pub async fn get_modloader_status(
    app: AppHandle,
    version_guid: String,
) -> CommandResult<Option<ModLoaderInstalled>> {
    let install_dir = installed_studio_target(&app, &version_guid)?;

    Ok(load_manifest(&install_dir)?)
}

#[tauri::command]
pub async fn install_modloader(
    app: AppHandle,
    state: State<'_, ModLoaderState>,
    version_guid: String,
    tag: String,
) -> CommandResult<ModLoaderInstalled> {
    let _guard = state
        .install_lock
        .try_lock()
        .map_err(|_| AppError::Failed("A mod loader operation is already in progress.".into()))?;

    info!(version_guid, tag, "installing mod loader release into Studio version");

    let install_dir = installed_studio_target(&app, &version_guid)?;
    let release = api::fetch_release(&tag).await?;
    let cache_dir = release_cache_dir(&Paths::resolve(&app)?, &release.tag);

    let sink = EventSink { app: &app };
    let manifest = install_release(&sink, cache_dir, &release, &version_guid, &install_dir).await?;

    set_vinegar_dwmapi_override(&version_guid, true);

    Ok(manifest)
}

#[tauri::command]
pub async fn uninstall_modloader(
    app: AppHandle,
    state: State<'_, ModLoaderState>,
    version_guid: String,
) -> CommandResult<()> {
    let _guard = state
        .install_lock
        .try_lock()
        .map_err(|_| AppError::Failed("A mod loader operation is already in progress.".into()))?;

    let install_dir = installed_studio_target(&app, &version_guid)?;

    let Some(manifest) = load_manifest(&install_dir)? else {
        return Ok(());
    };

    remove_from_install_dir(&install_dir, &manifest.artifacts).await?;
    remove_manifest(&install_dir).await?;

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
