pub const CURRENT_CHANNEL: &str = "LIVE";
pub const STUDIO_INSTALL_EVENT: &str = "studio-install-progress";

pub const APP_SETTINGS_XML: &str = include_str!("../../resources/app_settings.xml");

pub const OAUTH2_CONFIG_JSON: &str = include_str!("../../resources/OAuth2Config.json");

pub fn binary_target() -> &'static str {
    if cfg!(target_pointer_width = "64") {
        "WindowsStudio64"
    } else {
        "WindowsStudio"
    }
}

pub fn deploy_history_product() -> &'static str {
  if cfg!(target_pointer_width = "64") {
    "Studio64"
  } else {
    "Studio"
  }
}

pub fn package_extract_root(package_stem: &str, version_major: u32) -> &'static str {
    match package_stem {
        "ApplicationConfig" if version_major >= 532 => "ApplicationConfig",
        "BuiltInPlugins" => "BuiltInPlugins",
        "BuiltInStandalonePlugins" => "BuiltInStandalonePlugins",
        "content-api-docs" => "content/api_docs",
        "content-avatar" => "content/avatar",
        "content-configs" => "content/configs",
        "content-fonts" => "content/fonts",
        "content-models" => "content/models",
        "content-platform-dictionaries" => "PlatformContent/pc/dictionaries",
        "content-platform-fonts" => "PlatformContent/pc/fonts",
        "content-qt_translations" => "content/qt_translations",
        "content-sky" => "content/sky",
        "content-sounds" => "content/sounds",
        "content-studio_svg_textures" => "content/studio_svg_textures",
        "content-terrain" => "PlatformContent/pc/terrain",
        "content-textures2" => "content/textures",
        "content-textures3" => "PlatformContent/pc/textures",
        "extracontent-luapackages" => "ExtraContent/LuaPackages",
        "extracontent-models" => "ExtraContent/models",
        "extracontent-scripts" => "ExtraContent/scripts",
        "extracontent-textures" => "ExtraContent/textures",
        "extracontent-translations" => "ExtraContent/translations",
        "Plugins" => "Plugins",
        "Qml" => "Qml",
        "shaders" => "shaders",
        "ssl" => "ssl",
        "StudioFonts" => "StudioFonts",
        "studiocontent-models" if version_major >= 680 => "StudioContent/models",
        "studiocontent-textures" if version_major >= 680 => "StudioContent/textures",
        _ => "",
    }
}

#[cfg(test)]
mod tests {
    use super::package_extract_root;

    #[test]
    fn resolves_known_package_roots() {
        assert_eq!(package_extract_root("content-avatar", 719), "content/avatar");
        assert_eq!(package_extract_root("Libraries", 719), "");
        assert_eq!(package_extract_root("studiocontent-models", 719), "StudioContent/models");
        assert_eq!(package_extract_root("studiocontent-models", 600), "");
    }
}