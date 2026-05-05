use std::{fs, sync::OnceLock};

use anyhow::{Context, Result};
use tauri::{AppHandle, Manager};
use tracing_appender::rolling;
use tracing_subscriber::{fmt::writer::MakeWriterExt, prelude::*, EnvFilter};

static LOGGING_INITIALIZED: OnceLock<()> = OnceLock::new();

pub fn init(app: &AppHandle) -> Result<()> {
    if LOGGING_INITIALIZED.get().is_some() {
        return Ok(());
    }

    let log_dir = app
        .path()
        .app_data_dir()
        .context("failed to resolve the app data directory for logging")?
        .join("logs");

    fs::create_dir_all(&log_dir)
        .with_context(|| format!("failed to create {}", log_dir.display()))?;

    let file_appender = rolling::daily(&log_dir, "rml-launcher.log");
    let (file_writer, guard) = tracing_appender::non_blocking(file_appender);
    let subscriber = tracing_subscriber::registry()
        .with(EnvFilter::try_from_default_env().unwrap_or_else(|_| EnvFilter::new("info")))
        .with(
            tracing_subscriber::fmt::layer()
                .with_ansi(cfg!(debug_assertions))
                .with_target(true)
                .with_thread_ids(true)
                .with_writer(std::io::stderr.and(file_writer)),
        );

    tracing::subscriber::set_global_default(subscriber)
        .context("failed to initialize the tracing subscriber")?;

    let _ = Box::leak(Box::new(guard));
    let _ = LOGGING_INITIALIZED.set(());

    tracing::info!(log_dir = %log_dir.display(), "initialized backend logging");

    Ok(())
}