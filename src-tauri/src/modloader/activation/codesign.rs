use std::path::Path;
use std::process::Command;

use anyhow::{bail, Context, Result};
use plist::Value;

const DISABLE_LIBRARY_VALIDATION: &str = "com.apple.security.cs.disable-library-validation";

pub fn resign_bundle(bundle: &Path, main_binary: &Path, disable_library_validation: bool) -> Result<()> {
    let entitlements = read_entitlements(main_binary)?;
    let merged = if disable_library_validation {
        with_library_validation_disabled(entitlements)
    } else {
        entitlements
    };

    let entitlements_path = std::env::temp_dir().join("rml-launcher-entitlements.plist");
    plist::to_file_xml(&entitlements_path, &merged)
        .with_context(|| format!("failed to write {}", entitlements_path.display()))?;

    let result = sign(bundle, &entitlements_path);
    let _ = std::fs::remove_file(&entitlements_path);
    result
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

fn with_library_validation_disabled(entitlements: Value) -> Value {
    let mut dictionary = match entitlements {
        Value::Dictionary(dictionary) => dictionary,
        _ => plist::Dictionary::new(),
    };

    dictionary.insert(DISABLE_LIBRARY_VALIDATION.to_string(), Value::Boolean(true));
    Value::Dictionary(dictionary)
}

fn sign(bundle: &Path, entitlements: &Path) -> Result<()> {
    let status = Command::new("codesign")
        .arg("--force")
        .args(["--sign", "-"])
        .args(["--options", "runtime"])
        .arg("--deep")
        .arg("--entitlements")
        .arg(entitlements)
        .arg(bundle)
        .status()
        .context("failed to run codesign to sign the bundle")?;

    if !status.success() {
        bail!("codesign failed to sign {}", bundle.display());
    }

    Ok(())
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn adds_the_key_while_keeping_existing_entitlements() {
        let mut original = plist::Dictionary::new();
        original.insert("com.apple.security.cs.allow-jit".to_string(), Value::Boolean(true));
        original.insert("com.apple.security.device.camera".to_string(), Value::Boolean(true));

        let Value::Dictionary(merged) = with_library_validation_disabled(Value::Dictionary(original)) else {
            panic!("expected a dictionary");
        };

        assert_eq!(merged.get(DISABLE_LIBRARY_VALIDATION), Some(&Value::Boolean(true)));
        assert_eq!(merged.get("com.apple.security.cs.allow-jit"), Some(&Value::Boolean(true)));
        assert_eq!(merged.get("com.apple.security.device.camera"), Some(&Value::Boolean(true)));
    }

    #[test]
    fn produces_the_key_even_for_a_binary_without_entitlements() {
        let Value::Dictionary(merged) = with_library_validation_disabled(Value::Dictionary(plist::Dictionary::new())) else {
            panic!("expected a dictionary");
        };

        assert_eq!(merged.get(DISABLE_LIBRARY_VALIDATION), Some(&Value::Boolean(true)));
        assert_eq!(merged.len(), 1);
    }
}
