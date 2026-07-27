use anyhow::Result;

use super::{registry, ProtocolHandler, ProtocolStatus};

pub struct WindowsProtocolHandler;

impl ProtocolHandler for WindowsProtocolHandler {
    fn status(&self) -> ProtocolStatus {
        ProtocolStatus {
            supported: true,
            enabled: registry::is_registered().unwrap_or(false),
        }
    }

    fn register(&self) -> Result<()> {
        registry::register()
    }

    fn restore(&self) -> Result<()> {
        registry::restore()
    }
}
