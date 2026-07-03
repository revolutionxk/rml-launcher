use std::path::Path;

use anyhow::{Context, Result};
use serde::{de::DeserializeOwned, Serialize};
use tokio::fs as tokio_fs;

pub fn read_json<T: DeserializeOwned>(path: &Path) -> Result<Option<T>> {
    if !path.exists() {
        return Ok(None);
    }

    let bytes = std::fs::read(path).with_context(|| format!("failed to read {}", path.display()))?;
    let value = serde_json::from_slice(&bytes)
        .with_context(|| format!("failed to parse {}", path.display()))?;

    Ok(Some(value))
}

pub async fn write_json<T: Serialize>(path: &Path, value: &T) -> Result<()> {
    if let Some(parent) = path.parent() {
        tokio_fs::create_dir_all(parent)
            .await
            .with_context(|| format!("failed to create {}", parent.display()))?;
    }

    let bytes = serde_json::to_vec_pretty(value).context("failed to serialize JSON")?;
    tokio_fs::write(path, bytes)
        .await
        .with_context(|| format!("failed to write {}", path.display()))?;

    Ok(())
}

#[cfg(test)]
mod tests {
    use super::*;

    use serde::Deserialize;

    #[derive(Debug, PartialEq, Serialize, Deserialize)]
    struct Sample {
        name: String,
        count: u32,
    }

    #[test]
    fn read_json_treats_a_missing_file_as_none() {
        let value: Option<Sample> = read_json(Path::new("does/not/exist.json")).unwrap();
        assert_eq!(value, None);
    }

    #[tokio::test]
    async fn write_then_read_round_trips_and_creates_parent_dirs() {
        let path = std::env::temp_dir().join("rml-store-test/nested/sample.json");
        let _ = std::fs::remove_dir_all(std::env::temp_dir().join("rml-store-test"));

        let value = Sample {
            name: "hello".into(),
            count: 3,
        };
        write_json(&path, &value).await.unwrap();

        assert_eq!(read_json::<Sample>(&path).unwrap(), Some(value));

        let _ = std::fs::remove_dir_all(std::env::temp_dir().join("rml-store-test"));
    }
}
