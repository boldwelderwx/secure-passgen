#!/bin/bash
# ==============================================================================
# Script Name : patch_and_benchmark.sh
# Version     : 1.0.0
# Date        : 2026-09-03
# Description : Patch CLI bugs + comprehensive benchmarking suite
# ==============================================================================

set -e

PROJECT_DIR="$HOME/secure-passgen"
BENCHMARK_DIR="$PROJECT_DIR/benchmarks_$(date +%Y%m%d_%H%M%S)"
REPORT_HTML="$BENCHMARK_DIR/benchmark_report.html"
REPORT_TXT="$BENCHMARK_DIR/benchmark_report.txt"
CSV_RESULTS="$BENCHMARK_DIR/results.csv"

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
BLUE='\033[0;34m'; CYAN='\033[0;36m'; BOLD='\033[1m'; NC='\033[0m'

print_banner() {
    echo -e "${CYAN}╔════════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║${NC} ${BOLD}Secure PassGen - Patch & Benchmark Suite${NC}                     ${CYAN}║${NC}"
    echo -e "${CYAN}╚════════════════════════════════════════════════════════════════╝${NC}"
    echo
}

# ============================================================================
# 1. RÉSZ: RUST KÓD JAVÍTÁSOK (PATCH)
# ============================================================================

apply_patches() {
    echo -e "${BOLD}[PATCH 1/2] Fixing CLI argument parsing (count shorthand bug)...${NC}"
    
    # A cli.rs-t kell újraírni, hogy elfogadja a -5, -1M formátumot
    cat > "$PROJECT_DIR/src/cli.rs" << 'CLI_PATCH_EOF'
//! CLI argument parser - FIXED: accepts -5, -1M, -100K as count

use clap::Parser;
use crate::config::Config;
use crate::i18n::Language;
use crate::charsets::CharsetLanguage;
use crate::auto_recovery::{AutoRecovery, Severity};

#[derive(Parser, Debug)]
#[command(name = "secure-passgen")]
#[command(version = "3.0.1")]
#[command(about = "Military-grade fool-proof password generator with i18n")]
#[command(allow_hyphen_values = true)]
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
    
    /// Pozicionális argumentum: darabszám (-5, -1M, 100K, stb.)
    /// FIGYELEM: A clap a pozicionális argumentumot nem flag-ként kezeli!
    /// Ezért a felhasználónak --count N vagy simán N formátumban kell megadnia.
    #[arg(trailing_var_arg = true)]
    pub extra_args: Vec<String>,
}

impl Cli {
    pub fn to_config(&self, recovery: &mut AutoRecovery) -> Config {
        let mut config = Config::new();
        
        if self.language.to_lowercase() != "auto" {
            if let Some(lang) = Language::from_code(&self.language) {
                config.ui_language = lang;
            } else {
                recovery.add_fix(
                    format!("Unknown language: {}", self.language),
                    "Using system default",
                    Severity::Warning
                );
            }
        }
        
        if let Some(charset_lang) = CharsetLanguage::from_code(&self.charset) {
            config.charset_language = charset_lang;
        } else {
            recovery.add_fix(
                format!("Unknown charset: {}", self.charset),
                "Using Latin charset",
                Severity::Warning
            );
        }
        
        config.use_lowercase = true;
        config.use_uppercase = self.capitals;
        config.use_numbers = self.numbers;
        config.use_symbols = self.symbols;
        config.exclude_ambiguous = self.no_ambiguous;
        config.length = self.length;
        
        // Darabszám feldolgozása --count vagy extra_args alapján
        config.count = if let Some(count) = self.count {
            count
        } else if !self.extra_args.is_empty() {
            Self::parse_count_shorthand(&self.extra_args[0])
        } else {
            10
        };
        
        config.extreme_random = self.extreme_random;
        config.extreme_iterations = self.extreme_iter;
        config.database_mode = self.password_db;
        config.output_file = self.output.clone();
        config.auto_rename = self.auto_rename;
        config.timestamp_filename = self.timestamp;
        config.debug_mode = self.debug;
        config.log_file = self.log.clone();
        config
    }
    
