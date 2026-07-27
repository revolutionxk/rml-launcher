use std::os::raw::c_void;

use anyhow::{bail, Result};
use core_foundation::base::TCFType;
use core_foundation::string::{CFString, CFStringRef};
use tracing::warn;

use super::{ProtocolHandler, ProtocolStatus, STUDIO_SCHEMES};

const FALLBACK_BUNDLE_ID: &str = "com.revolution.rml-launcher";
const ROBLOX_STUDIO_BUNDLE_ID: &str = "com.Roblox.RobloxStudio";

type CFBundleRef = *mut c_void;
type OSStatus = i32;

#[link(name = "CoreFoundation", kind = "framework")]
extern "C" {
    fn CFBundleGetMainBundle() -> CFBundleRef;
    fn CFBundleGetIdentifier(bundle: CFBundleRef) -> CFStringRef;
}

#[link(name = "CoreServices", kind = "framework")]
extern "C" {
    fn LSSetDefaultHandlerForURLScheme(scheme: CFStringRef, bundle_id: CFStringRef) -> OSStatus;
    fn LSCopyDefaultHandlerForURLScheme(scheme: CFStringRef) -> CFStringRef;
}

pub struct MacosProtocolHandler;

impl ProtocolHandler for MacosProtocolHandler {
    fn status(&self) -> ProtocolStatus {
        let ours = our_bundle_id();
        let enabled = STUDIO_SCHEMES.iter().all(|scheme| {
            current_handler(scheme).is_some_and(|handler| handler.eq_ignore_ascii_case(&ours))
        });

        ProtocolStatus {
            supported: true,
            enabled,
        }
    }

    fn register(&self) -> Result<()> {
        let ours = our_bundle_id();
        for scheme in STUDIO_SCHEMES {
            set_default_handler(scheme, &ours)?;
        }
        Ok(())
    }

    fn restore(&self) -> Result<()> {
        for scheme in STUDIO_SCHEMES {
            if let Err(error) = set_default_handler(scheme, ROBLOX_STUDIO_BUNDLE_ID) {
                warn!(scheme, error = %error, "failed to hand the Studio scheme back to Roblox");
            }
        }
        Ok(())
    }
}

fn our_bundle_id() -> String {
    unsafe {
        let bundle = CFBundleGetMainBundle();
        if bundle.is_null() {
            return FALLBACK_BUNDLE_ID.to_string();
        }
        let identifier = CFBundleGetIdentifier(bundle);
        if identifier.is_null() {
            return FALLBACK_BUNDLE_ID.to_string();
        }
        CFString::wrap_under_get_rule(identifier).to_string()
    }
}

fn set_default_handler(scheme: &str, bundle_id: &str) -> Result<()> {
    let scheme_ref = CFString::new(scheme);
    let bundle_ref = CFString::new(bundle_id);
    let status = unsafe {
        LSSetDefaultHandlerForURLScheme(
            scheme_ref.as_concrete_TypeRef(),
            bundle_ref.as_concrete_TypeRef(),
        )
    };

    if status != 0 {
        bail!("Launch Services rejected {bundle_id} as the handler for {scheme}: OSStatus {status}");
    }

    Ok(())
}

fn current_handler(scheme: &str) -> Option<String> {
    let scheme_ref = CFString::new(scheme);
    unsafe {
        let handler = LSCopyDefaultHandlerForURLScheme(scheme_ref.as_concrete_TypeRef());
        if handler.is_null() {
            return None;
        }
        Some(CFString::wrap_under_create_rule(handler).to_string())
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn bundle_id_is_never_empty() {
        assert!(!our_bundle_id().is_empty());
    }

    #[test]
    fn a_scheme_no_app_claims_has_no_handler() {
        assert_eq!(current_handler("rml-launcher-nonexistent-scheme-xyzzy"), None);
    }
}
