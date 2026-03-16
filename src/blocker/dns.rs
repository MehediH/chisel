use anyhow::{Context, Result};
use std::process::Command;

pub fn flush() -> Result<()> {
    #[cfg(target_os = "macos")]
    {
        Command::new("dscacheutil")
            .arg("-flushcache")
            .output()
            .context("Failed to flush DNS cache (dscacheutil)")?;

        Command::new("killall")
            .args(["-HUP", "mDNSResponder"])
            .output()
            .context("Failed to restart mDNSResponder")?;
    }

    #[cfg(target_os = "windows")]
    {
        Command::new("ipconfig")
            .arg("/flushdns")
            .output()
            .context("Failed to flush DNS cache")?;
    }

    #[cfg(not(any(target_os = "macos", target_os = "windows")))]
    {
        // Linux: try systemd-resolve, ignore if not available
        let _ = Command::new("systemd-resolve")
            .arg("--flush-caches")
            .output();
    }

    Ok(())
}
