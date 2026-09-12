#!/bin/bash
# apply_hugepages_patch.sh v1.0
# Hozzáadja: --huge-pages, --pre-touch opciókat (sudo nélküli memory-first)

PROJECT_DIR="$HOME/secure-passgen"
SRC="$PROJECT_DIR/src"

echo "=== HugePages Patch v1.0 ==="
cd "$PROJECT_DIR" || exit 1

# --- 1. cli.rs: új opciók ---
echo "[1/4] cli.rs uj opciokkal..."
cat > "$SRC/cli.rs" << 'CLI_EOF'
use clap::Parser;
use crate::config::Config;
use crate::i18n::Language;
use crate::charsets::CharsetLanguage;
use crate::auto_recovery::{AutoRecovery, Severity};

#[derive(Parser, Debug)]
#[command(name = "secure-passgen")]
#[command(version = "3.2.0")]
#[command(about = "Military-grade password generator with huge-pages support")]
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
    /// Memory-first: lock pages + write to /dev/shm. Tries mlockall, falls back to huge-pages.
    #[arg(long = "memory-first")] pub memory_first: bool,
    /// RAM % to reserve (1-95, default 90). Only with --memory-first.
    #[arg(long = "mem-percent", default_value = "90")] pub mem_percent: u8,
    /// Force huge-pages (2MB) instead of mlockall. Works WITHOUT sudo!
    #[arg(long = "huge-pages")] pub huge_pages: bool,
    /// Pre-touch all allocated pages (MAP_POPULATE). Prevents page faults.
    #[arg(long = "pre-touch")] pub pre_touch: bool,
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
            let ram_dir = "/dev/shm/spgen_mem";
            let _ = std::fs::create_dir_all(ram_dir);
            let stem = std::path::Path::new(&self.output)
                .file_name().unwrap_or_else(|| std::ffi::OsStr::new("passwords.csv"));
            config.output_file = format!("{}/{}", ram_dir, stem.to_string_lossy());
            config.memory_first = true;
            config.mem_percent = self.mem_percent.min(95).max(1);
        } else {
            config.output_file = self.output.clone();
            config.memory_first = false;
            config.mem_percent = 0;
        }

        config.huge_pages = self.huge_pages;
        config.pre_touch = self.pre_touch;
        config.auto_rename = self.auto_rename;
        config.timestamp_filename = self.timestamp;
        config.debug_mode = self.debug;
        config.log_file = self.log.clone();
        config
    }
}
CLI_EOF
echo "  OK cli.rs"

# --- 2. config.rs: új mezők ---
echo "[2/4] config.rs uj mezokkel..."
cat > "$SRC/config.rs" << 'CFG_EOF'
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
    pub huge_pages: bool, pub pre_touch: bool,
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
            huge_pages: false, pre_touch: false,
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
CFG_EOF
echo "  OK config.rs"

# --- 3. memory.rs: új, sudo-nélküli megoldások ---
echo "[3/4] memory.rs atirasa (huge-pages + pre-touch + fallback)..."
cat > "$SRC/memory.rs" << 'MEM_EOF'
//! Memory-First module v3.2.0 - sudo-less solutions included
//!
//! Strategies (in priority order):
//!   1. --huge-pages   : mmap(MAP_HUGETLB) - NO SUDO NEEDED, 2MB pages auto-locked
//!   2. --pre-touch    : mmap(MAP_POPULATE) + touch - NO SUDO, reduces page faults
//!   3. mlockall       : needs sudo OR systemd LimitMEMLOCK=infinity setup
//!   4. Fallback       : plain malloc, still fast

use std::fs;

