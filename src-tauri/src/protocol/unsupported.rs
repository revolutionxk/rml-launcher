use anyhow::{bail, Result};

use super::{ProtocolHandler, ProtocolStatus};

pub struct UnsupportedProtocolHandler;

impl ProtocolHandler for UnsupportedProtocolHandler {
    fn status(&self) -> ProtocolStatus {
        ProtocolStatus {
            supported: false,
            enabled: false,
        }
    }

    fn register(&self) -> Result<()> {
        bail!("Opening Studio links through RML is not available on this platform.")
    }

    fn restore(&self) -> Result<()> {
        bail!("Opening Studio links through RML is not available on this platform.")
    }
}
