#[cfg(not(target_os = "macos"))]
use std::collections::BTreeMap;
use std::collections::HashSet;
use std::time::Duration;

use anyhow::{anyhow, bail, Context, Result};
use chrono::NaiveDateTime;
use reqwest::Client;
use tokio::time::sleep;
use tracing::{info, warn};

use super::{
    config::{
        binary_target, deploy_history_path, deploy_history_product, mac_studio_blob_dir, CURRENT_CHANNEL,
        MAC_STUDIO_ZIP,
    },
    model::{CurrentVersionResponse, StudioBuild},
};
#[cfg(not(target_os = "macos"))]
use super::model::PackageManifestEntry;

const SETUP_BASE_URLS: &[&str] = &["https://setup.rbxcdn.com"];
const CLIENT_SETTINGS_BASE_URL: &str = "https://clientsettingscdn.roblox.com/v2/client-version";
#[cfg(not(target_os = "macos"))]
const VERSION_HISTORY_URL: &str =
    "https://raw.githubusercontent.com/MaximumADHD/Roblox-Client-Tracker/refs/heads/roblox/version-history.json";
const USER_AGENT: &str = "RML Launcher/0.1.0";
const CONNECT_TIMEOUT: Duration = Duration::from_secs(10);
const REQUEST_TIMEOUT: Duration = Duration::from_secs(30);
const REQUEST_RETRY_DELAYS_MS: &[u64] = &[0, 500, 1500];

pub async fn fetch_current_version(channel: &str) -> Result<CurrentVersionResponse> {
    let url = format!(
        "{}/{}/channel/{}",
        CLIENT_SETTINGS_BASE_URL,
        binary_target(),
        channel,
    );

    let response = send_get_request_with_retry(
        &http_client()?,
        &url,
        "current Studio version",
    )
        .await?
        .json::<CurrentVersionResponse>()
        .await
        .context("failed to decode the Roblox version response")?;

    info!(
        channel,
        version = %response.version,
        client_version_upload = %response.client_version_upload,
        "resolved current Roblox Studio version"
    );

    Ok(response)
}

pub async fn resolve_client_version_upload(version: &str) -> Result<String> {
    match fetch_current_version(CURRENT_CHANNEL).await {
        Ok(current) if current.version == version => return Ok(current.client_version_upload),
        Ok(_) => {}
        Err(error) => warn!(version, error = %error, "failed to resolve the current Studio version"),
    }

    #[cfg(not(target_os = "macos"))]
    if let Some(client_version_upload) = fetch_version_history().await?.get(version) {
        info!(version, client_version_upload, "resolved Studio version through the version ledger");
        return Ok(client_version_upload.clone());
    }

    bail!("Roblox does not expose a download for Studio {version}")
}

#[cfg(not(target_os = "macos"))]
pub async fn fetch_version_history() -> Result<BTreeMap<String, String>> {
    send_get_request_with_retry(&http_client()?, VERSION_HISTORY_URL, "Studio version ledger")
        .await?
        .json::<BTreeMap<String, String>>()
        .await
        .context("failed to decode the Studio version ledger")
}

#[cfg(not(target_os = "macos"))]
pub async fn fetch_package_manifest(client_version_upload: &str) -> Result<Vec<PackageManifestEntry>> {
    let manifest_candidates = [
        format!("{client_version_upload}-rbxPkgManifest.txt"),
        format!("{client_version_upload}-rbxManifest.txt"),
    ];
    let mut last_error = None;

    for manifest_path in manifest_candidates {
        match fetch_setup_text(&manifest_path, "package manifest").await {
            Ok(data) => {
                info!(client_version_upload, manifest_path, "resolved Roblox Studio package manifest");
                return parse_package_manifest(&data)
                    .with_context(|| format!("failed to parse the package manifest at {manifest_path}"));
            }
            Err(error) => {
                warn!(client_version_upload, manifest_path, error = %error, "package manifest candidate failed");
                last_error = Some(error);
            }
        }
    }

    Err(last_error.unwrap_or_else(|| {
        anyhow!(
            "Roblox did not expose a package manifest for {} after all retry attempts",
            client_version_upload,
        )
    }))
}

pub async fn fetch_build_history() -> Result<Vec<StudioBuild>> {
    let data = fetch_setup_text(&deploy_history_path(), "Studio build history").await?;

    Ok(parse_deploy_history(&data, deploy_history_product()))
}

#[cfg(not(target_os = "macos"))]
pub fn package_url(client_version_upload: &str, package_name: &str) -> String {
    format!("{}/{client_version_upload}-{package_name}", SETUP_BASE_URLS[0])
}

pub fn mac_studio_url(client_version_upload: &str) -> String {
    format!(
        "{}{}{client_version_upload}-{MAC_STUDIO_ZIP}",
        SETUP_BASE_URLS[0],
        mac_studio_blob_dir(),
    )
}

pub(super) fn http_client() -> Result<Client> {
    Client::builder()
        .user_agent(USER_AGENT)
        .connect_timeout(CONNECT_TIMEOUT)
        .timeout(REQUEST_TIMEOUT)
        .build()
        .context("failed to build the HTTP client")
}