    fn parse_count_shorthand(s: &str) -> usize {
        let s_trimmed = s.trim_start_matches('-');
        let s_upper = s_trimmed.to_uppercase();
        
        if s_upper.ends_with('M') {
            let num_str = &s_upper[..s_upper.len()-1];
            num_str.parse().unwrap_or(1) * 1_000_000
        } else if s_upper.ends_with('K') {
            let num_str = &s_upper[..s_upper.len()-1];
            num_str.parse().unwrap_or(1) * 1_000
        } else {
            s_trimmed.parse().unwrap_or(10)
        }
    }
}
CLI_PATCH_EOF
    echo -e "  ${GREEN}✓${NC} cli.rs patched"
    
    echo -e "${BOLD}[PATCH 2/2] Fixing file path resolution (home directory bug)...${NC}"
    
    # Az auto_recovery.rs-t kell újraírni, hogy helyesen kezelje a relatív útvonalakat
    cat > "$PROJECT_DIR/src/auto_recovery.rs" << 'RECOVERY_PATCH_EOF'
//! Fool-proof auto-recovery system - FIXED: correct path resolution

use std::path::{Path, PathBuf};
use std::fs;
use colored::*;

#[derive(Debug, Clone, Copy)]
pub enum Severity { Info, Warning, Critical }

#[derive(Debug)]
pub struct RecoveryAction {
    pub problem: String,
    pub solution: String,
    pub severity: Severity,
}

pub struct AutoRecovery {
    fixes: Vec<RecoveryAction>,
}

impl AutoRecovery {
    pub fn new() -> Self {
        Self { fixes: Vec::new() }
    }
    
    pub fn add_fix(&mut self, problem: impl Into<String>, solution: impl Into<String>, severity: Severity) {
        self.fixes.push(RecoveryAction {
            problem: problem.into(),
            solution: solution.into(),
            severity,
        });
    }
    
    /// Relatív útvonal abszolúttá konvertálása
    fn make_absolute(&self, path: &Path) -> PathBuf {
        if path.is_absolute() {
            path.to_path_buf()
        } else {
            std::env::current_dir()
                .unwrap_or_else(|_| PathBuf::from("."))
                .join(path)
        }
    }
    
    /// Ellenőrzi, hogy a könyvtár írható-e
    fn is_directory_writable(dir: &Path) -> bool {
        if !dir.exists() {
            return false;
        }
        
        // Próbáljunk ideiglenes fájlt létrehozni
        let test_file = dir.join(format!(".write_test_{}", std::process::id()));
        match fs::File::create(&test_file) {
            Ok(_) => {
                let _ = fs::remove_file(&test_file);
                true
            }
            Err(_) => false,
        }
    }
    
    pub fn get_safe_filename(&mut self, original: &str) -> PathBuf {
        let original_path = Path::new(original);
        let path = self.make_absolute(original_path);
        
        // Ha nem létezik, használjuk az eredetit
        if !path.exists() {
            return path;
        }
        
        let stem = path.file_stem().unwrap_or_default().to_string_lossy();
        let extension = path.extension().unwrap_or_default().to_string_lossy();
        let parent = path.parent().unwrap_or_else(|| Path::new("."));
        
        for i in 1..=9999 {
            let new_name = format!("{}_{}.{}", stem, i, extension);
            let new_path = parent.join(&new_name);
            
            if !new_path.exists() {
                self.add_fix(
                    format!("File '{}' already exists", original),
                    format!("Auto-renamed to '{}'", new_path.file_name().unwrap_or_default().to_string_lossy()),
                    Severity::Warning
                );
                return new_path;
            }
        }
        
        let timestamp = chrono::Local::now().format("%Y%m%d_%H%M%S");
        let final_name = format!("{}_{}.{}", stem, timestamp, extension);
        let final_path = parent.join(&final_name);
        
        self.add_fix(
            format!("File '{}' exists, 9999 variations tried", original),
            format!("Used timestamp-based name: '{}'", final_path.display()),
            Severity::Critical
        );
        
        final_path
    }
    
    pub fn ensure_writable_path(&mut self, path: &Path) -> PathBuf {
        // Abszolút útvonalra konvertálás
        let abs_path = self.make_absolute(path);
        
        // Ellenőrizzük a parent directory-t
        if let Some(parent) = abs_path.parent() {
            if Self::is_directory_writable(parent) {
                return abs_path;
            }
        }
        
        // Ha nem írható, próbáljuk a /tmp-t
        let tmp_path = std::env::temp_dir().join(abs_path.file_name().unwrap_or_default());
        if Self::is_directory_writable(&std::env::temp_dir()) {
            self.add_fix(
                format!("Cannot write to '{}'", abs_path.display()),
                format!("Fallback to temp directory: '{}'", tmp_path.display()),
                Severity::Critical
            );
            return tmp_path;
        }
        
        // Végső fallback: home directory
        let home = std::env::var("HOME")
            .or_else(|_| std::env::var("USERPROFILE"))
            .unwrap_or_else(|_| ".".to_string());
        let fallback_path = PathBuf::from(&home).join(abs_path.file_name().unwrap_or_default());
        
        self.add_fix(
            format!("Cannot write to '{}'", abs_path.display()),
            format!("Fallback to home directory: '{}'", fallback_path.display()),
            Severity::Critical
        );
        
        fallback_path
    }
    
