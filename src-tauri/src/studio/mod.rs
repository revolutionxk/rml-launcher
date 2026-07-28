mod api;
mod config;
mod deployment;
mod launch;
mod progress;
pub(crate) mod engine;
pub(crate) mod installation;
#[cfg(not(target_os = "macos"))]
mod installer;
mod model;
pub(crate) mod paths;
pub(crate) mod storage;

use std::path::PathBuf;

use anyhow::{bail, Context, Result};
use tauri::{AppHandle, Emitter, State};
use tokio::{fs as tokio_fs, sync::Mutex};
use tracing::{info, warn};

use crate::{modloader::ModLoaderState, AppError, CommandResult, Paths};

use self::{
    config::{CURRENT_CHANNEL, STUDIO_INSTALL_EVENT},
    engine::apply_saved_preferences_to_install_dir,
    deployment::{active_deployment, StudioDeployment},
    launch::{active_launcher, StudioLauncher},
    progress::StudioProgressSink,
    model::{StudioBuild, StudioInstallProgress, StudioVersionsResponse},
    installation::{Capabilities, StudioInstallation},
    paths::{
        version_download_dir, version_executable_path, version_install_dir,
    },
    storage::{load_studio_preferences, save_studio_preferences},
};

#[cfg(not(target_os = "macos"))]
use self::installer::revalidate_version;

#[cfg(not(target_os = "macos"))]
use self::paths::downloads_dir;

pub(crate) use self::model::StudioVersionEntry;

#[derive(Default)]
pub struct StudioState {
    install_lock: Mutex<()>,
}

struct EventSink<'a> {
    app: &'a AppHandle,
}

impl StudioProgressSink for EventSink<'_> {
    fn report(&self, progress: StudioInstallProgress) {
        let _ = self.app.emit(STUDIO_INSTALL_EVENT, progress);
    }
}

pub(crate) fn installed_instances(app: &AppHandle) -> Result<Vec<StudioVersionEntry>> {
    let paths = Paths::resolve(app)?;
    let preferences = load_studio_preferences(&paths).unwrap_or_default();
    let default_id = preferences.default_installation_id.as_deref();

    let mut versions: Vec<StudioVersionEntry> = installation::discover(&paths)
        .iter()
        .map(StudioVersionEntry::from_installation)
        .collect();

    if let Some(default_id) = default_id {
        for version in versions.iter_mut() {
            version.is_default = version.id == default_id;
        }
    }

    versions.sort_by(|left, right| {
        right
            .is_default
            .cmp(&left.is_default)
            .then_with(|| right.installed_at.cmp(&left.installed_at))
            .then_with(|| right.version.cmp(&left.version))
    });

    Ok(versions)
}

pub(crate) fn loader_payload_dir(app: &AppHandle, installation_id: &str) -> Result<PathBuf> {
    Ok(resolve_installation(app, installation_id)?.payload_dir())
}

pub(crate) fn resolve_installation(app: &AppHandle, installation_id: &str) -> Result<StudioInstallation> {
    let paths = Paths::resolve(app)?;

    installation::resolve(&paths, installation_id)
        .context("The selected Studio installation is no longer available.")
}

fn require(installation: &StudioInstallation, capability: Capabilities) -> Result<()> {
    if !installation.capabilities.contains(capability) {
        bail!("This action is not available for the selected Studio installation.");
    }

    Ok(())
}

#[tauri::command]
pub async fn list_studio_versions(
    app: AppHandle,
    loader: State<'_, ModLoaderState>,
) -> CommandResult<StudioVersionsResponse> {
    if let Err(error) = crate::modloader::reapply_missing(&app, &loader).await {
        warn!(%error, "failed to reapply the mod loader to updated Studio installations");
    }

    Ok(list_studio_versions_inner(&app).await?)
}

#[tauri::command]
pub async fn install_latest_studio(
    app: AppHandle,
    state: State<'_, StudioState>,
) -> CommandResult<StudioVersionEntry> {
    let _guard = state
        .install_lock
        .try_lock()
        .map_err(|_| AppError::Failed("A Studio installation is already in progress.".into()))?;

    let version_info = api::fetch_current_version(CURRENT_CHANNEL).await?;

    info!(
        channel = CURRENT_CHANNEL,
        version = %version_info.version,
        version_guid = %version_info.client_version_upload,
        "installing latest Studio version"
    );

    Ok(install_studio_version_inner(
        &app,
        &version_info.client_version_upload,
        &version_info.version,
        CURRENT_CHANNEL,
        None,
    )
    .await?)
}

#[tauri::command]
pub async fn install_studio_version(
    app: AppHandle,
    state: State<'_, StudioState>,
    version_guid: String,
    version: String,
    channel: Option<String>,
    published_at: Option<String>,
) -> CommandResult<StudioVersionEntry> {
    let _guard = state
        .install_lock
        .try_lock()
        .map_err(|_| AppError::Failed("A Studio installation is already in progress.".into()))?;

    let channel = channel.unwrap_or_else(|| CURRENT_CHANNEL.to_string());

    info!(version_guid, version, channel, "installing requested Studio version");

    Ok(install_studio_version_inner(&app, &version_guid, &version, &channel, published_at.as_deref())
        .await?)
}

