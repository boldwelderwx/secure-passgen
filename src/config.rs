use crate::i18n::Language;
use crate::charsets::CharsetLanguage;
use crate::auto_recovery::AutoRecovery;

#[derive(Debug, Clone)]
pub struct Config {
    pub use_lowercase: bool, pub use_uppercase: bool, pub use_numbers: bool,
    pub use_symbols: bool, pub exclude_ambiguous: bool,
    pub length: usize, pub count: usize,
    pub extreme_random: bool, pub extreme_iterations: u32,
    pub database_mode: bool, pub max_rows: usize, pub max_columns: usize,
    pub output_file: String, pub auto_rename: bool, pub timestamp_filename: bool,
    pub debug_mode: bool, pub log_file: Option<String>,
    pub ui_language: Language, pub charset_language: CharsetLanguage,
    pub memory_first: bool, pub mem_percent: u8,
}

impl Default for Config {
    fn default() -> Self {
        Self {
            use_lowercase: true, use_uppercase: false, use_numbers: false,
            use_symbols: false, exclude_ambiguous: false,
            length: 8, count: 10,
            extreme_random: false, extreme_iterations: 10000,
            database_mode: false, max_rows: 1000, max_columns: 26,
            output_file: "passwords.csv".to_string(),
            auto_rename: true, timestamp_filename: false,
            debug_mode: false, log_file: None,
            ui_language: Language::detect_system_language(),
            charset_language: CharsetLanguage::Latin,
            memory_first: false, mem_percent: 0,
        }
    }
}

impl Config {
    pub fn new() -> Self { Self::default() }

    pub fn build_charset(&self, recovery: &mut AutoRecovery) -> String {
        let base = self.charset_language.charset();
        let mut charset = String::new();
        for c in base.chars() {
            let is_lower_pool = c.is_lowercase() || (c.is_alphabetic() && !c.is_uppercase());
            let is_upper_pool = c.is_uppercase();
            let is_num = c.is_numeric();
            let is_sym = !c.is_alphanumeric() && !c.is_whitespace();
            if self.use_lowercase && is_lower_pool { charset.push(c); continue; }
            if self.use_uppercase && is_upper_pool { charset.push(c); continue; }
            if self.use_numbers && is_num { charset.push(c); continue; }
            if self.use_symbols && is_sym { charset.push(c); continue; }
        }
        if self.exclude_ambiguous {
            let ambiguous = "1lI0Oo";
            charset.retain(|c| !ambiguous.contains(c));
        }
        recovery.ensure_valid_charset(&charset, base)
    }

    pub fn validate(&mut self, recovery: &mut AutoRecovery) {
        self.length = recovery.ensure_valid_length(self.length);
        self.count = recovery.ensure_valid_count(self.count);
    }

    pub fn calculate_grid_dimensions(&mut self) {
        if !self.database_mode { return; }
        let total = self.count;
        if total <= self.max_rows { self.max_columns = 1; }
        else {
            self.max_columns = (total + self.max_rows - 1) / self.max_rows;
            if self.max_columns > 1000 {
                self.max_rows = (total + 1000 - 1) / 1000;
                self.max_columns = 1000;
            }
        }
        self.count = self.max_rows * self.max_columns;
    }
}