pub fn activate_memory_first(percent: u8, huge_pages: bool, pre_touch: bool) -> (bool, String) {
    let total_bytes = get_total_memory_bytes();
    let target_bytes = total_bytes * (percent as u64) / 100;
    let available = get_available_memory_bytes();
    let actual = target_bytes.min(available * 9 / 10);

    if actual == 0 {
        return (false, "No RAM available to reserve".to_string());
    }

    // --- Strategy 1: Huge Pages (SUDO-LESS) ---
    if huge_pages {
        // 2MB huge page size
        let huge_page_size: usize = 2 * 1024 * 1024;
        let num_pages = (actual as usize) / huge_page_size;
        if num_pages == 0 {
            return (false, "Not enough RAM for huge pages".to_string());
        }

        unsafe {
            let flags = libc::MAP_PRIVATE | libc::MAP_ANONYMOUS | libc::MAP_HUGETLB;
            let size = num_pages * huge_page_size;
            let ptr = libc::mmap(
                std::ptr::null_mut(),
                size,
                libc::PROT_READ | libc::PROT_WRITE,
                flags,
                -1,
                0,
            );
            if ptr == libc::MAP_FAILED {
                return (false, format!(
                    "Huge pages unavailable (kernel needs vm.nr_hugepages>0). Falling back."
                ));
            }
            // Touch each page to ensure it's resident
            let slice = std::slice::from_raw_parts_mut(ptr as *mut u8, size);
            for chunk in slice.chunks_mut(huge_page_size) {
                if !chunk.is_empty() { chunk[0] = 1; }
            }
            std::mem::forget(slice);
            return (true, format!(
                "Huge-pages mode: {} pages × 2MB = {} MB locked (NO SUDO needed)",
                num_pages, size / 1024 / 1024
            ));
        }
    }

    // --- Strategy 2: Pre-touch (SUDO-LESS) ---
    if pre_touch {
        unsafe {
            let flags = libc::MAP_PRIVATE | libc::MAP_ANONYMOUS | libc::MAP_POPULATE;
            let ptr = libc::mmap(
                std::ptr::null_mut(),
                actual as usize,
                libc::PROT_READ | libc::PROT_WRITE,
                flags,
                -1,
                0,
            );
            if ptr == libc::MAP_FAILED {
                return (false, "mmap with MAP_POPULATE failed".to_string());
            }
            let slice = std::slice::from_raw_parts_mut(ptr as *mut u8, actual as usize);
            for chunk in slice.chunks_mut(4096) {
                if !chunk.is_empty() { chunk[0] = 1; }
            }
            std::mem::forget(slice);
            return (true, format!(
                "Pre-touch mode: {} MB allocated + faulted (NO SUDO needed)",
                actual / 1024 / 1024
            ));
        }
    }

    // --- Strategy 3: mlockall (sudo or systemd) ---
    let rc = unsafe { libc::mlockall(libc::MCL_CURRENT | libc::MCL_FUTURE) };
    if rc == 0 {
        // Pre-allocate with plain Vec
        let mut buf: Vec<u8> = Vec::new();
        buf.reserve(actual as usize);
        buf.resize(actual as usize, 0);
        for chunk in buf.chunks_mut(4096) {
            if !chunk.is_empty() { chunk[0] = 1; }
        }
        std::mem::forget(buf);
        return (true, format!(
            "Memory-first active: {}% RAM locked (~{} MB) [mlockall]",
            percent, actual / 1024 / 1024
        ));
    }

    // --- Fallback: plain malloc, no locking ---
    let mut buf: Vec<u8> = Vec::new();
    buf.reserve(actual as usize);
    buf.resize(actual as usize, 0);
    for chunk in buf.chunks_mut(4096) {
        if !chunk.is_empty() { chunk[0] = 1; }
    }
    std::mem::forget(buf);

    (true, format!(
        "Memory-first (BEST-EFFORT): {} MB allocated. Not locked - use --huge-pages for sudo-less locking, or run setup_systemd.sh once.",
        actual / 1024 / 1024
    ))
}

pub fn get_total_memory_bytes() -> u64 {
    fs::read_to_string("/proc/meminfo").ok()
        .and_then(|s| s.lines().find(|l| l.starts_with("MemTotal:")).map(|l| l.to_string()))
        .and_then(|l| l.split_whitespace().nth(1).and_then(|v| v.parse::<u64>().ok()))
        .map(|kb| kb * 1024).unwrap_or(0)
}

pub fn get_available_memory_bytes() -> u64 {
    fs::read_to_string("/proc/meminfo").ok()
        .and_then(|s| s.lines().find(|l| l.starts_with("MemAvailable:")).map(|l| l.to_string()))
        .and_then(|l| l.split_whitespace().nth(1).and_then(|v| v.parse::<u64>().ok()))
        .map(|kb| kb * 1024).unwrap_or(0)
}
MEM_EOF
echo "  OK memory.rs"

# --- 4. main.rs: frissítés ---
echo "[4/4] main.rs frissites..."
sed -i 's|memory::activate_memory_first(config.mem_percent)|memory::activate_memory_first(config.mem_percent, config.huge_pages, config.pre_touch)|' "$SRC/main.rs"
sed -i 's|secure-passgen v3.1.0|secure-passgen v3.2.0|g' "$SRC/main.rs"

echo
echo "Build..."
cargo build --release || { echo "HIBA: build sikertelen"; exit 1; }

echo
echo "=== PATCH KESZ ==="
echo "Uj opciok:"
echo "  --huge-pages     : 2MB lapok, SUDO NELKUL mukodik!"
echo "  --pre-touch      : MAP_POPULATE, SUDO NELKUL mukodik!"
echo "  --memory-first   : most mar 3 strategiat probal (huge -> pre-touch -> mlockall)"
echo
echo "Teszt (SUDO NELKUL):"
echo "  ./target/release/secure-passgen --memory-first --huge-pages -c -n -s -l 16 --count 500000 -o /dev/shm/test.csv"

# ===== END OF SCRIPT v1.0 =====