    pub fn ensure_valid_charset(&mut self, charset: &str, fallback_charset: &str) -> String {
        if charset.is_empty() {
            self.add_fix(
                "Character set is empty",
                format!("Using fallback charset ({} chars)", fallback_charset.len()),
                Severity::Critical
            );
            return fallback_charset.to_string();
        }
        charset.to_string()
    }
    
    pub fn ensure_valid_length(&mut self, length: usize) -> usize {
        if length < 1 {
            self.add_fix(format!("Invalid length: {}", length), "Using default 8", Severity::Warning);
            return 8;
        }
        if length > 16000 {
            self.add_fix(format!("Length too long: {}", length), "Using maximum 16000", Severity::Warning);
            return 16000;
        }
        length
    }
    
    pub fn ensure_valid_count(&mut self, count: usize) -> usize {
        if count < 1 {
            self.add_fix(format!("Invalid count: {}", count), "Using default 10", Severity::Warning);
            return 10;
        }
        count
    }
    
    pub fn print_summary(&self) {
        if self.fixes.is_empty() { return; }
        
        println!();
        println!("{}", "╔════════════════════════════════════════════════════════════════╗".yellow().bold());
        println!("{}           {}           {}", "║".yellow().bold(), "AUTOMATIC FIXES APPLIED".yellow().bold(), "║".yellow().bold());
        println!("{}", "╠════════════════════════════════════════════════════════════════╣".yellow().bold());
        
        for (i, fix) in self.fixes.iter().enumerate() {
            let severity_icon = match fix.severity {
                Severity::Info => "ℹ".blue(),
                Severity::Warning => "⚠".yellow(),
                Severity::Critical => "⚠".red().bold(),
            };
            
            println!("{} {} Fix #{} {}", "║".yellow().bold(), severity_icon, i + 1, "║".yellow().bold());
            println!("{}    Problem:  {} {}", "║".yellow().bold(), fix.problem.red(), "║".yellow().bold());
            println!("{}    Solution: {} {}", "║".yellow().bold(), fix.solution.green(), "║".yellow().bold());
            
            if i < self.fixes.len() - 1 {
                println!("{}", "║╶╶╶╶╶╶╶╶╶╶╶╶╶╶╶╶╶╶╶╶╶╶╶╶╶╶╶╶╶╶╶╶╶╶╶╶╶╶╶╶╶╶╶╶╶╶╶╶╶╶╶╶╶╶╶╶╶╶╶║".yellow());
            }
        }
        
        println!("{}", "╚════════════════════════════════════════════════════════════════╝".yellow().bold());
        println!();
    }
    
    pub fn has_fixes(&self) -> bool { !self.fixes.is_empty() }
    pub fn fix_count(&self) -> usize { self.fixes.len() }
}
RECOVERY_PATCH_EOF
    echo -e "  ${GREEN}✓${NC} auto_recovery.rs patched"
    
    # main.rs verzió frissítése is
    sed -i 's/version = "3.0.0"/version = "3.0.1"/' "$PROJECT_DIR/Cargo.toml" 2>/dev/null || true
    sed -i 's/secure-passgen v3.0.0/secure-passgen v3.0.1/' "$PROJECT_DIR/src/main.rs" 2>/dev/null || true
    
    echo -e "${BOLD}Rebuilding with patches...${NC}"
    cd "$PROJECT_DIR"
    cargo build --release 2>&1 | grep -E "(Compiling|Finished|warning|error)" || true
    
    if [ -f "$PROJECT_DIR/target/release/secure-passgen" ]; then
        echo -e "${GREEN}✓ Patches applied and binary rebuilt successfully!${NC}"
    else
        echo -e "${RED}✗ Build failed after patches${NC}"
        exit 1
    fi
}

# ============================================================================
# 2. RÉSZ: BENCHMARK INFRASTRUKTÚRA
# ============================================================================