#[tauri::command]
pub async fn set_default_studio_version(
    app: AppHandle,
    installation_id: Option<String>,
) -> CommandResult<()> {
    let paths = Paths::resolve(&app)?;
    let mut preferences = load_studio_preferences(&paths)?;

    preferences.default_installation_id = match installation_id {
        Some(installation_id) => {
            let target = installation::resolve(&paths, &installation_id).ok_or_else(|| {
                AppError::Failed("The selected Studio installation is no longer available.".into())
            })?;

            Some(target.id.to_string())
        }
        None => None,
    };

    Ok(save_studio_preferences(&paths, &preferences).await?)
}

#[tauri::command]
pub async fn launch_studio(
    app: AppHandle,
    loader: State<'_, ModLoaderState>,
    installation_id: String,
    uri: Option<String>,
) -> CommandResult<()> {
    Ok(launch_studio_inner(&app, &loader, &installation_id, uri.as_deref()).await?)
}

async fn launch_studio_inner(
    app: &AppHandle,
    loader: &ModLoaderState,
    installation_id: &str,
    uri: Option<&str>,
) -> Result<()> {
    let paths = Paths::resolve(app)?;
    let installation = resolve_installation(app, installation_id)?;
    require(&installation, Capabilities::LAUNCH)?;

    crate::modloader::reapply_to(app, loader, &installation).await?;

    if installation.capabilities.contains(Capabilities::ENGINE_FLAGS) {
        apply_saved_preferences_to_install_dir(&paths, &installation.install_dir).await?;
    }

    let install_dir = installation.install_dir;
    let uri = uri.map(str::to_string);
    tokio::task::spawn_blocking(move || active_launcher().launch(&install_dir, uri.as_deref()))
        .await
        .context("the Studio launch task failed to join")?
}

#[tauri::command]
pub async fn revalidate_studio_version(
    app: AppHandle,
    state: State<'_, StudioState>,
    installation_id: String,
) -> CommandResult<StudioVersionEntry> {
    let _guard = state.install_lock.try_lock().map_err(|_| {
        AppError::Failed("Cannot revalidate Studio while another installation is running.".into())
    })?;

    #[cfg(target_os = "macos")]
    {
        let _ = (&app, &installation_id);
        return Err(AppError::unsupported(
            "Revalidation is not available for macOS Studio yet.",
        ));
    }

    #[cfg(not(target_os = "macos"))]
    {
        let paths = Paths::resolve(&app)?;
        let installation = resolve_installation(&app, &installation_id)?;
        require(&installation, Capabilities::REVALIDATE)?;

        let version_guid = installation
            .version_guid
            .clone()
            .ok_or_else(|| AppError::Failed("This Studio installation cannot be revalidated.".into()))?;

        let downloads_root = downloads_dir(&paths);
        let manifest =
            revalidate_version(installation.install_dir.clone(), downloads_root, &version_guid)
                .await?;
        let install_dir = version_install_dir(&paths, &manifest.version_guid);
        let executable_path = version_executable_path(&install_dir);

        let mut refreshed = installation;
        refreshed.version = Some(manifest.version);
        refreshed.version_guid = Some(manifest.version_guid);
        refreshed.channel = Some(manifest.channel);
        refreshed.installed_at = Some(manifest.installed_at);
        refreshed.published_at = manifest.published_at;
        refreshed.integrity_verified_at = manifest.integrity_verified_at;
        refreshed.install_dir = install_dir;
        refreshed.executable = executable_path;

        let mut entry = StudioVersionEntry::from_installation(&refreshed);

        if let Ok(latest_remote) = api::fetch_current_version(CURRENT_CHANNEL).await {
            entry.is_latest =
                api::same_version_guid(&latest_remote.client_version_upload, &entry.version_guid);
        } else {
            warn!(
                installation_id,
                "failed to refresh latest-version metadata after revalidation"
            );
        }

        Ok(entry)
    }
}

#[tauri::command]
pub async fn open_studio_install_dir(
    app: AppHandle,
    installation_id: String,
) -> CommandResult<()> {
    let installation = resolve_installation(&app, &installation_id)?;

    Ok(crate::platform::reveal_path(&installation.install_dir)?)
}

