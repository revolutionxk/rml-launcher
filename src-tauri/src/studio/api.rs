use std::collections::HashSet;

use std::time::Duration;

use anyhow::{anyhow, bail, Context, Result};
use chrono::NaiveDateTime;
use reqwest::Client;
use tokio::time::sleep;
use tracing::{info, warn};

use super::{
    config::{binary_target, deploy_history_product},
    model::{CurrentVersionResponse, PackageManifestEntry, StudioBuild},
};

const SETUP_BASE_URLS: &[&str] = &["https://setup.rbxcdn.com"];
const CLIENT_SETTINGS_BASE_URL: &str = "https://clientsettingscdn.roblox.com/v2/client-version";
const USER_AGENT: &str = "RML Launcher/0.1.0";
const VERSION_GUID_PREFIX: &str = "version-";
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
        version_guid = %response.client_version_upload,
        "resolved current Roblox Studio version"
    );

    Ok(response)
}

pub async fn fetch_package_manifest(version_guid: &str) -> Result<Vec<PackageManifestEntry>> {
    let normalized_version_guid = normalize_version_guid(version_guid);
    let manifest_candidates = [
        format!("{normalized_version_guid}-rbxPkgManifest.txt"),
        format!("{normalized_version_guid}-rbxManifest.txt"),
    ];
    let mut last_error = None;

    for manifest_path in manifest_candidates {
        match fetch_setup_text(&manifest_path, "package manifest").await {
            Ok(data) => {
                info!(version_guid, manifest_path, "resolved Roblox Studio package manifest");
                return parse_package_manifest(&data)
                    .with_context(|| format!("failed to parse the package manifest at {manifest_path}"));
            }
            Err(error) => {
                warn!(version_guid, manifest_path, error = %error, "package manifest candidate failed");
                last_error = Some(error);
            }
        }
    }

    Err(last_error.unwrap_or_else(|| {
        anyhow!(
            "Roblox did not expose a package manifest for {} after all retry attempts",
            version_guid,
        )
    }))
}

pub async fn fetch_build_history() -> Result<Vec<StudioBuild>> {
    let data = fetch_setup_text("DeployHistory.txt", "Studio build history").await?;

    Ok(parse_deploy_history(&data, deploy_history_product()))
}

pub fn package_url(version_guid: &str, package_name: &str) -> String {
    let normalized_version_guid = normalize_version_guid(version_guid);

    format!("{}/{normalized_version_guid}-{package_name}", SETUP_BASE_URLS[0])
}

pub(super) fn same_version_guid(left: &str, right: &str) -> bool {
    normalize_version_guid(left).eq_ignore_ascii_case(&normalize_version_guid(right))
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

fn normalize_version_guid(version_guid: &str) -> String {
    let trimmed = version_guid.trim();

    if trimmed.len() >= VERSION_GUID_PREFIX.len()
        && trimmed[..VERSION_GUID_PREFIX.len()].eq_ignore_ascii_case(VERSION_GUID_PREFIX)
    {
        return trimmed.to_string();
    }

    format!("{VERSION_GUID_PREFIX}{trimmed}")
}

fn parse_package_manifest(data: &str) -> Result<Vec<PackageManifestEntry>> {
    let mut lines = data.lines();
    let manifest_version = lines.next().unwrap_or_default();

    if manifest_version.trim() != "v0" {
        bail!("unexpected package manifest version: {manifest_version}");
    }

    let mut packages = Vec::new();

    loop {
        let Some(name) = lines.next() else {
            break;
        };
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
    let mut seen_guids = HashSet::new();

    for raw_line in data.lines().rev() {
        let line = raw_line.trim();
        if !line.starts_with(&prefix) {
            continue;
        }

        let Some((header, details)) = line.split_once(" at ") else {
            continue;
        };
        let Some(version_guid) = header.strip_prefix(&prefix) else {
            continue;
        };

        if version_guid.eq_ignore_ascii_case("hidden") || !seen_guids.insert(version_guid.to_string()) {
            continue;
        }

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

        builds.push(StudioBuild {
            version_guid: version_guid.to_string(),
            version,
            published_at,
        });
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
    use super::{normalize_version_guid, parse_deploy_history, parse_package_manifest, same_version_guid};

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
    fn parses_recent_build_history_and_skips_hidden_entries() {
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

        assert_eq!(history.len(), 2);
        assert_eq!(history[0].version_guid, "recent-guid");
        assert_eq!(history[0].version, "0.718.0.7181104");
        assert_eq!(history[1].version_guid, "older-guid");
    }

    #[test]
    fn normalizes_setup_version_guids() {
        assert_eq!(normalize_version_guid("recent-guid"), "version-recent-guid");
        assert_eq!(normalize_version_guid("version-recent-guid"), "version-recent-guid");
        assert!(same_version_guid("recent-guid", "version-recent-guid"));
    }
}