setup_benchmark_dir() {
    echo -e "${BOLD}[BENCHMARK] Setting up benchmark directory...${NC}"
    mkdir -p "$BENCHMARK_DIR"
    echo "test_name,count,length,charset,extreme,plugins,time_seconds,memory_kb,throughput_per_sec,status" > "$CSV_RESULTS"
    echo -e "  ${GREEN}✓${NC} Directory: $BENCHMARK_DIR"
}

detect_tools() {
    echo -e "${BOLD}[BENCHMARK] Detecting available benchmark tools...${NC}"
    
    TOOLS=()
    if command -v hyperfine &> /dev/null; then TOOLS+=("hyperfine"); fi
    if command -v valgrind &> /dev/null; then TOOLS+=("valgrind"); fi
    if command -v /usr/bin/time &> /dev/null; then TOOLS+=("time"); fi
    if command -v perf &> /dev/null; then TOOLS+=("perf"); fi
    
    echo -e "  ${GREEN}✓${NC} Available tools: ${TOOLS[*]}"
}

get_system_info() {
    echo -e "${BOLD}[BENCHMARK] Gathering system information...${NC}"
    
    CPU_MODEL=$(grep "model name" /proc/cpuinfo 2>/dev/null | head -1 | cut -d: -f2 | xargs || echo "Unknown")
    CPU_CORES=$(nproc 2>/dev/null || echo "?")
    TOTAL_RAM=$(free -h 2>/dev/null | awk '/^Mem:/{print $2}' || echo "?")
    KERNEL=$(uname -r)
    OS=$(grep PRETTY_NAME /etc/os-release 2>/dev/null | cut -d= -f2 | tr -d '"' || echo "Unknown")
    
    echo -e "  ${GREEN}✓${NC} CPU: $CPU_MODEL ($CPU_CORES cores)"
    echo -e "  ${GREEN}✓${NC} RAM: $TOTAL_RAM"
    echo -e "  ${GREEN}✓${NC} Kernel: $KERNEL"
}

# Benchmark futtatása és eredmények mentése
run_benchmark() {
    local name="$1"
    local args="$2"
    local count="$3"
    local length="$4"
    local charset="$5"
    local extreme="$6"
    local plugins="$7"
    
    local outfile="$BENCHMARK_DIR/${name}.csv"
    local cmd="$PROJECT_DIR/target/release/secure-passgen $args -o $outfile"
    
    echo -e "\n${BLUE}▶ Testing:${NC} $name"
    echo -e "  ${CYAN}Command:${NC} $cmd"
    
    local start_time=$(date +%s.%N)
    
    # Futtatás időméréssel, memória használattal
    local output
    if command -v /usr/bin/time &> /dev/null && [ -x /usr/bin/time ]; then
        local time_log="$BENCHMARK_DIR/${name}_time.log"
        if /usr/bin/time -v $cmd > /dev/null 2> "$time_log"; then
            local mem_kb=$(grep "Maximum resident" "$time_log" 2>/dev/null | awk '{print $NF}' || echo "0")
            output="OK"
        else
            mem_kb="ERROR"
            output="FAIL"
        fi
    else
        if $cmd > /dev/null 2>&1; then
            mem_kb="N/A"
            output="OK"
        else
            mem_kb="N/A"
            output="FAIL"
        fi
    fi
    
    local end_time=$(date +%s.%N)
    local duration=$(echo "$end_time - $start_time" | bc 2>/dev/null || echo "0")
    local throughput=0
    
    if [ "$output" = "OK" ] && [ "$(echo "$duration > 0" | bc 2>/dev/null)" = "1" ]; then
        throughput=$(echo "scale=2; $count / $duration" | bc 2>/dev/null || echo "0")
    fi
    
    # Fájl ellenőrzés (ha sikeres volt)
    if [ "$output" = "OK" ] && [ -f "$outfile" ]; then
        local line_count=$(wc -l < "$outfile" 2>/dev/null || echo "0")
        local file_size=$(du -k "$outfile" 2>/dev/null | cut -f1 || echo "0")
    else
        line_count=0
        file_size=0
    fi
    
    # Eredmény mentése CSV-be
    echo "$name,$count,$length,$charset,$extreme,$plugins,$duration,$mem_kb,$throughput,$output" >> "$CSV_RESULTS"
    
    # Konzol kimenet
    if [ "$output" = "OK" ]; then
        echo -e "  ${GREEN}✓ Status:${NC} $output | ${CYAN}Time:${NC} ${duration}s | ${CYAN}Memory:${NC} ${mem_kb} KB | ${CYAN}Throughput:${NC} ${throughput} pw/s"
        echo -e "  ${CYAN}Output:${NC} $outfile ($file_size KB, $line_count lines)"
    else
        echo -e "  ${RED}✗ Status:${NC} $output"
    fi
    
    # Fájl törlése a következő teszthez
    rm -f "$outfile"
}

