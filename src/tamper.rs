use anyhow::{Context, Result};
use std::path::Path;
use std::process::Command;

/// Lock a file to prevent modification (extreme mode).
pub fn lock_file(path: &Path) -> Result<()> {
    if !path.exists() {
        return Ok(());
    }

    #[cfg(target_os = "macos")]
    {
        Command::new("chflags")
            .args(["uchg", &path.to_string_lossy()])
            .output()
            .with_context(|| format!("Failed to lock {}", path.display()))?;
    }

    #[cfg(target_os = "windows")]
    {
        // Set read-only + system attributes
        Command::new("attrib")
            .args(["+R", "+S", &path.to_string_lossy()])
            .output()
            .with_context(|| format!("Failed to set attribs on {}", path.display()))?;

        // Deny write and delete to everyone
        Command::new("icacls")
            .args([
                &path.to_string_lossy().to_string(),
                "/deny",
                "Everyone:(W,D)",
            ])
            .output()
            .with_context(|| format!("Failed to set ACL on {}", path.display()))?;
    }

    #[cfg(not(any(target_os = "macos", target_os = "windows")))]
    {
        // Linux: use chattr +i if available
        let _ = Command::new("chattr")
            .args(["+i", &path.to_string_lossy()])
            .output();
    }

    Ok(())
}

/// Unlock a file (remove immutability).
pub fn unlock_file(path: &Path) -> Result<()> {
    if !path.exists() {
        return Ok(());
    }

    #[cfg(target_os = "macos")]
    {
        Command::new("chflags")
            .args(["nouchg", &path.to_string_lossy()])
            .output()
            .with_context(|| format!("Failed to unlock {}", path.display()))?;
    }

    #[cfg(target_os = "windows")]
    {
        // Remove deny ACL
        Command::new("icacls")
            .args([
                &path.to_string_lossy().to_string(),
                "/remove:d",
                "Everyone",
            ])
            .output()
            .with_context(|| format!("Failed to remove ACL on {}", path.display()))?;

        // Remove read-only + system
        Command::new("attrib")
            .args(["-R", "-S", &path.to_string_lossy()])
            .output()
            .with_context(|| format!("Failed to clear attribs on {}", path.display()))?;
    }

    #[cfg(not(any(target_os = "macos", target_os = "windows")))]
    {
        let _ = Command::new("chattr")
            .args(["-i", &path.to_string_lossy()])
            .output();
    }

    Ok(())
}
