use clap::Parser;
use crate::config::Config;
use crate::i18n::Language;
use crate::charsets::CharsetLanguage;
use crate::auto_recovery::{AutoRecovery, Severity};

#[derive(Parser, Debug)]
#[command(name = "secure-passgen")]
#[command(version = "4.0.0")]
#[command(about = "Military-grade password generator with THP memory-first (sudo-less)")]
pub struct Cli {
    #[arg(short = 'c', long = "capitals")] pub capitals: bool,
    #[arg(short = 'n', long = "numbers")] pub numbers: bool,
    #[arg(short = 's', long = "symbols")] pub symbols: bool,
    #[arg(short = 'B', long = "no-ambiguous")] pub no_ambiguous: bool,
    #[arg(short = 'l', long = "length", default_value = "8")] pub length: usize,
    #[arg(long = "count")] pub count: Option<usize>,
    #[arg(long = "extreme-random")] pub extreme_random: bool,
    #[arg(long = "extreme-iter", default_value = "10000")] pub extreme_iter: u32,
    #[arg(long = "password-db")] pub password_db: bool,
    #[arg(short = 'o', long = "output", default_value = "passwords.csv")] pub output: String,
    #[arg(long = "auto-rename", default_value = "true")] pub auto_rename: bool,
    #[arg(long = "timestamp")] pub timestamp: bool,
    #[arg(long = "debug")] pub debug: bool,
    #[arg(long = "log")] pub log: Option<String>,
    #[arg(long = "plugins")] pub plugins: Option<String>,
    #[arg(long = "language", default_value = "auto")] pub language: String,
    #[arg(long = "charset", default_value = "latin")] pub charset: String,
    /// Memory-first: allocate a THP-optimized buffer (sudo-less)
    #[arg(long = "memory-first")] pub memory_first: bool,
    /// RAM % to reserve for the buffer (1-70, default 25)
    #[arg(long = "mem-percent", default_value = "25")] pub mem_percent: u8,
    pub count_positional: Option<usize>,
}

impl Cli {
    pub fn to_config(&self, recovery: &mut AutoRecovery) -> Config {
        let mut config = Config::new();

        if self.language.to_lowercase() != "auto" {
            if let Some(lang) = Language::from_code(&self.language) {
                config.ui_language = lang;
            } else {
                recovery.add_fix(format!("Unknown language: {}", self.language), "Using system default", Severity::Warning);
            }
        }

        if let Some(charset_lang) = CharsetLanguage::from_code(&self.charset) {
            config.charset_language = charset_lang;
        } else {
            recovery.add_fix(format!("Unknown charset: {}", self.charset), "Using Latin charset", Severity::Warning);
        }

        config.use_lowercase = true;
        config.use_uppercase = self.capitals;
        config.use_numbers = self.numbers;
        config.use_symbols = self.symbols;
        config.exclude_ambiguous = self.no_ambiguous;
        config.length = self.length;
        config.count = self.count.or(self.count_positional).unwrap_or(10);
        config.extreme_random = self.extreme_random;
        config.extreme_iterations = self.extreme_iter;
        config.database_mode = self.password_db;

        if self.memory_first {
            config.output_file = self.output.clone();
            config.memory_first = true;
            config.mem_percent = self.mem_percent.min(70).max(1);
        } else {
            config.output_file = self.output.clone();
            config.memory_first = false;
            config.mem_percent = 0;
        }

        config.auto_rename = self.auto_rename;
        config.timestamp_filename = self.timestamp;
        config.debug_mode = self.debug;
        config.log_file = self.log.clone();
        config
    }
}
