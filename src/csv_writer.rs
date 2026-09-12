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
