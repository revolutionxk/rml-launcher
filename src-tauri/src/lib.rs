mod instances;
mod logging;
mod modloader;
mod mods;
mod platform;
mod studio;
mod vinegar;

pub mod i18n;

#[cfg_attr(mobile, tauri::mobile_entry_point)]
pub fn run() {
    #[cfg(target_os = "linux")]
    std::env::set_var("WEBKIT_DISABLE_DMABUF_RENDERER", "1");

    tauri::Builder::default()
        .setup(|app| {
            logging::init(app.handle()).map_err(Into::into)
        })
        .manage(studio::StudioState::default())
        .manage(modloader::ModLoaderState::default())
        .plugin(tauri_plugin_opener::init())
        .plugin(tauri_plugin_dialog::init())
        .invoke_handler(tauri::generate_handler![
            studio::engine::apply_engine_state_patch,
            studio::engine::clear_engine_flag_overrides,
            studio::engine::get_engine_state,
            studio::engine::set_engine_target_version,
            studio::install_latest_studio,
            studio::install_studio_version,
            studio::launch_studio,
            studio::list_studio_versions,
            studio::open_studio_install_dir,
            studio::engine::remove_engine_flag_override,
            studio::revalidate_studio_version,
            studio::engine::rescan_engine_flags,
            studio::engine::set_engine_general_settings,
            studio::set_default_studio_version,
            studio::uninstall_studio,
            studio::engine::upsert_engine_flag_override,
            modloader::list_modloader_releases,
            modloader::get_modloader_status,
            modloader::install_modloader,
            modloader::uninstall_modloader,
            mods::list_mods,
            mods::set_mod_enabled,
            mods::remove_mod,
            mods::import_mod,
            mods::open_mods_dir,
            instances::list_instances,
            platform::get_host_info,
            vinegar::vinegar_status,
            vinegar::install_vinegar,
            vinegar::launch_vinegar,
        ])
        .run(tauri::generate_context!())
        .expect("error while running tauri application");
}
