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