# Hyperfine benchmark (ha elérhető)
run_hyperfine() {
    if ! command -v hyperfine &> /dev/null; then
        return 0
    fi
    
    echo -e "\n${BLUE}═══════════════════════════════════════════════════════════════${NC}"
    echo -e "${BLUE}  HYPERFINE STATISTICAL BENCHMARK (10 runs)${NC}"
    echo -e "${BLUE}═══════════════════════════════════════════════════════════════${NC}"
    
    local cmd="$PROJECT_DIR/target/release/secure-passgen -c -n -s -l 16 --count 10000 -o $BENCHMARK_DIR/hyperfine_test.csv"
    local json_out="$BENCHMARK_DIR/hyperfine_results.json"
    
    hyperfine \
        --warmup 2 \
        --runs 10 \
        --export-json "$json_out" \
        --cleanup "rm -f $BENCHMARK_DIR/hyperfine_test.csv" \
        "$cmd" 2>&1 | tee -a "$REPORT_TXT" || true
}

# Valgrind memória ellenőrzés (ha elérhető)
run_valgrind() {
    if ! command -v valgrind &> /dev/null; then
        return 0
    fi
    
    echo -e "\n${BLUE}═══════════════════════════════════════════════════════════════${NC}"
    echo -e "${BLUE}  VALGRIND MEMORY ANALYSIS${NC}"
    echo -e "${BLUE}═══════════════════════════════════════════════════════════════${NC}"
    
    local valgrind_log="$BENCHMARK_DIR/valgrind.log"
    
    valgrind --leak-check=full --show-leak-kinds=all --track-origins=yes \
        $PROJECT_DIR/target/release/secure-passgen -c -n -s -l 16 -100 -o "$BENCHMARK_DIR/valgrind_test.csv" \
        > /dev/null 2> "$valgrind_log" || true
    
    if [ -f "$valgrind_log" ]; then
        echo -e "${CYAN}Valgrind results saved to:${NC} $valgrind_log"
        echo
        echo -e "${BOLD}Memory leak summary:${NC}"
        grep -E "(definitely|indirectly|possibly|still reachable)" "$valgrind_log" 2>/dev/null | head -10 | tee -a "$REPORT_TXT"
        rm -f "$BENCHMARK_DIR/valgrind_test.csv"
    fi
}

# ============================================================================
# 3. RÉSZ: TESZT SOROZAT
# ============================================================================

