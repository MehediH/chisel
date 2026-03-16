use anyhow::Result;
use colored::Colorize;
use console::Term;
use inquire::error::InquireResult;
use inquire::{Confirm, InquireError, MultiSelect, Select, Text};

use crate::config::{Config, Mode, Schedule};
use crate::display;

fn clear_canceled() {
    let _ = Term::stdout().clear_last_lines(1);
}

fn clear_prev_answer() {
    let _ = Term::stdout().clear_last_lines(1);
}

const DAYS: &[&str] = &[
    "Monday",
    "Tuesday",
    "Wednesday",
    "Thursday",
    "Friday",
    "Saturday",
    "Sunday",
];

const DAY_KEYS: &[&str] = &["mon", "tue", "wed", "thu", "fri", "sat", "sun"];

/// Returns Ok(None) on cancel/Esc at step 1, Ok(Some(config)) on success.
pub fn run_wizard() -> Result<Option<Config>> {
    display::print_banner();

    println!(
        "  {}",
        "Welcome! Let's set up your AI-free coding schedule.".bright_white()
    );
    println!("  {}\n", "(Press Esc to go back)".dimmed());

    let mut day_keys: Vec<String> = vec![];
    let mut all_day = true;
    let mut start_time: Option<String> = None;
    let mut end_time: Option<String> = None;
    let mut extreme = false;

    let mut step: u8 = 1;

    loop {
        match step {
            1 => match prompt_days() {
                Ok(Some(keys)) => {
                    day_keys = keys;
                    step = 2;
                }
                Ok(None) => return Ok(None), // empty selection
                Err(_) => return Ok(None),    // Esc at first step = quit
            },

            2 => match prompt_time_choice() {
                Ok(choice) => {
                    all_day = choice;
                    step = if all_day { 4 } else { 3 };
                }
                Err(_) => {
                    clear_prev_answer();
                    step = 1;
                }
            },

            3 => match prompt_hours() {
                Ok((s, e)) => {
                    start_time = Some(s);
                    end_time = Some(e);
                    step = 4;
                }
                Err(_) => {
                    clear_prev_answer();
                    step = 2;
                }
            },

            4 => match prompt_mode() {
                Ok(is_extreme) => {
                    extreme = is_extreme;
                    step = 5;
                }
                Err(_) => {
                    clear_prev_answer();
                    step = if all_day { 2 } else { 3 };
                }
            },

            5 => match prompt_confirm(&day_keys, all_day, start_time.as_deref(), end_time.as_deref(), extreme) {
                Ok(true) => {
                    let config = Config {
                        schedule: Schedule {
                            days: day_keys,
                            all_day,
                            start_time,
                            end_time,
                        },
                        mode: Mode { extreme },
                    };
                    return Ok(Some(config));
                }
                Ok(false) => {
                    println!("\n  {}", "Setup cancelled.".yellow());
                    return Ok(None);
                }
                Err(_) => {
                    clear_prev_answer();
                    step = 4;
                }
            },

            _ => unreachable!(),
        }
    }
}

fn prompt_days() -> std::result::Result<Option<Vec<String>>, ()> {
    let result: InquireResult<Vec<&str>> = MultiSelect::new(
        "Which days do you want to code without AI?",
        DAYS.to_vec(),
    )
    .prompt();

    match result {
        Ok(selected) if selected.is_empty() => {
            println!("\n  {}", "No days selected. Setup cancelled.".yellow());
            Ok(None)
        }
        Ok(selected) => {
            let keys = selected
                .iter()
                .filter_map(|d| {
                    DAYS.iter()
                        .position(|&full| full == *d)
                        .map(|i| DAY_KEYS[i].to_string())
                })
                .collect();
            Ok(Some(keys))
        }
        Err(InquireError::OperationCanceled) => {
            clear_canceled();
            Err(())
        }
        Err(e) => {
            eprintln!("Error: {e}");
            Err(())
        }
    }
}

fn prompt_time_choice() -> std::result::Result<bool, ()> {
    match Select::new(
        "Block all day or set specific hours?",
        vec!["All day", "Specific hours"],
    )
    .prompt()
    {
        Ok(choice) => Ok(choice == "All day"),
        Err(InquireError::OperationCanceled) => {
            clear_canceled();
            Err(())
        }
        Err(e) => {
            eprintln!("Error: {e}");
            Err(())
        }
    }
}

fn prompt_hours() -> std::result::Result<(String, String), ()> {
    let start = match Text::new("Start time (24h format):")
        .with_default("09:00")
        .prompt()
    {
        Ok(s) => s,
        Err(InquireError::OperationCanceled) => {
            clear_canceled();
            return Err(());
        }
        Err(e) => {
            eprintln!("Error: {e}");
            return Err(());
        }
    };

    let end = match Text::new("End time (24h format):")
        .with_default("17:00")
        .prompt()
    {
        Ok(s) => s,
        Err(InquireError::OperationCanceled) => {
            clear_canceled();
            return Err(());
        }
        Err(e) => {
            eprintln!("Error: {e}");
            return Err(());
        }
    };

    Ok((start, end))
}

fn prompt_mode() -> std::result::Result<bool, ()> {
    let choice = match Select::new(
        "Choose your mode:",
        vec![
            "Normal  — you can turn off blocking anytime (escape hatch)",
            "Extreme — no way to turn it off during scheduled time. True commitment.",
        ],
    )
    .prompt()
    {
        Ok(c) => c,
        Err(InquireError::OperationCanceled) => {
            clear_canceled();
            return Err(());
        }
        Err(e) => {
            eprintln!("Error: {e}");
            return Err(());
        }
    };

    let extreme = choice.starts_with("Extreme");

    if extreme {
        match Confirm::new(
            "Are you sure? In extreme mode, you cannot disable blocking during your scheduled time. There is no override.",
        )
        .with_default(false)
        .prompt()
        {
            Ok(true) => Ok(true),
            Ok(false) => {
                println!("  {}", "Switched to normal mode.".yellow());
                Ok(false)
            }
            Err(InquireError::OperationCanceled) => {
            clear_canceled();
            Err(())
        }
            Err(e) => {
                eprintln!("Error: {e}");
                Err(())
            }
        }
    } else {
        Ok(false)
    }
}

fn prompt_confirm(
    days: &[String],
    all_day: bool,
    start_time: Option<&str>,
    end_time: Option<&str>,
    extreme: bool,
) -> std::result::Result<bool, ()> {
    println!("\n  {}", "── Configuration Summary ──".bold().bright_white());
    display::print_schedule(days, all_day, start_time, end_time);
    println!(
        "  Mode: {}",
        if extreme {
            "extreme".red().bold().to_string()
        } else {
            "normal".green().bold().to_string()
        }
    );
    println!();

    match Confirm::new("Save this configuration?")
        .with_default(true)
        .prompt()
    {
        Ok(v) => Ok(v),
        Err(InquireError::OperationCanceled) => {
            clear_canceled();
            Err(())
        }
        Err(e) => {
            eprintln!("Error: {e}");
            Err(())
        }
    }
}
