#![cfg_attr(not(target_os = "linux"), allow(dead_code))]

use anyhow::Result;

use crate::vinegar;
use crate::Paths;

use super::{
    Capabilities, InstallationId, InstallationProvider, InstallationSource, StudioInstallation,
};

const STUDIO_EXECUTABLE: &str = "RobloxStudioBeta.exe";
const STUDIO_KEY: &str = "studio";

pub(crate) fn installation_id() -> InstallationId {
    InstallationId::new(InstallationSource::Vinegar.slug(), STUDIO_KEY)
}

pub(crate) struct VinegarProvider;

impl InstallationProvider for VinegarProvider {
    fn source(&self) -> InstallationSource {
        InstallationSource::Vinegar
    }

    fn discover(&self, _paths: &Paths) -> Result<Vec<StudioInstallation>> {
        if !vinegar::detect().installed {
            return Ok(Vec::new());
        }

        let Ok(install_dir) = vinegar::studio_dir() else {
            return Ok(Vec::new());
        };

        let executable = install_dir.join(STUDIO_EXECUTABLE);
        let mut installation = StudioInstallation::new(
            InstallationSource::Vinegar,
            STUDIO_KEY,
            install_dir,
            executable,
        );
        installation.capabilities = Capabilities::DETECTED;

        Ok(vec![installation])
    }
}
