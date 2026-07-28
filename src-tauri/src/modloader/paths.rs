use std::path::{Path, PathBuf};

use crate::Paths;

pub fn modloader_root_dir(paths: &Paths) -> PathBuf {
    paths.data_dir().join("modloader")
}

pub fn cache_dir(paths: &Paths) -> PathBuf {
    modloader_root_dir(paths).join("cache")
}

pub fn release_cache_dir(paths: &Paths, tag: &str) -> PathBuf {
    cache_dir(paths).join(sanitize_tag(tag))
}

pub fn subscriptions_path(paths: &Paths) -> PathBuf {
    modloader_root_dir(paths).join("subscriptions.json")
}

pub fn version_manifest_path(payload_dir: &Path) -> PathBuf {
    payload_dir.join("rml-modloader.json")
}

fn sanitize_tag(tag: &str) -> String {
    tag.chars()
        .map(|character| {
            if character.is_ascii_alphanumeric() || matches!(character, '-' | '_' | '.') {
                character
            } else {
                '_'
            }
        })
        .collect()
}
