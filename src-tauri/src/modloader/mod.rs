mod activation;
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
    activation::{activation, ActivationContext},
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
    installation_id: String,
) -> CommandResult<Option<ModLoaderInstalled>> {
    let install_dir = installed_studio_target(&app, &installation_id)?;

    Ok(load_manifest(&install_dir)?)
}

#[tauri::command]
pub async fn install_modloader(
    app: AppHandle,
    state: State<'_, ModLoaderState>,
    installation_id: String,
    tag: String,
) -> CommandResult<ModLoaderInstalled> {
    let _guard = state
        .install_lock
        .try_lock()
        .map_err(|_| AppError::Failed("A mod loader operation is already in progress.".into()))?;

    info!(installation_id, tag, "installing mod loader release into Studio version");

    let install_dir = installed_studio_target(&app, &installation_id)?;
    let release = api::fetch_release(&tag).await?;
    let cache_dir = release_cache_dir(&Paths::resolve(&app)?, &release.tag);

    let sink = EventSink { app: &app };
    let manifest = install_release(&sink, cache_dir, &release, &installation_id, &install_dir).await?;

    activate_loader(&installation_id, &install_dir).await?;

    Ok(manifest)
}

#[tauri::command]
pub async fn uninstall_modloader(
    app: AppHandle,
    state: State<'_, ModLoaderState>,
    installation_id: String,
) -> CommandResult<()> {
    let _guard = state
        .install_lock
        .try_lock()
        .map_err(|_| AppError::Failed("A mod loader operation is already in progress.".into()))?;

    let install_dir = installed_studio_target(&app, &installation_id)?;

    let Some(manifest) = load_manifest(&install_dir)? else {
        return Ok(());
    };

    deactivate_loader(&installation_id, &install_dir).await?;

    remove_from_install_dir(&install_dir, &manifest.artifacts).await?;
    remove_manifest(&install_dir).await?;

    info!(installation_id, tag = %manifest.tag, "mod loader uninstalled from Studio version");

    Ok(())
}

pub(crate) fn installed_manifest(install_dir: &Path) -> Option<ModLoaderInstalled> {
    load_manifest(install_dir).ok().flatten()
}

async fn activate_loader(installation_id: &str, install_dir: &Path) -> Result<(), AppError> {
    run_activation(installation_id, install_dir, Activation::Activate).await
}

async fn deactivate_loader(installation_id: &str, install_dir: &Path) -> Result<(), AppError> {
    run_activation(installation_id, install_dir, Activation::Deactivate).await
}

enum Activation {
    Activate,
    Deactivate,
}

async fn run_activation(installation_id: &str, install_dir: &Path, action: Activation) -> Result<(), AppError> {
    let installation_id = installation_id.to_string();
    let install_dir = install_dir.to_path_buf();

    tokio::task::spawn_blocking(move || {
        let backend = activation();
        let context = ActivationContext {
            installation_id: &installation_id,
            install_dir: &install_dir,
        };

        match action {
            Activation::Activate => backend.activate(&context),
            Activation::Deactivate => backend.deactivate(&context),
        }
    })
    .await?
    .map_err(AppError::from)
}
