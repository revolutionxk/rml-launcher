pub(crate) const REGISTRATION_PATTERN: &str =
    "41 B8 ?? 00 00 00 48 8D 15 ?? ?? ?? ?? 48 8D 0D ?? ?? ?? ?? E9 ?? ?? ?? ?? CC CC CC CC CC CC CC";
    
pub(crate) const KNOWN_FLAG_TYPES: &[&str] = &["FFlag", "SFFlag", "FInt", "FLog"];
pub(crate) const MIN_REGISTRATION_ROUTINES: usize = KNOWN_FLAG_TYPES.len();
