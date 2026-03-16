use anyhow::{Context, Result};
use serde::{Deserialize, Serialize};
use std::fs;
use std::path::PathBuf;

#[derive(Debug, Serialize, Deserialize, Clone)]
pub struct Config {
    pub schedule: Schedule,
    pub mode: Mode,
}

#[derive(Debug, Serialize, Deserialize, Clone)]
pub struct Schedule {
    pub days: Vec<String>,
    pub all_day: bool,
    pub start_time: Option<String>,
    pub end_time: Option<String>,
}

#[derive(Debug, Serialize, Deserialize, Clone)]
pub struct Mode {
    pub extreme: bool,
}

impl Config {
    pub fn mode_name(&self) -> &str {
        if self.mode.extreme {
            "extreme"
        } else {
            "normal"
        }
    }
}

pub fn config_dir() -> PathBuf {
    if cfg!(windows) {
        let appdata = std::env::var("APPDATA").unwrap_or_else(|_| {
            dirs_fallback()
        });
        PathBuf::from(appdata).join("chisel")
    } else {
        let home = std::env::var("HOME").unwrap_or_else(|_| "/root".to_string());
        PathBuf::from(home).join(".config").join("chisel")
    }
}

fn dirs_fallback() -> String {
    std::env::var("USERPROFILE").unwrap_or_else(|_| ".".to_string())
}

pub fn config_path() -> PathBuf {
    config_dir().join("config.toml")
}

pub fn load_config() -> Result<Option<Config>> {
    let path = config_path();
    if !path.exists() {
        return Ok(None);
    }
    let contents = fs::read_to_string(&path)
        .with_context(|| format!("Failed to read config from {}", path.display()))?;
    let config: Config =
        toml::from_str(&contents).with_context(|| "Failed to parse config.toml")?;
    Ok(Some(config))
}

pub fn save_config(config: &Config) -> Result<()> {
    let dir = config_dir();
    fs::create_dir_all(&dir)
        .with_context(|| format!("Failed to create config directory {}", dir.display()))?;
    let path = config_path();
    let contents = toml::to_string_pretty(config).context("Failed to serialize config")?;
    fs::write(&path, contents)
        .with_context(|| format!("Failed to write config to {}", path.display()))?;
    Ok(())
}
