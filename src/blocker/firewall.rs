use anyhow::{Context, Result};
use std::process::Command;

use crate::tools::BLOCKED_DOMAINS;

#[cfg(target_os = "macos")]
const ANCHOR_NAME: &str = "com.chisel.block";

pub fn activate() -> Result<()> {
    #[cfg(target_os = "macos")]
    macos_activate()?;

    #[cfg(target_os = "windows")]
    windows_activate()?;

    Ok(())
}

pub fn deactivate() -> Result<()> {
    #[cfg(target_os = "macos")]
    macos_deactivate()?;

    #[cfg(target_os = "windows")]
    windows_deactivate()?;

    Ok(())
}

#[cfg(target_os = "macos")]
fn macos_activate() -> Result<()> {
    // Resolve domains to IPs and build pfctl rules
    let mut rules = String::new();
    rules.push_str(&format!("table <chisel_blocked> persist {{\n"));

    for domain in BLOCKED_DOMAINS {
        // Use the domain directly — pfctl can resolve, or we add IP entries
        // For simplicity, block via DNS name in the table
        if let Ok(output) = Command::new("dig")
            .args(["+short", domain])
            .output()
        {
            let ips = String::from_utf8_lossy(&output.stdout);
            for line in ips.lines() {
                let trimmed = line.trim();
                if !trimmed.is_empty() && trimmed.chars().next().map_or(false, |c| c.is_ascii_digit()) {
                    rules.push_str(&format!("  {trimmed}\n"));
                }
            }
        }
    }

    rules.push_str("}\n");
    rules.push_str("block drop out quick on en0 to <chisel_blocked>\n");
    rules.push_str("block drop out quick on en1 to <chisel_blocked>\n");

    // Write anchor rules
    let anchor_path = format!("/etc/pf.anchors/{ANCHOR_NAME}");
    std::fs::write(&anchor_path, &rules)
        .with_context(|| "Failed to write pfctl anchor")?;

    // Load anchor into pfctl
    Command::new("pfctl")
        .args(["-a", ANCHOR_NAME, "-f", &anchor_path])
        .output()
        .context("Failed to load pfctl anchor")?;

    // Enable pf if not already enabled
    Command::new("pfctl")
        .args(["-e"])
        .output()
        .ok(); // Ignore error if already enabled

    Ok(())
}

#[cfg(target_os = "macos")]
fn macos_deactivate() -> Result<()> {
    // Flush the anchor
    Command::new("pfctl")
        .args(["-a", ANCHOR_NAME, "-F", "all"])
        .output()
        .context("Failed to flush pfctl anchor")?;

    // Remove anchor file
    let anchor_path = format!("/etc/pf.anchors/{ANCHOR_NAME}");
    let _ = std::fs::remove_file(anchor_path);

    Ok(())
}

#[cfg(target_os = "windows")]
fn windows_activate() -> Result<()> {
    for domain in BLOCKED_DOMAINS {
        let rule_name = format!("Chisel Block - {domain}");
        Command::new("netsh")
            .args([
                "advfirewall",
                "firewall",
                "add",
                "rule",
                &format!("name={rule_name}"),
                "dir=out",
                "action=block",
                &format!("remoteip={domain}"),
                "enable=yes",
            ])
            .output()
            .with_context(|| format!("Failed to add firewall rule for {domain}"))?;
    }
    Ok(())
}

#[cfg(target_os = "windows")]
fn windows_deactivate() -> Result<()> {
    for domain in BLOCKED_DOMAINS {
        let rule_name = format!("Chisel Block - {domain}");
        let _ = Command::new("netsh")
            .args([
                "advfirewall",
                "firewall",
                "delete",
                "rule",
                &format!("name={rule_name}"),
            ])
            .output();
    }
    Ok(())
}
