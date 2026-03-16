use clap::{Parser, Subcommand};

#[derive(Parser)]
#[command(name = "chisel", about = "Train your brain. Code without AI.", version)]
pub struct Cli {
    #[command(subcommand)]
    pub command: Option<Commands>,
}

#[derive(Subcommand)]
pub enum Commands {
    /// Activate AI blocking
    On,
    /// Deactivate AI blocking
    Off,
    /// Show current status and schedule
    Status,
    /// Re-run setup wizard
    Config,
}
