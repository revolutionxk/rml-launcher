use std::{
    fs,
    io::{self, Read},
    path::Path,
};

use anyhow::{bail, Context, Result};
use chrono::Utc;
use sha2::{Digest, Sha256};

use crate::mods::MODLOADER_DIR;

use super::{
    installer::top_level_name,
    model::{ModLoaderAsset, ModLoaderChannel, ModLoaderPayload, ModLoaderSubscriptions},
};

const LOCAL_TAG_PREFIX: &str = "local-";

pub fn stage_bundle(source: &Path, cache_root: &Path) -> Result<ModLoaderPayload> {
    let is_zip = source
        .extension()
        .is_some_and(|extension| extension.eq_ignore_ascii_case("zip"));

    if !source.is_file() || !is_zip {
        bail!("{} is not a .zip mod loader bundle", source.display());
    }

    ensure_loader_bundle(source)?;

    let asset_name = source
        .file_name()
        .context("the mod loader bundle has no file name")?
        .to_string_lossy()
        .into_owned();
    let display_name = source
        .file_stem()
        .map(|stem| stem.to_string_lossy().into_owned())
        .unwrap_or_else(|| asset_name.clone());

    let sha256 = digest(source)?;
    let tag = format!("{LOCAL_TAG_PREFIX}{}", &sha256[..12]);
    let cache_dir = cache_root.join(&tag);
    let bundle_path = cache_dir.join(&asset_name);

    fs::create_dir_all(&cache_dir).with_context(|| format!("failed to create {}", cache_dir.display()))?;
    let size = fs::copy(source, &bundle_path)
        .with_context(|| format!("failed to copy {} to {}", source.display(), bundle_path.display()))?;

    Ok(ModLoaderPayload {
        tag,
        name: display_name,
        channel: ModLoaderChannel::Local,
        asset: ModLoaderAsset {
            name: asset_name,
            size,
            download_url: String::new(),
            sha256: Some(sha256),
            updated_at: Utc::now().to_rfc3339(),
        },
    })
}

pub fn prune_unreferenced(cache_root: &Path, subscriptions: &ModLoaderSubscriptions) {
    let Ok(entries) = fs::read_dir(cache_root) else {
        return;
    };

    for entry in entries.flatten() {
        let tag = entry.file_name().to_string_lossy().into_owned();
        let is_referenced = subscriptions.values().any(|payload| payload.tag == tag);

        if tag.starts_with(LOCAL_TAG_PREFIX) && !is_referenced {
            let _ = fs::remove_dir_all(entry.path());
        }
    }
}

fn ensure_loader_bundle(source: &Path) -> Result<()> {
    let file = fs::File::open(source).with_context(|| format!("failed to open {}", source.display()))?;
    let mut archive =
        zip::ZipArchive::new(file).with_context(|| format!("failed to read {}", source.display()))?;

    for index in 0..archive.len() {
        let entry = archive
            .by_index(index)
            .with_context(|| format!("failed to read archive entry {index} from {}", source.display()))?;

        let holds_loader = entry
            .enclosed_name()
            .and_then(|name| top_level_name(&name))
            .is_some_and(|root| root == MODLOADER_DIR);

        if holds_loader {
            return Ok(());
        }
    }

    bail!(
        "{} has no {MODLOADER_DIR} folder at its root, so it is not a mod loader bundle",
        source.display()
    )
}

fn digest(path: &Path) -> Result<String> {
    let mut reader =
        io::BufReader::new(fs::File::open(path).with_context(|| format!("failed to open {}", path.display()))?);
    let mut buffer = [0_u8; 64 * 1024];
    let mut hasher = Sha256::new();

    loop {
        let read = reader
            .read(&mut buffer)
            .with_context(|| format!("failed to read {}", path.display()))?;
        if read == 0 {
            break;
        }
        hasher.update(&buffer[..read]);
    }

    Ok(format!("{:x}", hasher.finalize()))
}

