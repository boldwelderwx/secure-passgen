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
            recovery.add_fix("Memory lock failed", msg, secure_passgen::auto_recovery::Severity::Warning);
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
