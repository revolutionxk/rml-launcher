mod managed;
mod model;

use std::collections::HashSet;

use anyhow::Result;
use tracing::warn;

use crate::Paths;

pub(crate) use managed::ManagedProvider;
pub(crate) use model::{Capabilities, InstallationId, InstallationSource, StudioInstallation};

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
