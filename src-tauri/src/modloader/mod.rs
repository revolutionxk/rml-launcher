mod activation;
mod api;
mod installer;
mod model;
mod paths;
mod reconcile;
mod storage;

use std::path::Path;

use tauri::{AppHandle, Emitter, State};
use tokio::sync::Mutex;
use tracing::info;

use crate::{
    studio::{installation::{InstallationSource, StudioInstallation}, resolve_installation},
    AppError, CommandResult, Paths,
};

use self::{
    activation::{activation, ActivationContext},
    installer::{install_release, remove_payload, InstallProgressSink, INSTALL_EVENT},
    model::{ModLoaderInstallProgress, ModLoaderPayload},
    paths::release_cache_dir,
    storage::{load_manifest, load_subscriptions, remove_manifest, save_subscriptions},
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
    let installation = resolve_installation(&app, &installation_id)?;

    Ok(load_manifest(&installation.payload_dir())?)
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

    let paths = Paths::resolve(&app)?;
    let installation = resolve_installation(&app, &installation_id)?;
    let payload_dir = installation.payload_dir();
    let payload = api::fetch_release(&tag).await?.payload();
    let cache_dir = release_cache_dir(&paths, &payload.tag);

    let sink = EventSink { app: &app };
    let manifest = install_release(&sink, cache_dir, &payload, &installation_id, &payload_dir).await?;

    activate_loader(&installation).await?;
    subscribe(&paths, installation.source, payload).await?;

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

    let paths = Paths::resolve(&app)?;
    let installation = resolve_installation(&app, &installation_id)?;
    let payload_dir = installation.payload_dir();

    unsubscribe(&paths, installation.source).await?;

    let Some(manifest) = load_manifest(&payload_dir)? else {
        return Ok(());
    };

    deactivate_loader(&installation).await?;

    remove_payload(&payload_dir, &manifest.artifacts).await?;
    remove_manifest(&payload_dir).await?;

    info!(installation_id, tag = %manifest.tag, "mod loader uninstalled from Studio version");

    Ok(())
}

pub(crate) async fn reapply_missing(app: &AppHandle, state: &ModLoaderState) -> Result<(), AppError> {
    let Ok(_guard) = state.install_lock.try_lock() else {
        return Ok(());
    };

    reconcile::reapply_missing(app).await
}

pub(crate) async fn reapply_to(
    app: &AppHandle,
    state: &ModLoaderState,
    installation: &StudioInstallation,
) -> Result<(), AppError> {
    let _guard = state
        .install_lock
        .try_lock()
        .map_err(|_| AppError::Failed("A mod loader operation is already in progress.".into()))?;

    reconcile::reapply_to(app, installation).await
}

async fn subscribe(paths: &Paths, source: InstallationSource, payload: ModLoaderPayload) -> Result<(), AppError> {
    let mut subscriptions = load_subscriptions(paths)?;
    subscriptions.insert(source.slug().to_string(), payload);
    save_subscriptions(paths, &subscriptions).await?;

    Ok(())
}

async fn unsubscribe(paths: &Paths, source: InstallationSource) -> Result<(), AppError> {
    let mut subscriptions = load_subscriptions(paths)?;

    if subscriptions.remove(source.slug()).is_some() {
        save_subscriptions(paths, &subscriptions).await?;
    }

    Ok(())
}

pub(crate) fn installed_manifest(payload_dir: &Path) -> Option<ModLoaderInstalled> {
    load_manifest(payload_dir).ok().flatten()
}

async fn activate_loader(installation: &StudioInstallation) -> Result<(), AppError> {
    run_activation(installation, Activation::Activate).await
}

async fn deactivate_loader(installation: &StudioInstallation) -> Result<(), AppError> {
    run_activation(installation, Activation::Deactivate).await
}

enum Activation {
    Activate,
    Deactivate,
}

async fn run_activation(installation: &StudioInstallation, action: Activation) -> Result<(), AppError> {
    let installation_id = installation.id.to_string();
    let install_dir = installation.install_dir.clone();
    let payload_dir = installation.payload_dir();

    tokio::task::spawn_blocking(move || {
        let backend = activation();
        let context = ActivationContext {
            installation_id: &installation_id,
            install_dir: &install_dir,
            payload_dir: &payload_dir,
        };

        match action {
            Activation::Activate => backend.activate(&context),
            Activation::Deactivate => backend.deactivate(&context),
        }
    })
    .await?
    .map_err(AppError::from)
}
