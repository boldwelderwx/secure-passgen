//! Uppercase Validator Plugin

use super::Plugin;
use rand::Rng;

pub struct UppercaseValidator;

impl UppercaseValidator {
    pub fn new() -> Self { Self }
}

impl Plugin for UppercaseValidator {
    fn name(&self) -> &str { "Uppercase Validator" }
    fn description(&self) -> &str { "Ensures every password has at least one uppercase letter" }
    fn process_password(&self, password: String) -> String {
        if password.chars().any(|c| c.is_uppercase()) {
            return password;
        }
        let uppercase_chars = "ABCDEFGHIJKLMNOPQRSTUVWXYZ";
        let mut rng = rand::thread_rng();
        let random_char = uppercase_chars.chars().nth(rng.gen_range(0..uppercase_chars.len())).unwrap();
        format!("{}{}", password, random_char)
    }
}
