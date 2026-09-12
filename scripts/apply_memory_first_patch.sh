#!/bin/bash
# ==============================================================================
# apply_memory_first_patch.sh v1.0
# Hozzaadja: --memory-first es --mem-percent <N> opciokat
# - RAM-disk (/dev/shm) alapertelmezett kimenet memory-first modban
# - mlockall: a folyamat memoriaja nem swap-elodik ki (SQL Server stilus)
# - ulimit -l ellenorzes (root jog kell hozza, vagy sudo)
# ==============================================================================

PROJECT_DIR="$HOME/secure-passgen"
SRC="$PROJECT_DIR/src"

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; CYAN='\033[0;36m'; BOLD='\033[1m'; NC='\033[0m'

echo -e "${CYAN}╔══════════════════════════════════════════════════════════════╗${NC}"
echo -e "${CYAN}║${NC} ${BOLD}Memory-First Patch v1.0 (RAM-disk + mlockall)${NC}             ${CYAN}║${NC}"
echo -e "${CYAN}╚══════════════════════════════════════════════════════════════╝${NC}"

# --- 1. Ellenorzes ---
echo -e "${BOLD}[1/6] Ellenorzes...${NC}"
[ -f "$PROJECT_DIR/Cargo.toml" ] || { echo -e "${RED}HIBA: Cargo.toml nem talalhato${NC}"; exit 1; }
cd "$PROJECT_DIR" || exit 1
echo -e "  ${GREEN}OK: projekt talalva${NC}"

# --- 2. libc fuggoseg (mlockall syscall-hoz) ---
echo -e "${BOLD}[2/6] libc fuggoseg hozzaadasa...${NC}"
if grep -q '^libc' Cargo.toml; then
    echo -e "  ${YELLOW}libc mar szerepel${NC}"
else
    cargo add libc || { echo -e "${RED}HIBA: cargo add libc sikertelen${NC}"; exit 1; }
    echo -e "  ${GREEN}libc hozzaadva${NC}"
fi

# --- 3. cli.rs - uj opciok ---
echo -e "${BOLD}[3/6] cli.rs frissitese (--memory-first, --mem-percent)...${NC}"
cat > "$SRC/cli.rs" << 'CLI_EOF'
//! CLI argument parser v3.1.0 with --memory-first

use clap::Parser;
use crate::config::Config;
use crate::i18n::Language;
use crate::charsets::CharsetLanguage;
use crate::auto_recovery::{AutoRecovery, Severity};

#[derive(Parser, Debug)]
#[command(name = "secure-passgen")]
#[command(version = "3.1.0")]
#[command(about = "Military-grade fool-proof password generator with memory-first mode")]
pub struct Cli {
    #[arg(short = 'c', long = "capitals")]
    pub capitals: bool,
    #[arg(short = 'n', long = "numbers")]
    pub numbers: bool,
    #[arg(short = 's', long = "symbols")]
    pub symbols: bool,
    #[arg(short = 'B', long = "no-ambiguous")]
    pub no_ambiguous: bool,
    #[arg(short = 'l', long = "length", default_value = "8")]
    pub length: usize,
    #[arg(long = "count")]
    pub count: Option<usize>,
    #[arg(long = "extreme-random")]
    pub extreme_random: bool,
    #[arg(long = "extreme-iter", default_value = "10000")]
    pub extreme_iter: u32,
    #[arg(long = "password-db")]
    pub password_db: bool,
    #[arg(short = 'o', long = "output", default_value = "passwords.csv")]
    pub output: String,
    #[arg(long = "auto-rename", default_value = "true")]
    pub auto_rename: bool,
    #[arg(long = "timestamp")]
    pub timestamp: bool,
    #[arg(long = "debug")]
    pub debug: bool,
    #[arg(long = "log")]
    pub log: Option<String>,
    #[arg(long = "plugins")]
    pub plugins: Option<String>,
    #[arg(long = "language", default_value = "auto")]
    pub language: String,
    #[arg(long = "charset", default_value = "latin")]
    pub charset: String,
    /// Memory-first mode: locks RAM pages + writes to /dev/shm by default.
    /// SQL Server "Lock Pages in Memory" style.
    #[arg(long = "memory-first")]
    pub memory_first: bool,
    /// RAM percentage to reserve (1-95, default 90).
    /// Only effective with --memory-first.
    #[arg(long = "mem-percent", default_value = "90")]
    pub mem_percent: u8,
    /// Plain-number positional count
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

