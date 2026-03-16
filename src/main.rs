mod blocker;
mod cli;
mod config;
mod display;
mod privilege;
mod schedule;
mod state;
mod tamper;
mod tools;
mod wizard;

use anyhow::Result;
use clap::Parser;
use colored::Colorize;

use cli::{Cli, Commands};

fn main() -> Result<()> {
    let cli = Cli::parse();

    match cli.command {
        None => cmd_default()?,
        Some(Commands::On) => cmd_on()?,
        Some(Commands::Off) => cmd_off()?,
        Some(Commands::Status) => cmd_status()?,
        Some(Commands::Config) => cmd_config()?,
    }

    Ok(())
}

fn cmd_default() -> Result<()> {
    match config::load_config()? {
        Some(config) => show_status(&config),
        None => run_setup(),
    }
}

fn cmd_on() -> Result<()> {
    privilege::require_root()?;
    let config = require_config()?;
    blocker::activate(&config)
}

fn cmd_off() -> Result<()> {
    privilege::require_root()?;
    let config = require_config()?;
    blocker::deactivate(&config)
}

fn cmd_status() -> Result<()> {
    let config = require_config()?;
    show_status(&config)
}

fn cmd_config() -> Result<()> {
    let existing = config::load_config()?;

    // In extreme mode, refuse to reconfigure while active
    if let Some(ref cfg) = existing {
        if cfg.mode.extreme {
            let st = state::load_state()?;
            if st.active {
                println!();
                display::print_error(
                    "Cannot reconfigure in extreme mode while blocking is active.",
                );
                println!(
                    "  {}\n",
                    "Wait for your scheduled blocking time to end, then run `chisel off` first."
                        .dimmed()
                );
                return Ok(());
            }
        }
    }

    run_setup()
}

fn run_setup() -> Result<()> {
    match wizard::run_wizard()? {
        Some(config) => {
            config::save_config(&config)?;
            println!();
            display::print_success("Configuration saved!");
            println!(
                "  Run {} to start blocking.\n",
                "sudo chisel on".bright_white().bold()
            );
            Ok(())
        }
        None => Ok(()),
    }
}

fn show_status(config: &config::Config) -> Result<()> {
    let st = state::load_state()?;
    println!();

    if st.active {
        let since = st
            .activated_at
            .map(|t| t.format("%-I:%M %p").to_string())
            .unwrap_or_else(|| "unknown".to_string());
        display::print_active_status(&since, config.mode_name());
    } else {
        display::print_inactive_status(config.mode_name());
    }

    display::print_schedule(
        &config.schedule.days,
        config.schedule.all_day,
        config.schedule.start_time.as_deref(),
        config.schedule.end_time.as_deref(),
    );

    let next = schedule::next_session_str(config);
    display::print_next_session(&next);
    println!();

    Ok(())
}

fn require_config() -> Result<config::Config> {
    match config::load_config()? {
        Some(c) => Ok(c),
        None => {
            display::print_error("No configuration found. Run `chisel` first to set up.");
            std::process::exit(1);
        }
    }
}
