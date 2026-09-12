//! Interactive mode - SSH-style prompts

use dialoguer::{theme::ColorfulTheme, Confirm, Input};
use colored::Colorize;
use crate::config::Config;

pub fn interactive_config(mut config: Config) -> Config {
    println!();
    println!("{}", "  --- INTERACTIVE PASSWORD DATABASE SETUP ---".bold());
    println!();
    
    let theme = ColorfulTheme::default();
    
    let length: usize = Input::with_theme(&theme)
        .with_prompt("  Enter password length")
        .default(8)
        .interact_text()
        .unwrap_or(8);
    config.length = length;
    
    config.use_uppercase = Confirm::with_theme(&theme)
        .with_prompt("  Include Capital Letters?")
        .default(false)
        .interact()
        .unwrap_or(false);
    
    config.use_numbers = Confirm::with_theme(&theme)
        .with_prompt("  Include Numbers?")
        .default(false)
        .interact()
        .unwrap_or(false);
    
    config.use_symbols = Confirm::with_theme(&theme)
        .with_prompt("  Include Symbols?")
        .default(false)
        .interact()
        .unwrap_or(false);
    
    config.extreme_random = Confirm::with_theme(&theme)
        .with_prompt("  Enable Extreme Randomness?")
        .default(false)
        .interact()
        .unwrap_or(false);
    
    if config.extreme_random {
        let iterations: u32 = Input::with_theme(&theme)
            .with_prompt("  Hash iterations (1000-1000000)")
            .default(10000)
            .interact_text()
            .unwrap_or(10000);
        config.extreme_iterations = iterations;
    }
    
    println!();
    config
}
