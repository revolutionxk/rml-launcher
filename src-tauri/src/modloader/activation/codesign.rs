use std::path::Path;
use std::process::Command;

use anyhow::{bail, Context, Result};
use plist::Value;

const DISABLE_LIBRARY_VALIDATION: &str = "com.apple.security.cs.disable-library-validation";
const DISABLE_PAGE_PROTECTION: &str = "com.apple.security.cs.disable-executable-page-protection";
const GET_TASK_ALLOW: &str = "com.apple.security.get-task-allow";

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum Mode {
    Lock,
    Unlock,
}

pub fn resign_bundle(bundle: &Path, entitlements_source: &Path, mode: Mode) -> Result<()> {
    let entitlements = read_entitlements(entitlements_source)?;
    let merged = match mode {
        Mode::Unlock => unlocked(entitlements, cfg!(debug_assertions)),
        Mode::Lock => entitlements,
    };

    let entitlements_path = std::env::temp_dir().join("rml-launcher-entitlements.plist");
    plist::to_file_xml(&entitlements_path, &merged)
        .with_context(|| format!("failed to write {}", entitlements_path.display()))?;

    let result = sign(bundle, Some(&entitlements_path));
    let _ = std::fs::remove_file(&entitlements_path);
    result
}

pub fn sign_ad_hoc(target: &Path) -> Result<()> {
    sign(target, None)
}

pub fn verify(bundle: &Path) -> Result<()> {
    let output = Command::new("codesign")
        .arg("-v")
        .arg(bundle)
        .output()
        .context("failed to run codesign to verify the bundle")?;

    if !output.status.success() {
        bail!("codesign could not verify {}", bundle.display());
    }

    Ok(())
}

fn read_entitlements(binary: &Path) -> Result<Value> {
    let output = Command::new("codesign")
        .args(["-d", "--entitlements", ":-", "--xml"])
        .arg(binary)
        .output()
        .context("failed to run codesign to read entitlements")?;

    if output.stdout.is_empty() {
        return Ok(Value::Dictionary(plist::Dictionary::new()));
    }

    Value::from_reader_xml(std::io::Cursor::new(output.stdout)).context("failed to parse the binary's entitlements")
}

fn unlocked(entitlements: Value, debuggable: bool) -> Value {
    let mut dictionary = match entitlements {
        Value::Dictionary(dictionary) => dictionary,
        _ => plist::Dictionary::new(),
    };

    dictionary.insert(DISABLE_LIBRARY_VALIDATION.to_string(), Value::Boolean(true));
    dictionary.insert(DISABLE_PAGE_PROTECTION.to_string(), Value::Boolean(true));

    if debuggable {
        dictionary.insert(GET_TASK_ALLOW.to_string(), Value::Boolean(true));
    }

    Value::Dictionary(dictionary)
}

fn sign(target: &Path, entitlements: Option<&Path>) -> Result<()> {
    let mut command = Command::new("codesign");
    command.arg("--force").args(["--sign", "-"]);

    if let Some(entitlements) = entitlements {
        command
            .args(["--options", "runtime"])
            .arg("--deep")
            .arg("--entitlements")
            .arg(entitlements);
    }

    let status = command
        .arg(target)
        .status()
        .context("failed to run codesign to sign")?;

    if !status.success() {
        bail!("codesign failed to sign {}", target.display());
    }

    Ok(())
}

#[cfg(test)]
mod tests {
    use super::*;

    fn unlock(debuggable: bool) -> plist::Dictionary {
        let mut original = plist::Dictionary::new();
        original.insert("com.apple.security.cs.allow-jit".to_string(), Value::Boolean(true));
        original.insert("com.apple.security.device.camera".to_string(), Value::Boolean(true));

        let Value::Dictionary(merged) = unlocked(Value::Dictionary(original), debuggable) else {
            panic!("expected a dictionary");
        };

        merged
    }

    #[test]
    fn adds_the_injection_keys_while_keeping_existing_entitlements() {
        let merged = unlock(false);

        assert_eq!(merged.get(DISABLE_LIBRARY_VALIDATION), Some(&Value::Boolean(true)));
        assert_eq!(merged.get(DISABLE_PAGE_PROTECTION), Some(&Value::Boolean(true)));
        assert_eq!(merged.get("com.apple.security.cs.allow-jit"), Some(&Value::Boolean(true)));
        assert_eq!(merged.get("com.apple.security.device.camera"), Some(&Value::Boolean(true)));
    }

    #[test]
    fn only_a_debuggable_signature_can_be_attached_to() {
        assert_eq!(unlock(false).get(GET_TASK_ALLOW), None);
        assert_eq!(unlock(true).get(GET_TASK_ALLOW), Some(&Value::Boolean(true)));
    }

    #[test]
    fn produces_the_keys_even_for_a_binary_without_entitlements() {
        let Value::Dictionary(merged) = unlocked(Value::Dictionary(plist::Dictionary::new()), false) else {
            panic!("expected a dictionary");
        };

        assert_eq!(merged.get(DISABLE_LIBRARY_VALIDATION), Some(&Value::Boolean(true)));
        assert_eq!(merged.get(DISABLE_PAGE_PROTECTION), Some(&Value::Boolean(true)));
        assert_eq!(merged.len(), 2);
    }
}