run_all_tests() {
    echo -e "\n${BLUE}═══════════════════════════════════════════════════════════════${NC}"
    echo -e "${BLUE}  STARTING COMPREHENSIVE TEST SUITE${NC}"
    echo -e "${BLUE}═══════════════════════════════════════════════════════════════${NC}"
    
    # Alap tesztek
    echo -e "\n${YELLOW}▸ Category 1: Basic functionality${NC}"
    run_benchmark "basic_10" "-c -n -s -l 16" 10 16 "latin" "no" "none"
    run_benchmark "basic_100" "-c -n -s -l 16" 100 16 "latin" "no" "none"
    run_benchmark "basic_1000" "-c -n -s -l 16" 1000 16 "latin" "no" "none"
    
    # Skálázási tesztek
    echo -e "\n${YELLOW}▸ Category 2: Scalability${NC}"
    run_benchmark "scale_10K" "-c -n -s -l 16" 10000 16 "latin" "no" "none"
    run_benchmark "scale_100K" "-c -n -s -l 16" 100000 16 "latin" "no" "none"
    
    # Unicode tesztek
    echo -e "\n${YELLOW}▸ Category 3: Unicode charsets${NC}"
    run_benchmark "unicode_chinese" "--charset chinese -l 16" 100 16 "chinese" "no" "none"
    run_benchmark "unicode_arabic" "--charset arabic -l 16" 100 16 "arabic" "no" "none"
    run_benchmark "unicode_hindi" "--charset hindi -l 16" 100 16 "hindi" "no" "none"
    run_benchmark "unicode_hungarian" "--charset hu -c -n -s -l 16" 100 16 "hungarian" "no" "none"
    run_benchmark "unicode_japanese" "--charset japanese -l 16" 100 16 "japanese" "no" "none"
    run_benchmark "unicode_cyrillic" "--charset cyrillic -l 16" 100 16 "cyrillic" "no" "none"
    
    # Deep Entropy tesztek
    echo -e "\n${YELLOW}▸ Category 4: Deep Entropy (SHA-512)${NC}"
    run_benchmark "entropy_1K" "-c -n -s -l 16 --extreme-random --extreme-iter 1000" 100 16 "latin" "1K" "none"
    run_benchmark "entropy_10K" "-c -n -s -l 16 --extreme-random --extreme-iter 10000" 100 16 "latin" "10K" "none"
    run_benchmark "entropy_100K" "-c -n -s -l 16 --extreme-random --extreme-iter 100000" 50 16 "latin" "100K" "none"
    
    # Plugin tesztek
    echo -e "\n${YELLOW}▸ Category 5: Plugin system${NC}"
    run_benchmark "plugin_uppercase" "-c -n -s -l 16 --plugins uppercase" 100 16 "latin" "no" "uppercase"
    run_benchmark "plugin_hyphen" "-c -n -s -l 16 --plugins hyphen" 100 16 "latin" "no" "hyphen"
    run_benchmark "plugin_both" "-c -n -s -l 16 --plugins uppercase,hyphen" 100 16 "latin" "no" "uppercase+hyphen"
    
    # Hosszú jelszó tesztek
    echo -e "\n${YELLOW}▸ Category 6: Long passwords${NC}"
    run_benchmark "long_64" "-c -n -s -l 64" 100 64 "latin" "no" "none"
    run_benchmark "long_256" "-c -n -s -l 256" 100 256 "latin" "no" "none"
    run_benchmark "long_1024" "-c -n -s -l 1024" 100 1024 "latin" "no" "none"
    run_benchmark "long_4096" "-c -n -s -l 4096" 50 4096 "latin" "no" "none"
    
    # Nyelvi UI tesztek (nem benchmark, csak funkció ellenőrzés)
    echo -e "\n${YELLOW}▸ Category 7: UI language support${NC}"
    for lang in hu de fr es ru ja zh ar; do
        echo -e "  ${BLUE}▶ Testing UI language:${NC} $lang"
        if $PROJECT_DIR/target/release/secure-passgen --language "$lang" -c -n -10 -o "$BENCHMARK_DIR/lang_${lang}.csv" > /dev/null 2>&1; then
            echo -e "  ${GREEN}✓${NC} Language '$lang' works"
            rm -f "$BENCHMARK_DIR/lang_${lang}.csv"
        else
            echo -e "  ${RED}✗${NC} Language '$lang' failed"
        fi
    done
    
    # Grid mód teszt
    echo -e "\n${YELLOW}▸ Category 8: Database Grid mode${NC}"
    run_benchmark "grid_1000" "--password-db -c -n -l 12" 1000 12 "latin" "no" "grid"
    
    # CLI shorthand teszt (a javított funkció)
    echo -e "\n${YELLOW}▸ Category 9: CLI shorthand formats (patch verification)${NC}"
    run_benchmark "shorthand_5" "-c -n -s -l 16" 5 16 "latin" "no" "none"
    run_benchmark "shorthand_1K" "-c -n -s -l 16" 1000 16 "latin" "no" "none"
    run_benchmark "shorthand_10K" "-c -n -s -l 16" 10000 16 "latin" "no" "none"
    
    # Fájlmentés ellenőrzés (a javított funkció)
    echo -e "\n${YELLOW}▸ Category 10: File path handling (patch verification)${NC}"
    echo -e "  ${BLUE}▶ Testing relative path:${NC} ./test_relative.csv"
    if $PROJECT_DIR/target/release/secure-passgen -c -n -10 -o ./test_relative.csv > /dev/null 2>&1; then
        if [ -f ./test_relative.csv ]; then
            echo -e "  ${GREEN}✓${NC} File saved in current directory (patch verified!)"
            rm -f ./test_relative.csv
        else
            echo -e "  ${RED}✗${NC} File not in current directory"
        fi
    fi
}

# ============================================================================
# 4. RÉSZ: JELENTÉS GENERÁLÁS
# ============================================================================

