pub const SUPPORTED_LOCALES: [&str; 2] = ["en-US", "pt-BR"];

const EN_US_MESSAGES: &str = include_str!("../../locales/en-US.ftl");
const PT_BR_MESSAGES: &str = include_str!("../../locales/pt-BR.ftl");

pub fn messages_for(locale: &str) -> Option<&'static str> {
    match locale {
        "en-US" => Some(EN_US_MESSAGES),
        "pt-BR" => Some(PT_BR_MESSAGES),
        _ => None,
    }
}
