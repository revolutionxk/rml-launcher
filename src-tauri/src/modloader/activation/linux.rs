use anyhow::Result;
use tracing::warn;

use super::{ActivationContext, LoaderActivation};

pub struct LinuxActivation;

impl LinuxActivation {
    fn set_override(context: &ActivationContext<'_>, enabled: bool) -> Result<()> {
        if context.installation_id != crate::vinegar::INSTANCE_ID {
            return Ok(());
        }

        if let Err(error) = crate::vinegar::set_dwmapi_override(enabled) {
            warn!(error = %error, "failed to update the Vinegar dwmapi override");
        }

        Ok(())
    }
}

impl LoaderActivation for LinuxActivation {
    fn activate(&self, context: &ActivationContext<'_>) -> Result<()> {
        Self::set_override(context, true)
    }

    fn deactivate(&self, context: &ActivationContext<'_>) -> Result<()> {
        Self::set_override(context, false)
    }
}