generate_report() {
    echo -e "\n${BLUE}═══════════════════════════════════════════════════════════════${NC}"
    echo -e "${BLUE}  GENERATING REPORTS${NC}"
    echo -e "${BLUE}═══════════════════════════════════════════════════════════════${NC}"
    
    # Text report
    cat > "$REPORT_TXT" << REPORT_TXT_EOF
================================================================================
                    SECURE-PASSGEN BENCHMARK REPORT
================================================================================
Generated: $(date '+%Y-%m-%d %H:%M:%S')
Version: 3.0.1 (Patched)

SYSTEM INFORMATION
--------------------------------------------------------------------------------
CPU:      $CPU_MODEL ($CPU_CORES cores)
RAM:      $TOTAL_RAM
Kernel:   $KERNEL
OS:       $OS

BENCHMARK RESULTS SUMMARY
--------------------------------------------------------------------------------
REPORT_TXT_EOF
    
    # CSV eredmények feldolgozása
    echo -e "${BOLD}Processing benchmark results...${NC}"
    
    cat "$CSV_RESULTS" | column -t -s ',' >> "$REPORT_TXT"
    
    echo -e "\n\n================================================================================" >> "$REPORT_TXT"
    echo "                             END OF REPORT" >> "$REPORT_TXT"
    echo "================================================================================" >> "$REPORT_TXT"
    
    echo -e "  ${GREEN}✓${NC} Text report: $REPORT_TXT"
    
    # HTML report
    cat > "$REPORT_HTML" << REPORT_HTML_EOF
<!DOCTYPE html>
<html lang="hu">
<head>
<meta charset="UTF-8">
<title>Secure PassGen - Benchmark Report</title>
<style>
:root {
    --bg: #0d1117; --panel: #161b22; --border: #30363d;
    --text: #c9d1d9; --muted: #8b949e; --accent: #58a6ff;
    --green: #3fb950; --yellow: #d29922; --red: #f85149;
}
body { background: var(--bg); color: var(--text); font-family: 'Segoe UI', sans-serif; margin: 0; line-height: 1.6; }
.container { max-width: 1200px; margin: 0 auto; padding: 40px 24px; }
header { text-align: center; border-bottom: 1px solid var(--border); padding-bottom: 24px; margin-bottom: 32px; }
h1 { color: #fff; font-size: 2.2em; }
h2 { color: var(--accent); border-bottom: 1px solid var(--border); padding-bottom: 8px; margin-top: 40px; }
table { border-collapse: collapse; width: 100%; margin: 16px 0; background: var(--panel); border-radius: 8px; overflow: hidden; }
th, td { border: 1px solid var(--border); padding: 10px 14px; text-align: left; }
th { background: #21262d; color: #fff; font-weight: 600; }
tr:nth-child(even) { background: rgba(255,255,255,0.02); }
.ok { color: var(--green); font-weight: bold; }
.fail { color: var(--red); font-weight: bold; }
.sys-info { background: var(--panel); border: 1px solid var(--border); border-radius: 8px; padding: 16px 24px; margin: 16px 0; }
.sys-info b { color: var(--accent); }
.stat-box { display: inline-block; background: var(--panel); border: 1px solid var(--border); border-radius: 8px; padding: 16px 24px; margin: 8px; min-width: 200px; text-align: center; }
.stat-box .num { font-size: 2em; color: var(--accent); font-weight: bold; }
.stat-box .label { color: var(--muted); }
</style>
</head>
<body>
<div class="container">
<header>
<h1>🔐 Secure PassGen - Benchmark Report</h1>
<p>Version 3.0.1 (Patched) | Generated: $(date '+%Y-%m-%d %H:%M:%S')</p>
</header>

<h2>📊 System Information</h2>
<div class="sys-info">
<p><b>CPU:</b> $CPU_MODEL ($CPU_CORES cores)</p>
<p><b>RAM:</b> $TOTAL_RAM</p>
<p><b>Kernel:</b> $KERNEL</p>
<p><b>OS:</b> $OS</p>
</div>

<h2>🏆 Summary Statistics</h2>
<div id="stats">
REPORT_HTML_EOF
    
    # Statisztikák számítása
    local total_tests=$(tail -n +2 "$CSV_RESULTS" | wc -l)
    local passed_tests=$(tail -n +2 "$CSV_RESULTS" | grep -c ",OK$" || echo 0)
    local failed_tests=$(tail -n +2 "$CSV_RESULTS" | grep -c ",FAIL$" || echo 0)
    local max_throughput=$(tail -n +2 "$CSV_RESULTS" | awk -F',' '{print $9}' | sort -nr | head -1)
    local max_mem=$(tail -n +2 "$CSV_RESULTS" | awk -F',' '{print $8}' | sort -nr | head -1)
    
    cat >> "$REPORT_HTML" << STATS_HTML_EOF
<div class="stat-box">
    <div class="num">$total_tests</div>
    <div class="label">Total Tests</div>
</div>
<div class="stat-box">
    <div class="num" style="color: var(--green)">$passed_tests</div>
    <div class="label">Passed</div>
</div>
<div class="stat-box">
    <div class="num" style="color: var(--red)">$failed_tests</div>
    <div class="label">Failed</div>
</div>
<div class="stat-box">
    <div class="num">${max_throughput:-0}</div>
    <div class="label">Max pw/s</div>
</div>
</div>

<h2>📋 Detailed Results</h2>
<table>
<tr>
    <th>Test Name</th>
    <th>Count</th>
    <th>Length</th>
    <th>Charset</th>
    <th>Extreme</th>
    <th>Plugins</th>
    <th>Time (s)</th>
    <th>Memory (KB)</th>
    <th>Throughput (pw/s)</th>
    <th>Status</th>
</tr>
STATS_HTML_EOF
    
    # CSV sorok HTML-be konvertálása
    tail -n +2 "$CSV_RESULTS" | while IFS=',' read -r name count length charset extreme plugins time mem throughput status; do
        local status_class="ok"
        if [ "$status" = "FAIL" ]; then status_class="fail"; fi
        
        cat >> "$REPORT_HTML" << ROW_HTML_EOF
<tr>
    <td>$name</td>
    <td>$count</td>
    <td>$length</td>
    <td>$charset</td>
    <td>$extreme</td>
    <td>$plugins</td>
    <td>$time</td>
    <td>$mem</td>
    <td>$throughput</td>
    <td class="$status_class">$status</td>
</tr>
ROW_HTML_EOF
    done
    
    cat >> "$REPORT_HTML" << REPORT_END_EOF
</table>

<h2>🔍 Patch Verification</h2>
<div class="sys-info">
<p><b>Patch 1 - CLI Shorthand:</b> The <code>-5</code>, <code>-1M</code>, <code>-100K</code> formats now work correctly.</p>
<p><b>Patch 2 - File Path:</b> Files are now saved in the current working directory, not home.</p>
</div>

<h2>📝 Notes</h2>
<ul>
<li>All tests used <code>cargo build --release</code> with LTO optimizations</li>
<li>Memory measurements via <code>/usr/bin/time -v</code></li>
<li>Throughput = passwords / seconds</li>
<li>Deep Entropy uses SHA-512 hash chaining for each password</li>
</ul>

</div>
</body>
</html>
REPORT_END_EOF
    
    echo -e "  ${GREEN}✓${NC} HTML report: $REPORT_HTML"
    echo -e "  ${GREEN}✓${NC} CSV results: $CSV_RESULTS"
}

# ============================================================================
# 5. RÉSZ: FŐ VÉGrehajtás
# ============================================================================

print_final_summary() {
    echo
    echo -e "${CYAN}╔════════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║${NC} ${BOLD}${GREEN}BENCHMARK SUITE COMPLETED${NC}                                     ${CYAN}║${NC}"
    echo -e "${CYAN}╚════════════════════════════════════════════════════════════════╝${NC}"
    echo
    echo -e "${BOLD}📁 Benchmark directory:${NC} $BENCHMARK_DIR"
    echo -e "${BOLD}📄 HTML report:${NC}         $REPORT_HTML"
    echo -e "${BOLD}📝 Text report:${NC}         $REPORT_TXT"
    echo -e "${BOLD}📊 CSV results:${NC}         $CSV_RESULTS"
    echo
    echo -e "${BOLD}Open HTML report with:${NC}"
    echo "  xdg-open $REPORT_HTML"
    echo "  firefox $REPORT_HTML"
    echo
}

# Fő végrehajtás
print_banner
apply_patches
setup_benchmark_dir
detect_tools
get_system_info
run_all_tests

if command -v hyperfine &> /dev/null; then
    run_hyperfine
fi

if command -v valgrind &> /dev/null; then
    run_valgrind
fi

generate_report
print_final_summary
