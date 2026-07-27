use super::model::{InstallPhase, StudioInstallProgress};

pub trait StudioProgressSink {
    fn report(&self, progress: StudioInstallProgress);
}

pub(super) struct ProgressReporter<'a, S: StudioProgressSink> {
    sink: &'a S,
    version_guid: String,
    version: String,
    channel: String,
}

impl<'a, S: StudioProgressSink> ProgressReporter<'a, S> {
    pub(super) fn new(sink: &'a S, version_guid: &str, version: &str, channel: &str) -> Self {
        Self {
            sink,
            version_guid: version_guid.to_string(),
            version: version.to_string(),
            channel: channel.to_string(),
        }
    }

    #[allow(clippy::too_many_arguments)]
    pub(super) fn emit(
        &self,
        phase: InstallPhase,
        current_package: Option<String>,
        downloaded_bytes: u64,
        total_download_bytes: u64,
        extracted_packages: usize,
        total_packages: usize,
        error: Option<String>,
    ) {
        let payload = StudioInstallProgress {
            version_guid: self.version_guid.clone(),
            version: self.version.clone(),
            channel: self.channel.clone(),
            progress: compute_progress(&phase, downloaded_bytes, total_download_bytes, extracted_packages, total_packages),
            phase,
            current_package,
            downloaded_bytes,
            total_download_bytes,
            extracted_packages,
            total_packages,
            error,
        };

        self.sink.report(payload);
    }
}

fn compute_progress(
    phase: &InstallPhase,
    downloaded_bytes: u64,
    total_download_bytes: u64,
    extracted_packages: usize,
    total_packages: usize,
) -> f64 {
    let download_ratio = if total_download_bytes == 0 {
        0.0
    } else {
        downloaded_bytes as f64 / total_download_bytes as f64
    };

    let extraction_ratio = if total_packages == 0 {
        0.0
    } else {
        extracted_packages as f64 / total_packages as f64
    };

    match phase {
        InstallPhase::Resolving => 2.0,
        InstallPhase::Downloading => (download_ratio * 80.0).clamp(0.0, 80.0),
        InstallPhase::Extracting => (80.0 + extraction_ratio * 18.0).clamp(80.0, 98.0),
        InstallPhase::Finalizing => 99.0,
        InstallPhase::Completed => 100.0,
        InstallPhase::Failed => {
            if extracted_packages > 0 {
                (80.0 + extraction_ratio * 18.0).clamp(0.0, 99.0)
            } else {
                (download_ratio * 80.0).clamp(0.0, 80.0)
            }
        }
    }
}
