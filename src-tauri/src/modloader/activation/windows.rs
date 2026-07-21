use anyhow::Result;

use super::{ActivationContext, LoaderActivation};

pub struct WindowsActivation;

impl LoaderActivation for WindowsActivation {
    fn activate(&self, _context: &ActivationContext<'_>) -> Result<()> {
        Ok(())
    }

    fn deactivate(&self, _context: &ActivationContext<'_>) -> Result<()> {
        Ok(())
    }
}