#[cfg(test)]
mod tests {
    use super::*;
    use std::io::Write;
    use std::path::PathBuf;

    use zip::write::SimpleFileOptions;

    use crate::modloader::installer::{install_release, InstallProgressSink};
    use crate::modloader::model::ModLoaderInstallProgress;

    struct SilentSink;

    impl InstallProgressSink for SilentSink {
        fn report(&self, _progress: ModLoaderInstallProgress) {}
    }

    fn scratch(name: &str) -> PathBuf {
        let dir = std::env::temp_dir().join(format!("rml-local-bundle-{name}-{}", std::process::id()));
        let _ = fs::remove_dir_all(&dir);
        fs::create_dir_all(&dir).unwrap();
        dir
    }

    fn write_zip(path: &Path, entries: &[(&str, &[u8])]) {
        let mut writer = zip::ZipWriter::new(fs::File::create(path).unwrap());

        for (name, contents) in entries {
            writer.start_file(*name, SimpleFileOptions::default()).unwrap();
            writer.write_all(contents).unwrap();
        }

        writer.finish().unwrap();
    }

    fn subscribed(payloads: &[&ModLoaderPayload]) -> ModLoaderSubscriptions {
        payloads
            .iter()
            .enumerate()
            .map(|(index, payload)| (format!("source-{index}"), (*payload).clone()))
            .collect()
    }

    #[test]
    fn a_bundle_is_cached_under_a_tag_derived_from_its_own_digest() {
        let root = scratch("staged");
        let source = root.join("my-fork.zip");
        write_zip(&source, &[("dwmapi.dll", b"proxy"), ("RobloxModLoader/roblox_modloader.dll", b"loader")]);
        let cache = root.join("cache");

        let payload = stage_bundle(&source, &cache).unwrap();

        let sha256 = payload.asset.sha256.clone().unwrap();
        let cached = cache.join(&payload.tag).join("my-fork.zip");
        assert_eq!(payload.tag, format!("local-{}", &sha256[..12]));
        assert_eq!(payload.name, "my-fork");
        assert_eq!(payload.channel, ModLoaderChannel::Local);
        assert_eq!(payload.asset.size, fs::metadata(&cached).unwrap().len());
        assert_eq!(fs::read(&cached).unwrap(), fs::read(&source).unwrap());
        assert!(payload.asset.download_url.is_empty());

        fs::remove_dir_all(&root).ok();
    }

    #[test]
    fn staging_another_bundle_keeps_the_one_a_subscription_still_points_at() {
        let root = scratch("kept");
        let first = root.join("first.zip");
        let second = root.join("second.zip");
        write_zip(&first, &[("RobloxModLoader/a.dll", b"a")]);
        write_zip(&second, &[("RobloxModLoader/b.dll", b"b")]);
        let cache = root.join("cache");

        let first = stage_bundle(&first, &cache).unwrap();
        let second = stage_bundle(&second, &cache).unwrap();
        prune_unreferenced(&cache, &subscribed(&[&first, &second]));

        assert_ne!(first.tag, second.tag);
        assert!(cache.join(&first.tag).join("first.zip").is_file());
        assert!(cache.join(&second.tag).join("second.zip").is_file());

        fs::remove_dir_all(&root).ok();
    }

    #[test]
    fn pruning_drops_only_local_bundles_no_subscription_points_at() {
        let root = scratch("pruned");
        let first = root.join("first.zip");
        let second = root.join("second.zip");
        write_zip(&first, &[("RobloxModLoader/a.dll", b"a")]);
        write_zip(&second, &[("RobloxModLoader/b.dll", b"b")]);
        let cache = root.join("cache");
        fs::create_dir_all(cache.join("nightly")).unwrap();

        let first = stage_bundle(&first, &cache).unwrap();
        let second = stage_bundle(&second, &cache).unwrap();
        prune_unreferenced(&cache, &subscribed(&[&second]));

        assert!(!cache.join(&first.tag).exists());
        assert!(cache.join(&second.tag).is_dir());
        assert!(cache.join("nightly").is_dir());

        fs::remove_dir_all(&root).ok();
    }

