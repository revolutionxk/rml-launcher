use std::path::Path;

use tauri::AppHandle;
use tracing::info;

use crate::studio::installation::{self, Capabilities, StudioInstallation};
use crate::{AppError, Paths};

use super::{
    activate_loader,
    installer::install_release,
    model::{ModLoaderPayload, ModLoaderSubscriptions},
    paths::release_cache_dir,
    storage::{load_manifest, load_subscriptions},
    EventSink,
};

pub(super) async fn reapply_missing(app: &AppHandle) -> Result<(), AppError> {
    let paths = Paths::resolve(app)?;
    let subscriptions = load_subscriptions(&paths)?;

    if subscriptions.is_empty() {
        return Ok(());
    }

    let installations = installation::discover(&paths);

    for (installation, payload) in pending(&installations, &subscriptions, has_manifest) {
        reapply(app, &paths, installation, payload).await?;
    }

    Ok(())
}

pub(super) async fn reapply_to(app: &AppHandle, installation: &StudioInstallation) -> Result<(), AppError> {
    let paths = Paths::resolve(app)?;
    let subscriptions = load_subscriptions(&paths)?;

    for (installation, payload) in pending(std::slice::from_ref(installation), &subscriptions, has_manifest) {
        reapply(app, &paths, installation, payload).await?;
    }

    Ok(())
}

fn pending<'a>(
    installations: &'a [StudioInstallation],
    subscriptions: &'a ModLoaderSubscriptions,
    has_manifest: impl Fn(&Path) -> bool,
) -> Vec<(&'a StudioInstallation, &'a ModLoaderPayload)> {
    installations
        .iter()
        .filter(|installation| installation.capabilities.contains(Capabilities::MODS))
        .filter(|installation| !has_manifest(&installation.payload_dir()))
        .filter_map(|installation| {
            subscriptions
                .get(installation.source.slug())
                .map(|payload| (installation, payload))
        })
        .collect()
}

fn has_manifest(install_dir: &Path) -> bool {
    load_manifest(install_dir).ok().flatten().is_some()
}

async fn reapply(
    app: &AppHandle,
    paths: &Paths,
    installation: &StudioInstallation,
    payload: &ModLoaderPayload,
) -> Result<(), AppError> {
    info!(
        installation_id = %installation.id,
        tag = %payload.tag,
        "reapplying the mod loader to a Studio installation that no longer has it"
    );

    let cache_dir = release_cache_dir(paths, &payload.tag);
    let sink = EventSink { app };

    install_release(
        &sink,
        cache_dir,
        payload,
        installation.id.as_str(),
        &installation.payload_dir(),
    )
    .await?;
    activate_loader(installation).await?;

    Ok(())
}

#[cfg(test)]
mod tests {
    use super::*;
    use std::collections::HashSet;
    use std::path::PathBuf;

    use crate::modloader::model::{ModLoaderAsset, ModLoaderChannel};
    use crate::studio::installation::InstallationSource;

    fn payload(tag: &str) -> ModLoaderPayload {
        ModLoaderPayload {
            tag: tag.to_string(),
            name: tag.to_string(),
            channel: ModLoaderChannel::Stable,
            asset: ModLoaderAsset {
                name: "package-windows.zip".into(),
                size: 1024,
                download_url: "https://example.invalid/package-windows.zip".into(),
                sha256: None,
                updated_at: "2026-07-01T00:00:00Z".into(),
            },
        }
    }

    fn installation(source: InstallationSource, guid: &str) -> StudioInstallation {
        let dir = PathBuf::from("/versions").join(guid);
        StudioInstallation::new(source, guid, dir.clone(), dir.join("RobloxStudioBeta.exe"))
    }

    fn subscriptions(entries: &[(InstallationSource, &str)]) -> ModLoaderSubscriptions {
        entries
            .iter()
            .map(|(source, tag)| (source.slug().to_string(), payload(tag)))
            .collect()
    }

    fn nothing_installed(_: &Path) -> bool {
        false
    }

    #[test]
    fn a_fresh_version_of_a_subscribed_source_is_reapplied_with_the_recorded_tag() {
        let installations = vec![installation(InstallationSource::RobloxOfficial, "version-new")];
        let subscriptions = subscriptions(&[(InstallationSource::RobloxOfficial, "v1.4.0")]);

        let pending = pending(&installations, &subscriptions, nothing_installed);

        assert_eq!(pending.len(), 1);
        assert_eq!(pending[0].0.id.as_str(), "roblox-official:version-new");
        assert_eq!(pending[0].1.tag, "v1.4.0");
    }

    #[test]
    fn an_installation_that_still_has_the_mod_loader_is_left_alone() {
        let installations = vec![installation(InstallationSource::RobloxOfficial, "version-old")];
        let subscriptions = subscriptions(&[(InstallationSource::RobloxOfficial, "v1.4.0")]);

        assert!(pending(&installations, &subscriptions, |_| true).is_empty());
    }

    #[test]
    fn only_the_subscribed_sources_are_reapplied() {
        let installations = vec![
            installation(InstallationSource::RobloxOfficial, "version-a"),
            installation(InstallationSource::Bloxstrap, "version-b"),
        ];
        let subscriptions = subscriptions(&[(InstallationSource::Bloxstrap, "v1.4.0")]);

        let pending = pending(&installations, &subscriptions, nothing_installed);

        assert_eq!(pending.len(), 1);
        assert_eq!(pending[0].0.source, InstallationSource::Bloxstrap);
    }

    #[test]
    fn an_installation_that_cannot_take_mods_is_skipped() {
        let mut bundle = installation(InstallationSource::MacBundle, "studio");
        bundle.capabilities = Capabilities::LAUNCH;
        let subscriptions = subscriptions(&[(InstallationSource::MacBundle, "v1.4.0")]);

        assert!(pending(&[bundle], &subscriptions, nothing_installed).is_empty());
    }

    #[test]
    fn every_stale_version_of_a_subscribed_source_is_covered() {
        let installations = vec![
            installation(InstallationSource::RobloxOfficial, "version-a"),
            installation(InstallationSource::RobloxOfficial, "version-b"),
        ];
        let subscriptions = subscriptions(&[(InstallationSource::RobloxOfficial, "v1.4.0")]);

        let covered: HashSet<_> = pending(&installations, &subscriptions, nothing_installed)
            .iter()
            .map(|(installation, _)| installation.id.as_str().to_owned())
            .collect();

        assert_eq!(covered.len(), 2);
    }

    #[test]
    fn no_subscription_means_nothing_to_do() {
        let installations = vec![installation(InstallationSource::RobloxOfficial, "version-a")];

        assert!(pending(&installations, &ModLoaderSubscriptions::new(), nothing_installed).is_empty());
    }
}
