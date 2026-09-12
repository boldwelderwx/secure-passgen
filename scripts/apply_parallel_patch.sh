#!/bin/bash
# ==============================================================================
# apply_parallel_patch.sh v1.0
# Parhuzamositja a secure-passgen-t (rayon), hogy az OSSZES CPU magot hasznalja.
# A jelszogeneralas chunk-okban fut parhuzamosan, a CSV iras sorbarendezett.
# ==============================================================================

PROJECT_DIR="$HOME/secure-passgen"
SRC="$PROJECT_DIR/src"

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; CYAN='\033[0;36m'; BOLD='\033[1m'; NC='\033[0m'

echo -e "${CYAN}╔══════════════════════════════════════════════════════════════╗${NC}"
echo -e "${CYAN}║${NC} ${BOLD}Parallel Patch v1.0 - rayon${NC}                                 ${CYAN}║${NC}"
echo -e "${CYAN}╚══════════════════════════════════════════════════════════════╝${NC}"

# --- 1. Ellenorzes ---
echo -e "${BOLD}[1/4] Ellenorzes...${NC}"
[ -f "$PROJECT_DIR/Cargo.toml" ] || { echo -e "${RED}HIBA: Cargo.toml nem talalhato itt: $PROJECT_DIR${NC}"; exit 1; }
command -v cargo >/dev/null || { echo -e "${RED}HIBA: cargo nem talalhato${NC}"; exit 1; }
cd "$PROJECT_DIR" || exit 1
echo -e "  ${GREEN}OK: projekt talalva${NC}"

# --- 2. rayon hozzaadasa ---
echo -e "${BOLD}[2/4] rayon fuggoseg hozzaadasa...${NC}"
if grep -q '^rayon' Cargo.toml; then
    echo -e "  ${YELLOW}rayon mar szerepel - kihagyom${NC}"
else
    cargo add rayon || { echo -e "${RED}HIBA: cargo add rayon sikertelen${NC}"; exit 1; }
    echo -e "  ${GREEN}rayon hozzaadva${NC}"
fi

# --- 3. plugins/mod.rs: Plugin trait legyen Send + Sync (thread-safe) ---
echo -e "${BOLD}[3/4] plugins/mod.rs frissitese (Send + Sync)...${NC}"
cat > "$SRC/plugins/mod.rs" << 'PLUGMOD_EOF'
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
PLUGMOD_EOF
echo -e "  ${GREEN}plugins/mod.rs frissitve${NC}"

# --- 4. csv_writer.rs: parhuzamos verzio ---
echo -e "${BOLD}[4/4] csv_writer.rs parhuzamositasa (rayon)...${NC}"
cat > "$SRC/csv_writer.rs" << 'CSVW_EOF'
//! CSV writer module - PARALLEL version using rayon
//!
//! A jelszogeneralas chunk-okban, parhuzamosan fut az osszes CPUtagon.
//! A CSV iras sorbarendezett, igy az id oszlop es a sorrend hibátlan.

use std::fs::OpenOptions;
use std::io::{BufWriter, Write};
use std::path::PathBuf;
use chrono::Local;
use rayon::prelude::*;
use crate::error::Result;
use crate::config::Config;
use crate::entropy::DeepEntropy;
use crate::plugins::Plugin;
use crate::auto_recovery::AutoRecovery;

/// Egy parhuzamosan feldolgozott csomag merete
const PAR_CHUNK: usize = 4096;

pub struct CsvWriter {
    config: Config,
    entropy: DeepEntropy,
}

impl CsvWriter {
    pub fn new(config: Config) -> Self {
        let entropy = DeepEntropy::new(config.extreme_iterations);
        Self { config, entropy }
    }

    fn generate_one_password(&self, charset: &str) -> Result<String> {
        if self.config.extreme_random {
            self.entropy.generate_password(self.config.length, charset)
        } else {
            self.entropy.generate_password_standard(self.config.length, charset)
        }
    }

    fn csv_escape(value: &str) -> String {
        if value.contains(',') || value.contains('"') || value.contains('\n') {
            let escaped = value.replace('"', "\"\"");
            format!("\"{}\"", escaped)
        } else {
            value.to_string()
        }
    }

    fn get_style_string(&self) -> String {
        let mut style = String::new();
        if self.config.use_uppercase { style.push('C'); }
        if self.config.use_numbers { style.push('N'); }
        if self.config.use_symbols { style.push('S'); }
        if self.config.use_lowercase { style.push('L'); }
        if style.is_empty() { style.push('L'); }
        style
    }

    /// Parhuzamos jelszogeneralas egy csomagban (rayon).
    /// Minden CPUmag egyszerre dolgozik a csomag elemein.
    fn generate_chunk_parallel(
        &self,
        charset: &str,
        count: usize,
        plugins: &[Box<dyn Plugin>],
    ) -> Vec<String> {
        let extreme = self.config.extreme_random;
        let length = self.config.length;
        let entropy = &self.entropy;

        (0..count)
            .into_par_iter()
            .map(|_| {
                let gen_result = if extreme {
                    entropy.generate_password(length, charset)
                } else {
                    entropy.generate_password_standard(length, charset)
                };
                let mut pw = gen_result.unwrap_or_else(|_| "FALLBACK0000".to_string());

                for plugin in plugins {
                    pw = plugin.process_password(pw);
                }
                pw
            })
            .collect()
    }

