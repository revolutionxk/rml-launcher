use std::time::Duration;

use anyhow::{anyhow, bail, Context, Result};
use reqwest::Client;
use tokio::time::sleep;
use tracing::{info, warn};

use super::model::{
    GithubAsset, GithubRelease, ModLoaderAsset, ModLoaderChannel, ModLoaderRelease,
};

const RELEASES_API_URL: &str =
    "https://api.github.com/repos/revolutionxk/roblox-modloader/releases";
const USER_AGENT: &str = "RML Launcher/0.1.0";
const CONNECT_TIMEOUT: Duration = Duration::from_secs(10);
const REQUEST_TIMEOUT: Duration = Duration::from_secs(30);
const REQUEST_RETRY_DELAYS_MS: &[u64] = &[0, 500, 1500];

pub fn http_client() -> Result<Client> {
    Client::builder()
        .user_agent(USER_AGENT)
        .connect_timeout(CONNECT_TIMEOUT)
        .timeout(REQUEST_TIMEOUT)
        .build()
        .context("failed to build the HTTP client")
}

pub async fn fetch_releases() -> Result<Vec<ModLoaderRelease>> {
    let client = http_client()?;
    let raw_releases = request_releases(&client).await?;

    let mut releases = Vec::new();

    for release in raw_releases {
        if release.draft {
            continue;
        }

        let Some(asset) = resolve_bundle_asset(&release.assets) else {
            warn!(tag = %release.tag_name, "skipping release without an installable bundle asset");
            continue;
        };

        let name = release
            .name
            .clone()
            .filter(|name| !name.trim().is_empty())
            .unwrap_or_else(|| release.tag_name.clone());
        let channel = ModLoaderChannel::classify(&release.tag_name, &name, release.prerelease);
        let notes = release
            .body
            .as_ref()
            .map(|body| body.trim().to_string())
            .filter(|body| !body.is_empty());

        releases.push(ModLoaderRelease {
            tag: release.tag_name,
            name,
            channel,
            prerelease: release.prerelease,
            published_at: release.published_at,
            html_url: release.html_url,
            notes,
            asset: into_asset(asset),
            is_installed: false,
            update_available: false,
        });
    }

    info!(release_count = releases.len(), "resolved mod loader releases");

    Ok(releases)
}

pub async fn fetch_release(tag: &str) -> Result<ModLoaderRelease> {
    fetch_releases()
        .await?
        .into_iter()
        .find(|release| release.tag.eq_ignore_ascii_case(tag))
        .ok_or_else(|| anyhow!("the mod loader release '{tag}' is no longer available"))
}

fn into_asset(asset: GithubAsset) -> ModLoaderAsset {
    ModLoaderAsset {
        name: asset.name,
        size: asset.size,
        download_url: asset.browser_download_url,
        sha256: parse_sha256(asset.digest.as_deref()),
        updated_at: asset.updated_at,
    }
}

#[cfg(target_os = "windows")]
const PLATFORM_ASSET_KEYWORDS: &[&str] = &["windows"];
#[cfg(target_os = "macos")]
const PLATFORM_ASSET_KEYWORDS: &[&str] = &["macos", "darwin", "osx"];
#[cfg(target_os = "linux")]
const PLATFORM_ASSET_KEYWORDS: &[&str] = &["linux"];

fn resolve_bundle_asset(assets: &[GithubAsset]) -> Option<GithubAsset> {
    let zips = assets
        .iter()
        .filter(|asset| asset.name.to_ascii_lowercase().ends_with(".zip"))
        .collect::<Vec<_>>();

    zips.iter()
        .find(|asset| {
            let name = asset.name.to_ascii_lowercase();
            PLATFORM_ASSET_KEYWORDS.iter().any(|keyword| name.contains(keyword))
        })
        .or_else(|| {
            zips.iter()
                .filter(|asset| !asset.name.to_ascii_lowercase().contains("managed-runtime"))
                .max_by_key(|asset| asset.size)
        })
        .or_else(|| zips.first())
        .map(|asset| (*asset).clone())
}

fn parse_sha256(digest: Option<&str>) -> Option<String> {
    digest
        .and_then(|digest| digest.strip_prefix("sha256:"))
        .map(|hex| hex.trim().to_ascii_lowercase())
        .filter(|hex| !hex.is_empty())
}