#[tauri::command]
pub async fn uninstall_studio(
    app: AppHandle,
    state: State<'_, StudioState>,
    installation_id: String,
) -> CommandResult<()> {
    let _guard = state.install_lock.try_lock().map_err(|_| {
        AppError::Failed("Cannot uninstall Studio while another installation is running.".into())
    })?;

    let paths = Paths::resolve(&app)?;
    let installation = resolve_installation(&app, &installation_id)?;
    require(&installation, Capabilities::UNINSTALL)?;

    tokio_fs::remove_dir_all(&installation.install_dir)
        .await
        .with_context(|| format!("failed to remove {}", installation.install_dir.display()))?;

    if let Some(version_guid) = installation.version_guid.as_deref() {
        let download_dir = version_download_dir(&paths, version_guid);
        if download_dir.exists() {
            let _ = tokio_fs::remove_dir_all(&download_dir).await;
        }
    }

    let mut preferences = load_studio_preferences(&paths)?;
    if preferences.default_installation_id.as_deref() == Some(installation.id.as_str()) {
        preferences.default_installation_id = None;
        save_studio_preferences(&paths, &preferences).await?;
    }

    Ok(())
}

async fn list_studio_versions_inner(app: &AppHandle) -> Result<StudioVersionsResponse> {
    let paths = Paths::resolve(app)?;
    let mut versions: Vec<StudioVersionEntry> = installation::discover(&paths)
        .iter()
        .map(StudioVersionEntry::from_installation)
        .collect();
    let preferences = load_studio_preferences(&paths).unwrap_or_default();
    let latest_remote = api::fetch_current_version(CURRENT_CHANNEL).await.ok();

    if let Some(latest_remote) = latest_remote.as_ref() {
        merge_remote_version(
            &mut versions,
            latest_remote.client_version_upload.clone(),
            latest_remote.version.clone(),
            CURRENT_CHANNEL,
            None,
            true,
        );
    }

    if let Ok(history) = api::fetch_build_history().await {
        for build in history {
            let is_latest = latest_remote
                .as_ref()
                .map(|latest| api::same_version_guid(&latest.client_version_upload, &build.version_guid))
                .unwrap_or(false);

            merge_history_build(&mut versions, build, is_latest);
        }
    }

    if let Some(default_id) = preferences.default_installation_id.as_deref() {
        if let Some(default_version) = versions
            .iter_mut()
            .find(|version| version.is_installed && version.id == default_id)
        {
            default_version.is_default = true;
        }
    }

    versions.sort_by(|left, right| {
        right
            .is_default
            .cmp(&left.is_default)
            .then_with(|| right.is_latest.cmp(&left.is_latest))
            .then_with(|| right.is_installed.cmp(&left.is_installed))
            .then_with(|| right.published_at.cmp(&left.published_at))
            .then_with(|| right.installed_at.cmp(&left.installed_at))
            .then_with(|| right.version.cmp(&left.version))
    });

    Ok(StudioVersionsResponse { versions })
}

async fn install_studio_version_inner(
    app: &AppHandle,
    version_guid: &str,
    version: &str,
    channel: &str,
    published_at: Option<&str>,
) -> Result<StudioVersionEntry> {
    let paths = Paths::resolve(app)?;
    let install_dir = version_install_dir(&paths, version_guid);
    let download_dir = version_download_dir(&paths, version_guid);
    let manifest = active_deployment()
        .install(
            &EventSink { app },
            install_dir,
            download_dir,
            version_guid,
            version,
            channel,
            published_at,
        )
        .await?;
    let install_dir = version_install_dir(&paths, &manifest.version_guid);
    let executable_path = version_executable_path(&install_dir);

    apply_saved_preferences_to_install_dir(&paths, &install_dir).await?;

    let mut installation = StudioInstallation::new(
        installation::InstallationSource::Managed,
        &manifest.version_guid,
        install_dir,
        executable_path,
    );
    installation.version = Some(manifest.version);
    installation.version_guid = Some(manifest.version_guid);
    installation.channel = Some(manifest.channel);
    installation.installed_at = Some(manifest.installed_at);
    installation.published_at = manifest.published_at;
    installation.integrity_verified_at = manifest.integrity_verified_at;
    installation.capabilities = Capabilities::MANAGED;

    Ok(StudioVersionEntry::from_installation(&installation))
}

fn merge_history_build(versions: &mut Vec<StudioVersionEntry>, build: StudioBuild, is_latest: bool) {
    merge_remote_version(
        versions,
        build.version_guid,
        build.version,
        CURRENT_CHANNEL,
        Some(build.published_at),
        is_latest,
    );
}

fn merge_remote_version(
    versions: &mut Vec<StudioVersionEntry>,
    version_guid: String,
    version: String,
    channel: &str,
    published_at: Option<String>,
    is_latest: bool,
) {
    if let Some(existing) = versions
        .iter_mut()
        .find(|entry| api::same_version_guid(&entry.version_guid, &version_guid))
    {
        existing.version = version;
        existing.channel = channel.to_string();
        existing.is_latest |= is_latest;

        if existing.published_at.is_none() {
            existing.published_at = published_at;
        }

        return;
    }

    let mut entry = StudioVersionEntry::available(version_guid, version, channel, published_at);
    entry.is_latest = is_latest;
    versions.push(entry);
}