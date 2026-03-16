use anyhow::{bail, Result};

pub fn require_root() -> Result<()> {
    if !is_root() {
        bail!("This command requires root/administrator privileges.\nRe-run with: sudo chisel <command>");
    }
    Ok(())
}

#[cfg(unix)]
fn is_root() -> bool {
    unsafe { libc::geteuid() == 0 }
}

#[cfg(windows)]
fn is_root() -> bool {
    use std::process::Command;
    Command::new("net")
        .args(["session"])
        .output()
        .map(|o| o.status.success())
        .unwrap_or(false)
}