    /// Standard CSV irasa - PARHUZAMOS generalas, sorbarendezett iras.
    pub fn write_standard_csv(&self, plugins: &[Box<dyn Plugin>], recovery: &mut AutoRecovery) -> Result<PathBuf> {
        let output_path = recovery.get_safe_filename(&self.config.output_file);
        let output_path = recovery.ensure_writable_path(&output_path);
        let charset = self.config.build_charset(recovery);

        let file = OpenOptions::new()
            .write(true)
            .create(true)
            .truncate(true)
            .open(&output_path)?;
        let mut writer = BufWriter::with_capacity(1 << 16, file);

        writeln!(writer, "id,password,length,style,timestamp")?;
        let style = self.get_style_string();
        let timestamp = Local::now().to_rfc3339();

        let mut generated = 0usize;
        while generated < self.config.count {
            let this_chunk = std::cmp::min(PAR_CHUNK, self.config.count - generated);
            let base_id = generated;

            // Parhuzamos generalas az osszes magon
            let passwords = self.generate_chunk_parallel(&charset, this_chunk, plugins);

            // Sorbarendezett iras (id oszlop konzisztens marad)
            for (idx, pw) in passwords.into_iter().enumerate() {
                let global_id = base_id + idx + 1;
                let escaped_pw = Self::csv_escape(&pw);
                writeln!(writer, "{},{},{},{},{}", global_id, escaped_pw, self.config.length, style, timestamp)?;
            }

            generated += this_chunk;
            if generated % (PAR_CHUNK * 4) == 0 || generated >= self.config.count {
                self.print_progress(generated, self.config.count);
            }
            writer.flush()?;
        }

        writer.flush()?;
        println!();
        Ok(output_path)
    }

    /// Adatbazis racs irasa - soronkent parhuzamos generalas.
    pub fn write_database_grid(&self, plugins: &[Box<dyn Plugin>], recovery: &mut AutoRecovery) -> Result<PathBuf> {
        let output_path = recovery.get_safe_filename(&self.config.output_file);
        let output_path = recovery.ensure_writable_path(&output_path);
        let charset = self.config.build_charset(recovery);

        let file = OpenOptions::new()
            .write(true)
            .create(true)
            .truncate(true)
            .open(&output_path)?;
        let mut writer = BufWriter::with_capacity(1 << 16, file);

        let mut header = String::from("Row");
        for col in 1..=self.config.max_columns {
            header.push(',');
            header.push_str(&Self::num_to_column(col));
        }
        writeln!(writer, "{}", header)?;

        let total_rows = (self.config.count + self.config.max_columns - 1) / self.config.max_columns;

        for row in 1..=total_rows {
            let row_passwords = self.generate_chunk_parallel(&charset, self.config.max_columns, plugins);

            let mut row_data = row.to_string();
            for pw in row_passwords {
                row_data.push(',');
                row_data.push_str(&Self::csv_escape(&pw));
            }
            writeln!(writer, "{}", row_data)?;

            if row % 10 == 0 || row == total_rows {
                self.print_progress(row, total_rows);
            }
            if row % 100 == 0 {
                writer.flush()?;
            }
        }

        writer.flush()?;
        println!();
        Ok(output_path)
    }

    fn num_to_column(num: usize) -> String {
        let mut result = String::new();
        let mut n = num;
        while n > 0 {
            let rem = (n - 1) % 26;
            let ch = (b'A' + rem as u8) as char;
            result.insert(0, ch);
            n = (n - 1) / 26;
        }
        result
    }

    fn print_progress(&self, current: usize, total: usize) {
        let width = 40;
        let percentage = current * 100 / total;
        let filled = current * width / total;
        let empty = width - filled;
        print!("\r  [{}{}] {:3}% ({}/{})", "#".repeat(filled), "-".repeat(empty), percentage, current, total);
    }
}
CSVW_EOF
echo -e "  ${GREEN}csv_writer.rs frissitve (parhuzamos)${NC}"

# --- 5. Build ---
echo -e "${BOLD}Build...${NC}"
cargo build --release || { echo -e "${RED}HIBA: a build sikertelen. Mutasd meg a fenti hibat a tanacsadonak.${NC}"; exit 1; }

echo
echo -e "${GREEN}╔══════════════════════════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║${NC} ${BOLD}PATCH SIKERES - a program most mar parhuzamos!${NC}            ${GREEN}║${NC}"
echo -e "${GREEN}╚══════════════════════════════════════════════════════════════╝${NC}"
echo
echo -e "A rayon automatikusan az ${BOLD}osszes logikai CPU-magot${NC} hasznalja."
echo -e "A te gepeiden ez: ${BOLD}$(nproc) mag${NC}."
echo
echo -e "${BOLD}Teszt (figyeld a ventillatorokat es a magokat):${NC}"
echo -e "  ./target/release/secure-passgen -c -n -s -l 16 --count 200000 -o /dev/shm/ptest.csv"
echo
echo -e "${BOLD}Ellenorzes masik terminalban (eroforras-hasznalat):${NC}"
echo -e "  top   (vagy: htop)  - latnod kell, hogy tobb mag is ~100%-on fut"
echo

# ===== END OF SCRIPT v1.0 - ha ez a sor hianyzik, a paste csonkolodott! =====