async fn request_releases(client: &Client) -> Result<Vec<GithubRelease>> {
    let mut last_error = None;

    for (attempt_index, delay_ms) in REQUEST_RETRY_DELAYS_MS.iter().enumerate() {
        if *delay_ms > 0 {
            sleep(Duration::from_millis(*delay_ms)).await;
        }

        let attempt = attempt_index + 1;
        info!(url = RELEASES_API_URL, attempt, "requesting mod loader releases");

        let response = client
            .get(RELEASES_API_URL)
            .header("Accept", "application/vnd.github+json")
            .header("X-GitHub-Api-Version", "2022-11-28")
            .send()
            .await;

        match response {
            Ok(response) => {
                let status = response.status();

                if status.is_success() {
                    return response
                        .json::<Vec<GithubRelease>>()
                        .await
                        .context("failed to decode the GitHub releases response");
                }

                warn!(attempt, status = %status, "GitHub returned a non-success response");
                last_error = Some(anyhow!(
                    "GitHub returned HTTP {} while listing mod loader releases",
                    status.as_u16(),
                ));
            }
            Err(error) => {
                warn!(attempt, error = %error, "failed to contact GitHub");
                last_error = Some(anyhow!("failed to contact GitHub: {error}"));
            }
        }
    }

    Err(last_error.unwrap_or_else(|| anyhow!("failed to list mod loader releases")))
}

pub async fn send_download_request(client: &Client, url: &str) -> Result<reqwest::Response> {
    let mut last_error = None;

    for (attempt_index, delay_ms) in REQUEST_RETRY_DELAYS_MS.iter().enumerate() {
        if *delay_ms > 0 {
            sleep(Duration::from_millis(*delay_ms)).await;
        }

        let attempt = attempt_index + 1;
        info!(url, attempt, "downloading mod loader bundle");

        match client.get(url).send().await {
            Ok(response) => {
                let status = response.status();

                if status.is_success() {
                    return Ok(response);
                }

                warn!(url, attempt, status = %status, "bundle download returned a non-success response");
                last_error = Some(anyhow!("GitHub returned HTTP {} while downloading the bundle", status.as_u16()));
            }
            Err(error) => {
                warn!(url, attempt, error = %error, "failed to download the bundle");
                last_error = Some(anyhow!("failed to download the mod loader bundle: {error}"));
            }
        }
    }

    Err(last_error.unwrap_or_else(|| anyhow!("failed to download the mod loader bundle from {url}")))
}

pub fn ensure_trusted_download(url: &str) -> Result<()> {
    if url.starts_with("https://github.com/") || url.starts_with("https://objects.githubusercontent.com/") {
        return Ok(());
    }

    bail!("refusing to download the mod loader bundle from an untrusted URL: {url}")
}

#[cfg(test)]
mod tests {
    use super::{parse_sha256, resolve_bundle_asset, PLATFORM_ASSET_KEYWORDS};
    use crate::modloader::model::GithubAsset;

    fn asset(name: &str, size: u64) -> GithubAsset {
        GithubAsset {
            name: name.to_string(),
            size,
            browser_download_url: format!("https://github.com/x/y/releases/download/t/{name}"),
            digest: None,
            updated_at: "2026-06-26T07:22:52Z".to_string(),
        }
    }

    #[test]
    fn prefers_the_host_platform_bundle() {
        let platform_zip = format!("nightly-{}.zip", PLATFORM_ASSET_KEYWORDS[0]);
        let assets = vec![
            asset("managed-runtime.zip", 700_000),
            asset(&platform_zip, 1_700_000),
            asset("nightly-someotheros.zip", 9_000_000),
            asset("roblox_modloader.bin", 4_000_000),
        ];

        let resolved = resolve_bundle_asset(&assets).expect("a bundle should resolve");
        assert_eq!(resolved.name, platform_zip);
    }

    #[test]
    fn falls_back_to_largest_non_runtime_zip() {
        let assets = vec![
            asset("managed-runtime.zip", 700_000),
            asset("full-bundle.zip", 1_900_000),
        ];

        let resolved = resolve_bundle_asset(&assets).expect("a bundle should resolve");
        assert_eq!(resolved.name, "full-bundle.zip");
    }

    #[test]
    fn normalizes_digest() {
        assert_eq!(parse_sha256(Some("sha256:AABBCC")), Some("aabbcc".to_string()));
        assert_eq!(parse_sha256(None), None);
        assert_eq!(parse_sha256(Some("")), None);
    }
}
