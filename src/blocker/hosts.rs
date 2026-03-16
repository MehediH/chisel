use anyhow::{Context, Result};
use std::fs;
use std::path::PathBuf;

use crate::tools::BLOCKED_DOMAINS;

const MARKER_BEGIN: &str = "# BEGIN CHISEL BLOCK";
const MARKER_END: &str = "# END CHISEL BLOCK";

pub fn hosts_path() -> PathBuf {
    if cfg!(windows) {
        PathBuf::from(r"C:\Windows\System32\drivers\etc\hosts")
    } else {
        PathBuf::from("/etc/hosts")
    }
}

pub fn activate() -> Result<()> {
    let path = hosts_path();
    let contents = fs::read_to_string(&path)
        .with_context(|| format!("Failed to read {}", path.display()))?;

    // Remove any existing chisel block
    let cleaned = remove_chisel_block(&contents);

    // Build new block
    let mut block = String::new();
    block.push_str(MARKER_BEGIN);
    block.push('\n');
    for domain in BLOCKED_DOMAINS {
        block.push_str(&format!("0.0.0.0 {domain}\n"));
        block.push_str(&format!(":: {domain}\n"));
    }
    block.push_str(MARKER_END);
    block.push('\n');

    let new_contents = format!("{}\n{}", cleaned.trim_end(), block);
    fs::write(&path, new_contents)
        .with_context(|| format!("Failed to write {}", path.display()))?;

    Ok(())
}

pub fn deactivate() -> Result<()> {
    let path = hosts_path();
    let contents = fs::read_to_string(&path)
        .with_context(|| format!("Failed to read {}", path.display()))?;

    let cleaned = remove_chisel_block(&contents);
    fs::write(&path, cleaned.trim_end().to_string() + "\n")
        .with_context(|| format!("Failed to write {}", path.display()))?;

    Ok(())
}

fn remove_chisel_block(contents: &str) -> String {
    let mut result = String::new();
    let mut inside_block = false;

    for line in contents.lines() {
        if line.trim() == MARKER_BEGIN {
            inside_block = true;
            continue;
        }
        if line.trim() == MARKER_END {
            inside_block = false;
            continue;
        }
        if !inside_block {
            result.push_str(line);
            result.push('\n');
        }
    }

    result
}
