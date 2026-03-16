use colored::Colorize;
use indicatif::{ProgressBar, ProgressStyle};
use std::time::Duration;

pub fn print_banner() {
    println!();
    println!("         {}", "___".bright_white());
    println!("        {}{}", "/   \\".bright_white(), "_\\".dimmed());
    println!("       {}{}", "/     \\".bright_white(), "_\\".dimmed());
    println!("      {}{}", "/       \\".bright_white(), "_\\".dimmed());
    println!("     {}{}", "/  _   _  \\".bright_white(), "_\\".dimmed());
    println!("    {}{}", "/__| |_| |__\\".bright_white(), "_\\".dimmed());
    println!("     {}", "\\____________\\".dimmed());
    println!("       {}", "| | | |".yellow());
    println!("       {}", "| | | |".yellow());
    println!("       {}", "| | | |".yellow());
    println!("       {}", "| | | |".yellow());
    println!("       {}", "|_| |_|".yellow());
    println!();
    println!(
        "    {}",
        "c h i s e l".bold().bright_white()
    );
    println!(
        "    {}\n",
        "train your brain. code without ai.".dimmed()
    );
}

pub fn print_success(msg: &str) {
    println!("  {} {}", "✓".green().bold(), msg);
}

pub fn print_error(msg: &str) {
    println!("  {} {}", "✗".red().bold(), msg);
}

pub fn print_info(msg: &str) {
    println!("  {}", msg.dimmed());
}

pub fn print_active_status(since: &str, mode: &str) {
    println!(
        "  {} {} {}",
        "●".green().bold(),
        "ACTIVE".green().bold(),
        format!("since {since}").dimmed()
    );
    println!("  Mode: {}\n", mode.bold());
    println!("  {}", "Blocking all AI coding assistants".white());
}

pub fn print_inactive_status(mode: &str) {
    println!("  {} {}", "○".dimmed(), "INACTIVE".dimmed().bold());
    println!("  Mode: {}\n", mode.bold());
}

pub fn print_schedule(days: &[String], all_day: bool, start: Option<&str>, end: Option<&str>) {
    let day_str = days
        .iter()
        .map(|d| capitalize_day(d))
        .collect::<Vec<_>>()
        .join(", ");

    let time_str = if all_day {
        "All day".to_string()
    } else {
        format!(
            "{} - {}",
            start.unwrap_or("09:00"),
            end.unwrap_or("17:00")
        )
    };

    println!("  Schedule: {} — {}", day_str, time_str);
}

pub fn print_next_session(next: &str) {
    println!("  Next session: {}", next);
}

pub fn spinner(msg: &str) -> ProgressBar {
    let pb = ProgressBar::new_spinner();
    pb.set_style(
        ProgressStyle::default_spinner()
            .tick_chars("⠋⠙⠹⠸⠼⠴⠦⠧⠇⠏")
            .template("  {spinner} {msg}")
            .unwrap(),
    );
    pb.set_message(msg.to_string());
    pb.enable_steady_tick(Duration::from_millis(80));
    pb
}

pub fn finish_spinner(pb: &ProgressBar, msg: &str) {
    pb.finish_and_clear();
    print_success(msg);
}

fn capitalize_day(d: &str) -> String {
    let mut c = d.chars();
    match c.next() {
        None => String::new(),
        Some(f) => f.to_uppercase().to_string() + c.as_str(),
    }
}
