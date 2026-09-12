//! Plugin rendszer

/// Plugin trait - Send + Sync a parhuzamos (tobb szalas) feldolgozashoz.
/// Minden pluginnak thread-safe-nak kell lennie.
pub trait Plugin: Send + Sync {
    fn name(&self) -> &str;
    fn description(&self) -> &str;
    fn process_password(&self, password: String) -> String;
}

pub mod uppercase_validator;
pub mod hyphen_formatter;
