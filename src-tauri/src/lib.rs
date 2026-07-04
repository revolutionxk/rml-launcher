mod error;
mod instances;
mod logging;
mod modloader;
mod mods;
mod paths;
mod platform;
mod protocol;
mod startup;
mod store;
mod studio;
mod vinegar;

pub mod i18n;

pub(crate) use error::{AppError, CommandResult};
pub(crate) use paths::Paths;

#[cfg_attr(mobile, tauri::mobile_entry_point)]
pub fn run() {
    #[cfg(target_os = "linux")]
    if is_wayland_session() {
        std::env::set_var("WEBKIT_DISABLE_DMABUF_RENDERER", "1");
    }

    tauri::Builder::default()
        .plugin(tauri_plugin_single_instance::init(|app, argv, _cwd| {
            startup::handle_second_instance(app, argv);
        }))
        .setup(|app| {
            if let Err(error) = logging::init(app.handle()) {
                return Err(error.into());
            }

            Ok(())
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
            protocol::set_studio_protocol_handler,
            protocol::studio_protocol_status,
            startup::create_quick_launch_shortcut,
            startup::get_startup_options,
            vinegar::vinegar_status,
            vinegar::install_vinegar,
            vinegar::launch_vinegar,
        ])
        .run(tauri::generate_context!())
        .expect("error while running tauri application");
}

#[cfg(target_os = "linux")]
fn is_wayland_session() -> bool {
    std::env::var_os("WAYLAND_DISPLAY").is_some()
        || std::env::var("XDG_SESSION_TYPE")
            .is_ok_and(|session_type| session_type.eq_ignore_ascii_case("wayland"))
}