pub(super) async fn send_get_request_with_retry(
    client: &Client,
    url: &str,
    resource_name: &str,
) -> Result<reqwest::Response> {
    let mut last_error = None;

    for (attempt_index, delay_ms) in REQUEST_RETRY_DELAYS_MS.iter().enumerate() {
        if *delay_ms > 0 {
            sleep(Duration::from_millis(*delay_ms)).await;
        }

        let attempt = attempt_index + 1;
        info!(url, resource_name, attempt, total_attempts = REQUEST_RETRY_DELAYS_MS.len(), "requesting Roblox resource");

        match client.get(url).send().await {
            Ok(response) => {
                let status = response.status();

                if status.is_success() {
                    return Ok(response);
                }

                let body_snippet = response
                    .text()
                    .await
                    .map(|body| truncate_for_log(&body))
                    .unwrap_or_else(|_| "<failed to read response body>".to_string());

                warn!(url, resource_name, attempt, status = %status, body = %body_snippet, "Roblox returned a non-success response");
                last_error = Some(anyhow!(
                    "Roblox returned HTTP {} while resolving the {} at {}",
                    status.as_u16(),
                    resource_name,
                    url,
                ));
            }
            Err(error) => {
                warn!(url, resource_name, attempt, error = %error, "failed to contact Roblox");
                last_error = Some(anyhow!(
                    "failed to contact Roblox while resolving the {} at {}: {}",
                    resource_name,
                    url,
                    error,
                ));
            }
        }
    }

    Err(last_error.unwrap_or_else(|| {
        anyhow!("failed to resolve the {} at {}", resource_name, url)
    }))
}

async fn fetch_setup_text(path: &str, resource_name: &str) -> Result<String> {
    let client = http_client()?;
    let mut last_error = None;

    for base_url in SETUP_BASE_URLS {
        let url = format!("{base_url}/{path}");

        match send_get_request_with_retry(&client, &url, resource_name).await {
            Ok(response) => {
                return response
                    .text()
                    .await
                    .with_context(|| format!("failed to read the {} from {}", resource_name, url));
            }
            Err(error) => {
                warn!(url, resource_name, error = %error, "setup CDN candidate failed");
                last_error = Some(error);
            }
        }
    }

    Err(last_error.unwrap_or_else(|| {
        anyhow!("failed to resolve the {}", resource_name)
    }))
}

fn truncate_for_log(value: &str) -> String {
    const MAX_LEN: usize = 240;

    let trimmed = value.trim();
    let mut preview = trimmed.chars().take(MAX_LEN).collect::<String>();

    if trimmed.chars().count() > MAX_LEN {
        preview.push_str("...");
    }

    preview.replace('\n', "\\n")
}

#[cfg(not(target_os = "macos"))]
fn parse_package_manifest(data: &str) -> Result<Vec<PackageManifestEntry>> {
    let mut lines = data.lines();
    let manifest_version = lines.next().unwrap_or_default();

    if manifest_version.trim() != "v0" {
        bail!("unexpected package manifest version: {manifest_version}");
    }

    let mut packages = Vec::new();

    while let Some(name) = lines.next() {
        let Some(signature) = lines.next() else {
            break;
        };
        let Some(raw_packed_size) = lines.next() else {
            break;
        };
        let Some(raw_size) = lines.next() else {
            break;
        };

        let name = name.trim();

        if !name.ends_with(".zip") {
            continue;
        }

        let packed_size = raw_packed_size
            .trim()
            .parse::<u64>()
            .with_context(|| format!("invalid packed size for package {name}"))?;
        let unpacked_size = raw_size
            .trim()
            .parse::<u64>()
            .with_context(|| format!("invalid size for package {name}"))?;

        packages.push(PackageManifestEntry {
            name: name.to_string(),
            signature: signature.trim().to_ascii_lowercase(),
            packed_size,
            unpacked_size,
        });
    }

    Ok(packages)
}

fn parse_deploy_history(data: &str, product_name: &str) -> Vec<StudioBuild> {
    // I HATE parsing this garbage but Roblox doesn't provide a better way to get recent build history :(

    let prefix = format!("New {product_name} version-");
    let mut builds = Vec::new();
    let mut seen_versions = HashSet::new();

    for raw_line in data.lines().rev() {
        let line = raw_line.trim();
        if !line.starts_with(&prefix) || line.ends_with("Error!") {
            continue;
        }

        let Some((_, details)) = line.split_once(" at ") else {
            continue;
        };

        let Some((published_at, version_details)) = details.split_once(", file version: ") else {
            continue;
        };
        let Some(published_at) = parse_deploy_history_timestamp(published_at) else {
            continue;
        };

        let raw_version = version_details
            .split_once(", git hash:")
            .map(|(version, _)| version)
            .or_else(|| version_details.split_once("...").map(|(version, _)| version))
            .unwrap_or(version_details)
            .trim();
        let Some(version) = normalize_file_version(raw_version) else {
            continue;
        };

        if !seen_versions.insert(version.clone()) {
            continue;
        }

        builds.push(StudioBuild { version, published_at });
    }

    builds
}

