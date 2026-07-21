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

    activate_loader(&version_guid, &install_dir).await?;

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

    deactivate_loader(&version_guid, &install_dir).await?;

    remove_from_install_dir(&install_dir, &manifest.artifacts).await?;
    remove_manifest(&install_dir).await?;

    info!(version_guid, tag = %manifest.tag, "mod loader uninstalled from Studio version");

    Ok(())
}

pub(crate) fn installed_manifest(install_dir: &Path) -> Option<ModLoaderInstalled> {
    load_manifest(install_dir).ok().flatten()
}

async fn activate_loader(version_guid: &str, install_dir: &Path) -> Result<(), AppError> {
    run_activation(version_guid, install_dir, Activation::Activate).await
}

async fn deactivate_loader(version_guid: &str, install_dir: &Path) -> Result<(), AppError> {
    run_activation(version_guid, install_dir, Activation::Deactivate).await
}

enum Activation {
    Activate,
    Deactivate,
}

async fn run_activation(version_guid: &str, install_dir: &Path, action: Activation) -> Result<(), AppError> {
    let version_guid = version_guid.to_string();
    let install_dir = install_dir.to_path_buf();

    tokio::task::spawn_blocking(move || {
        let backend = activation();
        let context = ActivationContext {
            version_guid: &version_guid,
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
