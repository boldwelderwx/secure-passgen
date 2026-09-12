//! Hyphen Formatter Plugin

use super::Plugin;

pub struct HyphenFormatter { chunk_size: usize }

impl HyphenFormatter {
    pub fn new(chunk_size: usize) -> Self { Self { chunk_size } }
}

impl Plugin for HyphenFormatter {
    fn name(&self) -> &str { "Hyphen Formatter" }
    fn description(&self) -> &str { "Adds hyphens every N characters" }
    fn process_password(&self, password: String) -> String {
        let chars: Vec<char> = password.chars().collect();
        let mut result = String::new();
        for (i, ch) in chars.iter().enumerate() {
            if i > 0 && i % self.chunk_size == 0 {
                result.push('-');
            }
            result.push(*ch);
        }
        result
    }
}
