pub mod dns;
pub mod firewall;
pub mod hosts;

use anyhow::Result;
use colored::Colorize;

use crate::blocker::hosts::hosts_path;
use crate::config::{config_path, Config};
use crate::display;
use crate::schedule;
use crate::state::{self, state_path, State};
use crate::tamper;

pub fn activate(config: &Config) -> Result<()> {
    let current = state::load_state()?;
    if current.active {
        display::print_info("Blocking is already active.");
        return Ok(());
    }

    println!();

    // Step 1: Hosts file
    let sp = display::spinner("Updating hosts file...");
    hosts::activate()?;
    display::finish_spinner(&sp, "Hosts file updated");

    // Step 2: DNS flush
    let sp = display::spinner("Flushing DNS cache...");
    dns::flush()?;
    display::finish_spinner(&sp, "DNS cache flushed");

    // Step 3: Firewall rules
    let sp = display::spinner("Configuring firewall rules...");
    firewall::activate()?;
    display::finish_spinner(&sp, "Firewall rules configured");

    // Step 4: Save state
    let new_state = State::active_now(config.mode_name());
    state::save_state(&new_state)?;

    // Step 5: Extreme mode — lock files
    if config.mode.extreme {
        let sp = display::spinner("Locking down config files...");
        tamper::lock_file(&config_path())?;
        tamper::lock_file(&state_path())?;
        tamper::lock_file(&hosts_path())?;
        display::finish_spinner(&sp, "Config files locked (extreme mode)");
    }

    println!();
    display::print_success("All AI coding assistants blocked");
    println!(
        "  {}",
        "Focus up. You've got this.".bright_white().bold()
    );
    println!();

    Ok(())
}

pub fn deactivate(config: &Config) -> Result<()> {
    let current = state::load_state()?;
    if !current.active {
        display::print_info("Blocking is not active.");
        return Ok(());
    }

    // Extreme mode check: refuse during scheduled time
    if config.mode.extreme && schedule::is_blocked_now(config) {
        let ends = schedule::blocking_ends_at(config);
        println!();
        println!(
            "  {} {}",
            "✗".red().bold(),
            "You're in extreme mode.".red().bold()
        );
        println!(
            "  Blocking ends at {}. Keep going!",
            ends.bright_white().bold()
        );
        println!(
            "  {}\n",
            "You chose this. Your future self will thank you.".dimmed()
        );
        return Ok(());
    }

    println!();

    // Extreme mode: unlock files first
    if config.mode.extreme {
        let sp = display::spinner("Unlocking config files...");
        tamper::unlock_file(&config_path())?;
        tamper::unlock_file(&state_path())?;
        tamper::unlock_file(&hosts_path())?;
        display::finish_spinner(&sp, "Config files unlocked");
    }

    // Step 1: Hosts file
    let sp = display::spinner("Restoring hosts file...");
    hosts::deactivate()?;
    display::finish_spinner(&sp, "Hosts file restored");

    // Step 2: DNS flush
    let sp = display::spinner("Flushing DNS cache...");
    dns::flush()?;
    display::finish_spinner(&sp, "DNS cache flushed");

    // Step 3: Firewall rules
    let sp = display::spinner("Removing firewall rules...");
    firewall::deactivate()?;
    display::finish_spinner(&sp, "Firewall rules removed");

    // Step 4: Clear state
    state::save_state(&State::inactive())?;

    println!();
    display::print_success("AI coding assistants unblocked");
    println!();

    Ok(())
}