        // Memory-first mode: default output to RAM-disk
        if self.memory_first {
            let ram_dir = "/dev/shm/spgen_mem";
            let _ = std::fs::create_dir_all(ram_dir);
            let stem = std::path::Path::new(&self.output)
                .file_name()
                .unwrap_or_else(|| std::ffi::OsStr::new("passwords.csv"));
            config.output_file = format!("{}/{}", ram_dir, stem.to_string_lossy());
            config.memory_first = true;
            config.mem_percent = self.mem_percent.min(95).max(1);
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
CLI_EOF
echo -e "  ${GREEN}cli.rs frissitve${NC}"

# --- 4. config.rs - memory_first field ---
echo -e "${BOLD}[4/6] config.rs frissitese (memory_first field)...${NC}"
cat > "$SRC/config.rs" << 'CFG_EOF'
//! Configuration module v3.1.0

use crate::i18n::Language;
use crate::charsets::CharsetLanguage;
use crate::auto_recovery::AutoRecovery;

#[derive(Debug, Clone)]
pub struct Config {
    pub use_lowercase: bool,
    pub use_uppercase: bool,
    pub use_numbers: bool,
    pub use_symbols: bool,
    pub exclude_ambiguous: bool,
    pub length: usize,
    pub count: usize,
    pub extreme_random: bool,
    pub extreme_iterations: u32,
    pub database_mode: bool,
    pub max_rows: usize,
    pub max_columns: usize,
    pub output_file: String,
    pub auto_rename: bool,
    pub timestamp_filename: bool,
    pub debug_mode: bool,
    pub log_file: Option<String>,
    pub ui_language: Language,
    pub charset_language: CharsetLanguage,
    pub memory_first: bool,
    pub mem_percent: u8,
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
        if total <= self.max_rows {
            self.max_columns = 1;
        } else {
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
echo -e "  ${GREEN}config.rs frissitve${NC}"

# --- 5. memory.rs uj modul - mlockall + RAM foglalas ---
echo -e "${BOLD}[5/6] memory.rs uj modul...${NC}"
cat > "$SRC/memory.rs" << 'MEM_EOF'
//! Memory-First modul - RAM-disk + mlockall (SQL Server stilus)

use std::fs;

/// Aktiválja a memory-first módot: mlockall + RAM pre-allocation.
/// Visszatérési érték: (sikerült-e, üzenet).
pub fn activate_memory_first(percent: u8) -> (bool, String) {
    // 1. mlockall - minden jelenlegi és jövőbeli memória lap RAM-ban marad
    let rc = unsafe { libc::mlockall(libc::MCL_CURRENT | libc::MCL_FUTURE) };
    if rc != 0 {
        let err = std::io::Error::last_os_error();
        return (false, format!("mlockall failed: {} (try: sudo sh -c 'ulimit -l unlimited && ./secure-passgen ...')", err));
    }

    // 2. RAM pre-allocation - a kért % lefoglalása egy Vec-ben
    let total_bytes = get_total_memory_bytes();
    let target_bytes = total_bytes * (percent as u64) / 100;

    // Csak akkor foglalunk, ha van elég szabad RAM
    let available = get_available_memory_bytes();
    let actual = target_bytes.min(available * 9 / 10); // 10% tartalék

    let mut _ram_buffer: Vec<u8> = Vec::new();
    if actual > 0 {
        _ram_buffer.reserve(actual as usize);
        _ram_buffer.resize(actual as usize, 0);
        // Ténylegesen hozzányúlunk minden laphoz, hogy a kernel allokálja
        for chunk in _ram_buffer.chunks_mut(4096) {
            if !chunk.is_empty() { chunk[0] = 1; }
        }
    }

    // A buffer intentionally marad a program futása alatt (memória foglalva)
    // Ez megakadályozza, hogy más program elfoglalja a RAM-ot.
    std::mem::forget(_ram_buffer);

    (true, format!("Memory-first active: {}% RAM locked (~{} MB)", percent, actual / 1024 / 1024))
}

pub fn get_total_memory_bytes() -> u64 {
    fs::read_to_string("/proc/meminfo")
        .ok()
        .and_then(|s| s.lines().find(|l| l.starts_with("MemTotal:")).map(|l| l.to_string()))
        .and_then(|l| l.split_whitespace().nth(1).and_then(|v| v.parse::<u64>().ok()))
        .map(|kb| kb * 1024)
        .unwrap_or(0)
}

pub fn get_available_memory_bytes() -> u64 {
    fs::read_to_string("/proc/meminfo")
        .ok()
        .and_then(|s| s.lines().find(|l| l.starts_with("MemAvailable:")).map(|l| l.to_string()))
        .and_then(|l| l.split_whitespace().nth(1).and_then(|v| v.parse::<u64>().ok()))
        .map(|kb| kb * 1024)
        .unwrap_or(0)
}
MEM_EOF
echo -e "  ${GREEN}memory.rs letrehozva${NC}"

# --- 6. lib.rs + main.rs - memory modul beintegrálása ---
echo -e "${BOLD}[6/6] lib.rs + main.rs integracio...${NC}"

# lib.rs - memory modul export
grep -q "pub mod memory;" "$SRC/lib.rs" || echo "pub mod memory;" >> "$SRC/lib.rs"

# main.rs - memory_first aktiválása futtatás előtt
cat > "$SRC/main.rs" << 'MAIN_EOF'
//! Secure PassGen v3.1.0 - Memory-First mode support

use clap::Parser;
use colored::*;
use std::time::Instant;
use secure_passgen::{
    cli::Cli,
    config::Config,
    csv_writer::CsvWriter,
    i18n::Translations,
    auto_recovery::AutoRecovery,
    memory,
    plugins::{Plugin, uppercase_validator::UppercaseValidator, hyphen_formatter::HyphenFormatter},
};

fn preprocess_args() -> (Vec<String>, Option<String>) {
    let mut out = Vec::new();
    let mut shorthand: Option<String> = None;
    for arg in std::env::args().skip(1) {
        let is_sh = arg.starts_with('-') && !arg.starts_with("--") && {
            let t = arg.trim_start_matches('-');
            let core = t.trim_end_matches(|c: char| c == 'K' || c == 'k' || c == 'M' || c == 'm');
            let suffix_len = t.len() - core.len();
            suffix_len <= 1 && !core.is_empty() && core.chars().all(|c| c.is_ascii_digit())
        };
        if is_sh && shorthand.is_none() { shorthand = Some(arg.clone()); }
        else { out.push(arg); }
    }
    (out, shorthand)
}

fn shorthand_to_count(s: &str) -> usize {
    let t = s.trim_start_matches('-').to_uppercase();
    if t.ends_with('M') { t[..t.len()-1].parse().unwrap_or(1) * 1_000_000 }
    else if t.ends_with('K') { t[..t.len()-1].parse().unwrap_or(1) * 1_000 }
    else { t.parse().unwrap_or(10) }
}

fn main() {
    let (args, shorthand) = preprocess_args();
    let mut final_args: Vec<String> = vec!["secure-passgen".to_string()];
    final_args.extend(args);
    if let Some(sh) = shorthand {
        if !final_args.iter().any(|a| a == "--count") {
            final_args.push("--count".to_string());
            final_args.push(shorthand_to_count(&sh).to_string());
        }
    }
    if let Err(e) = run(final_args) {
        eprintln!("{}", "╔════════════════════════════════════════════════════════════════╗".red().bold());
        eprintln!("{}", "║                    UNEXPECTED ERROR OCCURRED                  ║".red().bold());
        eprintln!("{}", "╠════════════════════════════════════════════════════════════════╣".red().bold());
        eprintln!("║ {} {}", "Message:".bold(), e.to_string().red());
        eprintln!("{}", "╚════════════════════════════════════════════════════════════════╝".red().bold());
        std::process::exit(1);
    }
}

fn run(final_args: Vec<String>) -> Result<(), Box<dyn std::error::Error>> {
    let start_time = Instant::now();
    let cli = Cli::parse_from(final_args);
    let mut recovery = AutoRecovery::new();
    let mut config = cli.to_config(&mut recovery);

    // Memory-First aktiválás HA kérve van
    if config.memory_first {
        let (ok, msg) = memory::activate_memory_first(config.mem_percent);
        if ok {
            println!("{}", format!("  ✓ {}", msg).green().bold());
        } else {
            println!("{}", format!("  ⚠ Memory-first FAILED: {}", msg).yellow().bold());
            recovery.add_fix("Memory lock failed", msg, crate::auto_recovery::Severity::Warning);
        }
    }

    let translations = Translations::new(config.ui_language);
    print_banner(&translations);
    print_system_info(&translations);

    config.validate(&mut recovery);
    config.calculate_grid_dimensions();

    let plugins = load_plugins(&cli);
    print_execution_preview(&config, &plugins);

    let writer = CsvWriter::new(config.clone());
    println!("  {}", translations.get("generating").blue().bold());

    let output_path = if config.database_mode {
        writer.write_database_grid(&plugins, &mut recovery)?
    } else {
        writer.write_standard_csv(&plugins, &mut recovery)?
    };

    let duration = start_time.elapsed();
    println!("{}", "--------------------------------------------------------------------------------".cyan());
    println!("  {} - {} {:.3} seconds",
        translations.get("success").green().bold(),
        translations.get("completed").green(),
        duration.as_secs_f64());
    println!("{}", "================================================================================".cyan());
    println!();
    println!("  {} {}", translations.get("file_saved").green().bold(), output_path.display().to_string().bold());

    if recovery.has_fixes() {
        println!();
        println!("{}", "  ⚠ AUTOMATIC RECOVERY ACTIVATED".yellow().bold());
        recovery.print_summary();
    }

    println!();
    println!("  {} {}", "TIP".yellow().bold(), "You can open the CSV file in LibreOffice Calc or Excel.".yellow());
    Ok(())
}

fn print_banner(translations: &Translations) {
    println!("{}", "================================================================================".cyan());
    println!("  {}  |  Date: {}", translations.get("welcome").bold(), chrono::Local::now().format("%Y-%m-%d"));
    println!("{}", "================================================================================".cyan());
    println!("{}", "--------------------------------------------------------------------------------".cyan());
}

fn print_system_info(translations: &Translations) {
    println!("  {}", "[SYSTEM TELEMETRY]".blue().bold());
    println!("  Date/Time : {}", chrono::Local::now().format("%Y-%m-%d %H:%M:%S %Z"));
    println!("  Hostname  : {}", hostname::get().unwrap_or_default().to_string_lossy());
    println!("  OS        : {}", sys_info::os_release().unwrap_or_else(|_| "Unknown".to_string()));
    println!("  Language  : {}", translations.language().name());
    let total_mb = memory::get_total_memory_bytes() / 1024 / 1024;
    let avail_mb = memory::get_available_memory_bytes() / 1024 / 1024;
    println!("  RAM       : {} MB total, {} MB available", total_mb, avail_mb);
    println!("{}", "--------------------------------------------------------------------------------".cyan());
}

fn print_execution_preview(config: &Config, plugins: &[Box<dyn Plugin>]) {
    println!();
    println!("  {}", "--- EXECUTION PREVIEW ---".bold());
    println!("  Mode           : {}", if config.database_mode { "Password Database Grid".cyan() } else { "Standard CSV List".cyan() });
    println!("  Total Passwords: {}", config.count.to_string().cyan());
    println!("  Length         : {}", config.length.to_string().cyan());
    println!("  Charset        : {}", config.charset_language.name().cyan());
    println!("  UI Language    : {}", config.ui_language.name().cyan());
    if config.memory_first {
        println!("  Memory Mode    : {}", format!("MEMORY-FIRST ({}% RAM locked)", config.mem_percent).green().bold());
    }
    let mut style = String::new();
    if config.use_uppercase { style.push_str("Capitals "); }
    if config.use_numbers { style.push_str("Numbers "); }
    if config.use_symbols { style.push_str("Symbols "); }
    if config.use_lowercase { style.push_str("Lowers "); }
    println!("  Style          : {}", style.cyan());
    println!("  Randomness     : {}", if config.extreme_random {
        format!("Extreme (Deep Hashing {} iter)", config.extreme_iterations).cyan()
    } else { "Standard (CSPRNG)".cyan() });
    println!("  Output File    : {}", config.output_file.cyan());
    if !plugins.is_empty() {
        println!("  Plugins        : {}", plugins.iter().map(|p| p.name()).collect::<Vec<_>>().join(", ").cyan());
    }
    let est_time = if config.extreme_random {
        config.count * std::cmp::max(1, config.extreme_iterations / 10000) as usize
    } else {
        std::cmp::max(1, config.count / 10000)
    };
    println!("  Estimated Time : {}", format!("~{} seconds", est_time).yellow());
    println!("{}", "--------------------------------------------------------------------------------".cyan());
}

fn load_plugins(cli: &Cli) -> Vec<Box<dyn Plugin>> {
    let mut plugins: Vec<Box<dyn Plugin>> = Vec::new();
    if let Some(ref plugin_list) = cli.plugins {
        for plugin_name in plugin_list.split(',') {
            match plugin_name.trim().to_lowercase().as_str() {
                "uppercase" => {
                    println!("  {} Loading plugin: Uppercase Validator", "INFO".blue().bold());
                    plugins.push(Box::new(UppercaseValidator::new()));
                }
                "hyphen" => {
                    println!("  {} Loading plugin: Hyphen Formatter", "INFO".blue().bold());
                    plugins.push(Box::new(HyphenFormatter::new(4)));
                }
                other => {
                    println!("  {} Unknown plugin: {} (skipping)", "WARNING".yellow().bold(), other);
                }
            }
        }
    }
    plugins
}
MAIN_EOF

# sed: use crate::auto_recovery javitasa (az auto_recovery nem crate szintu)
sed -i 's|crate::auto_recovery::Severity|secure_passgen::auto_recovery::Severity|g' "$SRC/main.rs"

echo -e "  ${GREEN}main.rs frissitve${NC}"

# --- 7. Build ---
echo -e "${BOLD}Build...${NC}"
cargo build --release || { echo -e "${RED}HIBA: a build sikertelen${NC}"; exit 1; }

echo
echo -e "${GREEN}╔══════════════════════════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║${NC} ${BOLD}PATCH SIKERES - Memory-First mod elerheto!${NC}                 ${GREEN}║${NC}"
echo -e "${GREEN}╚══════════════════════════════════════════════════════════════╝${NC}"
echo
echo -e "Uj opciok:"
echo -e "  ${CYAN}--memory-first${NC}       RAM-diskre ir + mlockall aktivál"
echo -e "  ${CYAN}--mem-percent <N>${NC}    Hany %-a RAM-ot foglaja (1-95, alapertelmezett 90)"
echo
echo -e "${BOLD}Teszt (figyeld a RAM foglalas növekedését):${NC}"
echo -e "  sudo sh -c 'ulimit -l unlimited && $PROJECT_DIR/target/release/secure-passgen --memory-first -c -n -s -l 16 --count 500000 -o /dev/shm/mtest.csv'"
echo

# ===== END OF SCRIPT v1.0 - ha ez a sor hianyzik, a paste csonkolodott! =====