fn parse_deploy_history_timestamp(value: &str) -> Option<String> {
    NaiveDateTime::parse_from_str(value.trim(), "%-m/%-d/%Y %-I:%M:%S %p")
        .or_else(|_| NaiveDateTime::parse_from_str(value.trim(), "%m/%d/%Y %I:%M:%S %p"))
        .ok()
    .map(|timestamp| timestamp.format("%Y-%m-%dT%H:%M:%S").to_string())
}

fn normalize_file_version(raw: &str) -> Option<String> {
    let segments = raw
        .split(',')
        .map(str::trim)
        .filter(|segment| !segment.is_empty())
        .collect::<Vec<_>>();

    (!segments.is_empty()).then(|| segments.join("."))
}

#[cfg(test)]
mod tests {
    use super::{mac_studio_url, parse_deploy_history};
    #[cfg(not(target_os = "macos"))]
    use super::parse_package_manifest;

    #[test]
    fn builds_the_mac_studio_download_url() {
        let url = mac_studio_url("version-abc123");

        #[cfg(target_arch = "aarch64")]
        assert_eq!(url, "https://setup.rbxcdn.com/mac/arm64/version-abc123-RobloxStudioApp.zip");
        #[cfg(not(target_arch = "aarch64"))]
        assert_eq!(url, "https://setup.rbxcdn.com/mac/version-abc123-RobloxStudioApp.zip");
    }


    #[cfg(not(target_os = "macos"))]
    #[test]
    fn parses_package_manifest() {
        let manifest = parse_package_manifest(
            "v0\nRobloxStudio.zip\nabc123\n10\n20\ncontent-avatar.zip\ndef456\n30\n40\n",
        )
        .expect("manifest should parse");

        assert_eq!(manifest.len(), 2);
        assert_eq!(manifest[0].name, "RobloxStudio.zip");
        assert_eq!(manifest[0].signature, "abc123");
        assert_eq!(manifest[1].packed_size, 30);
        assert_eq!(manifest[1].unpacked_size, 40);
    }

    #[test]
    fn parses_the_macos_build_history() {
        let history = parse_deploy_history(
            concat!(
                "New Studio version-hidden at 9/14/2026 4:07:58 PM, file version: 0, 739, 0, 7390687, git hash: 0.739.0.7390687 ...Done!
",
                "
",
                "New Client version-hidden at 9/14/2026 4:31:45 PM, file version: 0,739,0,7390687, git hash: 0.739.0.7390687 ...Done!
",
                "
",
                "New StudioBeta version-637cf81b9e084588 at 1/20/2017 1:56:22 AM, file version: 0, 274, 0, 101540...Done!
",
                "Revert Studio version-48a14a101efa4802 at 1/30/2013 4:09:49 PM...Done!
",
                "New Studio version-a9a2351562de41c8 at 5/24/2021 3:14:21 PM, file version: 0, 480, 0, 423050, git hash: aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa ...Done!
",
                "New Studio version-4c966efb76b842b0 at 6/29/2012 1:13:09 AM, file version: 0, 65, 0, 596...Done!
",
                "New Studio version-deadbeefdeadbeef at 6/30/2012 1:13:09 AM, file version: 0, 66, 0, 600...Error!
",
                "New Studio version-hidden at 9/8/2026 10:20:11 AM, file version: 0, 738, 0, 7381393, git hash: 0.738.0.7381393 ...Done!
"
            ),
            "Studio",
        );

        let versions = history.iter().map(|build| build.version.as_str()).collect::<Vec<_>>();
        assert_eq!(
            versions,
            ["0.738.0.7381393", "0.65.0.596", "0.480.0.423050", "0.739.0.7390687"]
        );
        assert_eq!(history[3].published_at, "2026-09-14T16:07:58");
    }

    #[test]
    fn parses_recent_build_history_by_file_version() {
        let history = parse_deploy_history(
            concat!(
                "New Studio64 version-older-guid at 4/14/2026 10:05:34 AM, file version: 0, 717, 0, 7170978, git hash: 0.717.0.7170978 ...\n",
                "New Studio64 version-hidden at 4/15/2026 10:08:30 AM, file version: 0, 717, 0, 7170982, git hash: 0.717.0.7170982 ...\n",
                "New Studio version-wrong-product at 4/15/2026 10:08:30 AM, file version: 0, 717, 0, 7170982, git hash: 0.717.0.7170982 ...\n",
                "New Studio64 version-recent-guid at 4/21/2026 1:46:52 PM, file version: 0, 718, 0, 7181104, git hash: 0.718.0.7181104 ...\n",
                "New Studio64 version-recent-guid at 4/21/2026 1:48:11 PM, file version: 0, 718, 0, 7181104, git hash: 0.718.0.7181104 ...\n"
            ),
            "Studio64",
        );

        assert_eq!(history.len(), 3);
        assert_eq!(history[0].version, "0.718.0.7181104");
        assert_eq!(history[0].published_at, "2026-04-21T13:48:11");
        assert_eq!(history[1].version, "0.717.0.7170982");
        assert_eq!(history[2].version, "0.717.0.7170978");
    }
}