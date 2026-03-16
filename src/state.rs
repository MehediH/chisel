use anyhow::{Context, Result};
use chrono::{DateTime, Local};
use serde::{Deserialize, Serialize};
use std::fs;

use crate::config::config_dir;

#[derive(Debug, Serialize, Deserialize, Clone)]
pub struct State {
    pub active: bool,
    pub activated_at: Option<DateTime<Local>>,
    pub mode: String,
}

impl State {
    pub fn inactive() -> Self {
        Self {
            active: false,
            activated_at: None,
            mode: "normal".to_string(),
        }
    }

    pub fn active_now(mode: &str) -> Self {
        Self {
            active: true,
            activated_at: Some(Local::now()),
            mode: mode.to_string(),
        }
    }
}

pub fn state_path() -> std::path::PathBuf {
    config_dir().join("state.json")
}

pub fn load_state() -> Result<State> {
    let path = state_path();
    if !path.exists() {
        return Ok(State::inactive());
    }
    let contents = fs::read_to_string(&path)
        .with_context(|| format!("Failed to read state from {}", path.display()))?;
    let state: State =
        serde_json::from_str(&contents).with_context(|| "Failed to parse state.json")?;
    Ok(state)
}

pub fn save_state(state: &State) -> Result<()> {
    let dir = config_dir();
    fs::create_dir_all(&dir)?;
    let path = state_path();
    let contents = serde_json::to_string_pretty(state)?;
    fs::write(&path, contents)
        .with_context(|| format!("Failed to write state to {}", path.display()))?;
    Ok(())
}