    #[test]
    fn an_archive_without_the_loader_folder_is_refused_and_the_cache_is_left_alone() {
        let root = scratch("not-a-loader");
        let valid = root.join("my-fork.zip");
        let source = root.join("some-mod.zip");
        write_zip(&valid, &[("RobloxModLoader/roblox_modloader.dll", b"loader")]);
        write_zip(&source, &[("mod.toml", b"name = 'x'")]);
        let cache = root.join("cache");
        let staged = stage_bundle(&valid, &cache).unwrap();

        let error = stage_bundle(&source, &cache).unwrap_err();

        assert!(error.to_string().contains("RobloxModLoader"));
        assert_eq!(fs::read_dir(&cache).unwrap().count(), 1);
        assert!(cache.join(&staged.tag).join("my-fork.zip").is_file());

        fs::remove_dir_all(&root).ok();
    }

    #[test]
    fn a_file_that_is_not_a_zip_is_refused() {
        let root = scratch("not-a-zip");
        let source = root.join("loader.dll");
        fs::write(&source, b"binary").unwrap();

        assert!(stage_bundle(&source, &root.join("cache")).is_err());

        fs::remove_dir_all(&root).ok();
    }

    #[test]
    fn the_top_level_name_skips_a_leading_current_directory() {
        assert_eq!(top_level_name(Path::new("./dwmapi.dll")).as_deref(), Some("dwmapi.dll"));
        assert_eq!(
            top_level_name(Path::new("RobloxModLoader/runtime/nethost.dll")).as_deref(),
            Some("RobloxModLoader")
        );
        assert_eq!(top_level_name(Path::new(".")), None);
    }

    #[tokio::test]
    async fn a_staged_bundle_installs_from_the_cache_without_a_download() {
        let root = scratch("installed");
        let source = root.join("my-fork.zip");
        write_zip(&source, &[("dwmapi.dll", b"proxy"), ("RobloxModLoader/roblox_modloader.dll", b"loader")]);
        let cache = root.join("cache");
        let studio = root.join("studio");
        fs::create_dir_all(&studio).unwrap();
        let payload = stage_bundle(&source, &cache).unwrap();

        let manifest = install_release(&SilentSink, cache.join(&payload.tag), &payload, "managed:1.2.3", &studio)
            .await
            .unwrap();

        assert_eq!(manifest.tag, payload.tag);
        assert_eq!(manifest.artifacts, vec!["RobloxModLoader".to_string(), "dwmapi.dll".to_string()]);
        assert_eq!(fs::read(studio.join("RobloxModLoader/roblox_modloader.dll")).unwrap(), b"loader");
        assert!(studio.join("rml-modloader.json").is_file());

        fs::remove_dir_all(&root).ok();
    }

    #[tokio::test]
    async fn a_bundle_missing_from_the_cache_asks_for_the_file_again() {
        let root = scratch("evicted");
        let source = root.join("my-fork.zip");
        write_zip(&source, &[("RobloxModLoader/roblox_modloader.dll", b"loader")]);
        let cache = root.join("cache");
        let studio = root.join("studio");
        fs::create_dir_all(&studio).unwrap();
        let payload = stage_bundle(&source, &cache).unwrap();
        let cache_dir = cache.join(&payload.tag);
        fs::remove_file(cache_dir.join("my-fork.zip")).unwrap();

        let error = install_release(&SilentSink, cache_dir, &payload, "managed:1.2.3", &studio)
            .await
            .unwrap_err();

        assert!(error.to_string().contains("install the mod loader from the file again"));
        assert!(!studio.join("RobloxModLoader").exists());

        fs::remove_dir_all(&root).ok();
    }
}
