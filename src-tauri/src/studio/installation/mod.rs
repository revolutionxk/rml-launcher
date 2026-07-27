mod macos;
mod managed;
mod model;
mod vinegar;
mod windows;

use std::collections::HashSet;

use anyhow::Result;
use tracing::warn;

use crate::Paths;

pub(crate) use model::{Capabilities, InstallationId, InstallationSource, StudioInstallation};
#[cfg(target_os = "linux")]
pub(crate) use vinegar::installation_id as vinegar_installation_id;

pub(crate) trait InstallationProvider: Send + Sync {
    fn source(&self) -> InstallationSource;
    fn discover(&self, paths: &Paths) -> Result<Vec<StudioInstallation>>;
}

pub(crate) fn collect(
    providers: &[Box<dyn InstallationProvider>],
    paths: &Paths,
) -> Vec<StudioInstallation> {
    let mut seen = HashSet::new();
    let mut installations = Vec::new();

    for provider in providers {
        let discovered = match provider.discover(paths) {
            Ok(discovered) => discovered,
            Err(error) => {
                warn!(
                    source = provider.source().slug(),
                    %error,
                    "Studio installation provider failed"
                );
                continue;
            }
        };

        for installation in discovered {
            let key = installation
                .install_dir
                .canonicalize()
                .unwrap_or_else(|_| installation.install_dir.clone());

            if seen.insert(key) {
                installations.push(installation);
            }
        }
    }

    installations
}

pub(crate) fn providers() -> Vec<Box<dyn InstallationProvider>> {
    let mut providers: Vec<Box<dyn InstallationProvider>> =
        vec![Box::new(managed::ManagedProvider)];

    #[cfg(target_os = "windows")]
    providers.push(Box::new(windows::WindowsProvider));

    #[cfg(target_os = "macos")]
    providers.push(Box::new(macos::MacBundleProvider));

    #[cfg(target_os = "linux")]
    providers.push(Box::new(vinegar::VinegarProvider));

    providers
}

pub(crate) fn discover(paths: &Paths) -> Vec<StudioInstallation> {
    collect(&providers(), paths)
}

pub(crate) fn resolve(paths: &Paths, id: &str) -> Option<StudioInstallation> {
    select(discover(paths), id)
}

fn select(installations: Vec<StudioInstallation>, id: &str) -> Option<StudioInstallation> {
    let matched = installations
        .iter()
        .position(|installation| installation.id.as_str() == id)
        .or_else(|| {
            installations
                .iter()
                .position(|installation| installation.version_guid.as_deref() == Some(id))
        })?;

    installations.into_iter().nth(matched)
}

#[cfg(test)]
mod tests {
    use super::*;
    use std::path::PathBuf;

    use crate::Paths;

    struct StubProvider {
        source: InstallationSource,
        result: Result<Vec<StudioInstallation>, ()>,
    }

    impl InstallationProvider for StubProvider {
        fn source(&self) -> InstallationSource {
            self.source
        }

        fn discover(&self, _paths: &Paths) -> anyhow::Result<Vec<StudioInstallation>> {
            match &self.result {
                Ok(installations) => Ok(installations.clone()),
                Err(()) => anyhow::bail!("stub provider failure"),
            }
        }
    }

    fn installation(source: InstallationSource, dir: &str) -> StudioInstallation {
        let dir = PathBuf::from(dir);
        StudioInstallation::new(
            source,
            dir.to_string_lossy().as_ref(),
            dir.clone(),
            dir.join("Studio"),
        )
    }

    fn stub(source: InstallationSource, dirs: &[&str]) -> Box<dyn InstallationProvider> {
        Box::new(StubProvider {
            source,
            result: Ok(dirs.iter().map(|dir| installation(source, dir)).collect()),
        })
    }

    fn paths() -> Paths {
        Paths::for_test(std::env::temp_dir())
    }

    #[test]
    fn a_failing_provider_does_not_hide_the_others() {
        let providers: Vec<Box<dyn InstallationProvider>> = vec![
            Box::new(StubProvider {
                source: InstallationSource::Bloxstrap,
                result: Err(()),
            }),
            stub(InstallationSource::RobloxOfficial, &["/roblox/version-a"]),
        ];

        let found = collect(&providers, &paths());

        assert_eq!(found.len(), 1);
        assert_eq!(found[0].source, InstallationSource::RobloxOfficial);
    }

    #[test]
    fn the_same_directory_from_two_providers_is_listed_once_with_the_first_winning() {
        let providers: Vec<Box<dyn InstallationProvider>> = vec![
            stub(InstallationSource::Managed, &["/shared/version-a"]),
            stub(InstallationSource::RobloxOfficial, &["/shared/version-a"]),
        ];

        let found = collect(&providers, &paths());

        assert_eq!(found.len(), 1);
        assert_eq!(found[0].source, InstallationSource::Managed);
    }

    #[test]
    fn resolution_selects_the_installation_with_the_matching_id() {
        let installations = vec![
            installation(InstallationSource::Managed, "/managed/a"),
            installation(InstallationSource::Bloxstrap, "/bloxstrap/b"),
        ];
        let wanted = installations[1].id.as_str().to_owned();

        let found = select(installations, &wanted).unwrap();

        assert_eq!(found.source, InstallationSource::Bloxstrap);
    }

    #[test]
    fn resolution_falls_back_to_a_bare_version_guid_for_migrated_preferences() {
        let mut managed = installation(InstallationSource::Managed, "/managed/a");
        managed.version_guid = Some("version-legacy".into());

        let found = select(vec![managed], "version-legacy").unwrap();

        assert_eq!(found.source, InstallationSource::Managed);
    }

    #[test]
    fn resolution_prefers_an_exact_id_over_a_version_guid_match() {
        let mut managed = installation(InstallationSource::Managed, "/managed/a");
        managed.version_guid = Some("version-shared".into());
        let mut bloxstrap = installation(InstallationSource::Bloxstrap, "/bloxstrap/b");
        bloxstrap.version_guid = Some("version-shared".into());
        let wanted = bloxstrap.id.as_str().to_owned();

        let found = select(vec![managed, bloxstrap], &wanted).unwrap();

        assert_eq!(found.source, InstallationSource::Bloxstrap);
    }

    #[test]
    fn resolution_returns_none_when_nothing_matches() {
        assert!(select(vec![installation(InstallationSource::Managed, "/a")], "nope").is_none());
    }

    #[test]
    fn distinct_directories_are_all_retained() {
        let providers: Vec<Box<dyn InstallationProvider>> = vec![
            stub(InstallationSource::Managed, &["/managed/version-a"]),
            stub(
                InstallationSource::Bloxstrap,
                &["/bloxstrap/version-b", "/bloxstrap/version-c"],
            ),
        ];

        assert_eq!(collect(&providers, &paths()).len(), 3);
    }
}
