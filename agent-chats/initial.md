# Chisel — Full Development Conversation Summary

## What is Chisel?

Chisel is a tool that blocks AI coding assistants (Cursor, Claude Code, GitHub Copilot, Windsurf, Tabnine, Codeium, Supermaven, Amazon Q, Sourcegraph Cody) on scheduled days/hours so developers maintain their coding skills without LLM help. The user's tagline: "train your brain. code without ai."

---

## Phase 1: Rust CLI Implementation

The project started as a Rust CLI tool. We implemented a full-featured command-line application with the following architecture:

### Files Created

- **`Cargo.toml`** — Dependencies: clap, colored, indicatif, inquire, serde, toml, chrono, etc.
- **`src/main.rs`** — Entry point with clap dispatch to commands (on/off/status/config/default)
- **`src/cli.rs`** — Clap derive structs (Commands enum: On, Off, Status, Config)
- **`src/wizard.rs`** — Interactive setup wizard with a step-based state machine supporting Esc-to-go-back navigation. Steps: select days → select hours (all day or specific range) → select mode (normal/extreme) → confirm.
- **`src/config.rs`** — Config struct with TOML serialization, persisted at `~/.config/chisel/config.toml`
- **`src/state.rs`** — Runtime state (active/inactive) stored as JSON
- **`src/tools.rs`** — `BLOCKED_DOMAINS` constant containing ~55 AI tool domains including CNAME chain intermediaries
- **`src/schedule.rs`** — Day/time evaluation logic (is today a blocked day? are we within the time window?)
- **`src/privilege.rs`** — Root/admin check using `libc::geteuid`
- **`src/display.rs`** — ASCII banner (3D chisel shape with `\_\` side face), colored status output, spinner helpers
- **`src/tamper.rs`** — Extreme mode file locking (`chflags uchg` on macOS, `icacls` on Windows)
- **`src/blocker/mod.rs`** — Orchestrator with spinners (activate/deactivate flow)
- **`src/blocker/hosts.rs`** — `/etc/hosts` manipulation with BEGIN/END CHISEL markers, both `0.0.0.0` and `::` entries for IPv4+IPv6
- **`src/blocker/dns.rs`** — DNS cache flush (`dscacheutil -flushcache` + `killall mDNSResponder`)
- **`src/blocker/firewall.rs`** — pfctl anchor with resolved IPs (macOS) / netsh rules (Windows)

### Key Features

- **Interactive wizard**: Multi-step setup with Esc-to-go-back. No days selected by default — user must choose.
- **DNS blocking**: Adds entries to `/etc/hosts` mapping AI domains to `0.0.0.0` (IPv4) and `::` (IPv6)
- **Firewall rules**: Resolves domain IPs and blocks them via pfctl anchors
- **Extreme mode**: Locks config files with filesystem flags, prevents turning off blocking during scheduled hours
- **3D ASCII art banner**: A chisel shape with perspective/depth effect

### Bugs Fixed During Phase 1

- **Unused variable warning** in `schedule.rs` from redundant `.succ()` chain — removed dead code
- **Old config file** at `~/.config/chisel/config.toml` with incompatible schema — deleted
- **`cargo` not in PATH** — was at `~/.cargo/bin/cargo`, fixed by prepending to PATH
- **Wizard showing `<canceled>` on Esc** — inquire crate prints canceled status. Fixed with `clear_canceled()` using `Term::stdout().clear_last_lines(1)`

---

## Phase 2: ASCII Art Banner Iteration

Multiple rounds of feedback on the chisel ASCII art:

1. Started with a basic outline — user said "it looks ugly"
2. Made it more detailed — user said "too detailed"
3. Tried outlined-only version — "looks broken" (box-drawing corners didn't connect)
4. Went back to original shape, added 3D perspective with `\_\` side face and `\____________\` bottom face
5. Final version approved: filled 3D chisel shape

---

## Phase 3: DNS Blocking Reliability Fixes

After Phase 1, the user tested and found AI tools still worked:

### Problem 1: IPv6 Bypass

- **Discovery**: `curl -4 api.cursor.sh` was blocked, but `curl api.cursor.sh` (default) succeeded via IPv6 (`2607:6bc0::10`)
- **Root cause**: Hosts file only had `0.0.0.0` entries which only block IPv4. macOS prefers IPv6 when available (AAAA records).
- **Fix**: Added `:: domain` entries alongside `0.0.0.0 domain` entries in `blocker/hosts.rs`

### Problem 2: Missing CNAME Chain Domains

- **Discovery**: Cursor still worked even after IPv6 fix
- **Diagnosis**: Used `lsof -i -n -P | grep -i cursor` and reverse DNS lookups to find actual connection targets
- **Root cause**: Cursor uses intermediate CNAME domains: `api2.cursor.sh` → `api2geo.cursor.sh` → `api2direct.cursor.sh`, plus `auth.cursor.sh`, etc.
- **Fix**: Added ~15 more domains to the blocklist in `tools.rs`

---

## Phase 4: Investigating Per-Process Network Blocking

The user raised a fundamental concern: DNS/IP blocking is whack-a-mole. Proxy servers and intermediate domains keep changing. If we could block at the process level, we'd be 100% sure.

### Research into macOS Process-Level Network Blocking

We investigated all available mechanisms:

1. **`sandbox-exec`** — Can restrict network access per-process, but deprecated and requires launching the target process with the sandbox profile (can't attach to running processes). User said "not good enough."

2. **`pf` (packet filter)** — Can only filter by IP/port, not by process. Not viable.

3. **Endpoint Security Framework** — Can monitor process events but can't selectively block network connections per-process.

4. **`DYLD_INSERT_LIBRARIES`** — Could intercept socket calls via library injection, but SIP prevents this for system binaries and signed apps. Fragile.

5. **`NEFilterDataProvider` (Network Extension)** — The winner. macOS Network Extension framework that:
   - Intercepts ALL outgoing socket connections system-wide
   - Can identify the source process via `audit_token_t` → `audit_token_to_pid()` → `proc_pidpath()`
   - Can allow or drop connections per-process
   - Runs as a system extension that survives app termination
   - **Requires a macOS app bundle** — cannot be a CLI tool

This finding led directly to Phase 5.

---

## Phase 5: macOS SwiftUI GUI App with Network Extension (Current)

The user decided to pivot from the Rust CLI to a native macOS SwiftUI app. The user asked: "what if we turn it into a gui app completely?" and approved scaffolding.

### Architecture

```
Chisel.app (SwiftUI menu bar app)
├── ChiselFilter.systemextension (NEFilterDataProvider)
│   └── Intercepts all outgoing connections, checks source process
├── ChiselShared/ (shared code between app and extension)
│   ├── Constants, Config models, ProcessList, ScheduleEvaluator, IPC protocols
└── Communicates via:
    ├── App Group container (shared filesystem for config/state JSON)
    └── XPC Mach services (real-time IPC)
```

### Files Created

#### Shared (`ChiselShared/`)

- **`Constants.swift`** — App group ID (`group.cotl.chisel.app`), extension bundle ID (`cotl.chisel.app.ChiselFilter`), Mach service name, file names
- **`SharedConfig.swift`** — `ChiselConfig` (schedule + mode) and `ChiselState` (filterActive, activatedAt, mode) Codable models. `ChiselStore` enum with load/save via App Group container.
- **`ProcessList.swift`** — `ChiselProcessList` with process signatures for all AI tools (Cursor, Claude Code, Copilot, Windsurf, Tabnine, Codeium, Supermaven, Amazon Q, Cody). Matches via substring against executable path.
- **`ScheduleEvaluator.swift`** — Pure schedule logic: `isBlockedNow()`, `nextSessionDescription()`, `blockingEndsAt()`. Maps Calendar weekday ints to day keys ("mon", "tue", etc.).
- **`IPCProtocol.swift`** — `@objc` protocols: `AppToFilterProtocol` (updateConfig, getStatus) and `FilterToAppProtocol` (filterDidBlock, filterStatusChanged)

#### Network Extension (`ChiselFilter/`)

- **`main.swift`** — Entry point: `NEProvider.startSystemExtensionMode()` + `dispatchMain()`
- **`FilterDataProvider.swift`** — Core `NEFilterDataProvider` subclass:
  - `startFilter()`: Creates `NEFilterRule`s for all outbound TCP/UDP on `0.0.0.0` and `::` with `.filterData` action
  - `handleNewFlow()`: Extracts audit token → pid → `proc_pidpath()` → checks against `ChiselProcessList` → returns `.drop()` or `.allow()`
  - `shouldBlock()`: Reads config from shared store, checks if filter is active AND schedule says blocked now
  - `executablePath(from:)`: Converts `sourceAppAuditToken` Data → `audit_token_t` → `audit_token_to_pid()` → `proc_pidpath()`
  - Links against `libbsm` for `audit_token_to_pid`

#### Main App (`Chisel/`)

- **`App/ChiselApp.swift`** — SwiftUI `@main` app with `MenuBarExtra` (shield icon) and setup wizard `Window`
- **`App/AppDelegate.swift`** — `NSApplicationDelegate`:
  - Sets activation policy to `.accessory` (menu bar only, no dock icon)
  - Opens setup wizard on first run (no config)
  - Always activates the system extension on launch
  - Starts `ScheduleEngine`
  - Blocks quit in extreme mode during schedule
  - Has `activateExtension()`/`deactivateExtension()` methods
- **`Models/AppState.swift`** — `ObservableObject` holding config, blocking state, computed properties for UI
- **`Views/MenuBarView.swift`** — Menu bar popup showing:
  - Status (active/inactive with green/gray dot)
  - Mode and schedule info
  - Turn on/off blocking buttons
  - Settings button (opens wizard)
  - Quit button (blocked in extreme mode)
- **`Views/SetupWizardView.swift`** — 4-step onboarding wizard:
  - Step 0: Select days (checkboxes + Weekdays/All/Clear shortcuts)
  - Step 1: All day vs specific hours (with time text fields)
  - Step 2: Mode selection (Normal vs Extreme with warning card)
  - Step 3: Review & confirm
  - On save: persists config, activates extension
- **`Services/ExtensionManager.swift`** — `OSSystemExtensionRequestDelegate` handling activation/deactivation of the system extension
- **`Services/FilterManager.swift`** — Wrapper around `NEFilterManager` for enabling/disabling the content filter, configuring `NEFilterProviderConfiguration`
- **`Services/ScheduleEngine.swift`** — Timer-based engine that checks every 30 seconds if blocking should be auto-activated or deactivated based on schedule

#### Project Configuration

- **`project.yml`** — XcodeGen spec defining both targets:
  - `Chisel` (application) — automatic signing with team `F8HXV863FX` (COLOR OUTSIDE THE LINES LTD)
  - `ChiselFilter` (system-extension) — embedded in app at `Contents/Library/SystemExtensions/`
  - Both targets share `ChiselShared/` sources
  - Entitlements: app-sandbox disabled, app groups, network extension (content-filter-provider), system-extension.install
- **`Chisel/Info.plist`** — Generated by xcodegen. LSUIElement=true, URL scheme `chisel://`, NetworkExtension Mach service
- **`ChiselFilter/Info.plist`** — Generated by xcodegen. NSExtension point `com.apple.networkextension.filter-data`, principal class `FilterDataProvider`
- **`Chisel/Chisel.entitlements`** — App entitlements (app groups, system extension install, network extension content-filter-provider)
- **`ChiselFilter/ChiselFilter.entitlements`** — Extension entitlements (app groups, network extension content-filter-provider)

### Bundle ID

Originally `dev.chisel.app`, renamed to `cotl.chisel.app` at user's request. The rename touched all Swift files, plists, entitlements, and project.yml.

### Build System

- **XcodeGen** (`/opt/homebrew/bin/xcodegen`) generates `Chisel.xcodeproj` from `project.yml`
- Build command: `xcodegen generate && xcodebuild -project Chisel.xcodeproj -scheme Chisel -configuration Debug build`
- Signing: Automatic with Development Team `F8HXV863FX` (certificate: "Apple Development: MD MEHEDI H KHAN (KYDW84YWVV)")

### Build Issues & Fixes

1. **`handleRulesChanged` unavailable** — Apple marked it unavailable in newer SDKs. Removed the override.
2. **`apply()` completion type mismatch** — Completion handler passes `Error?` not `Bool`. Fixed to check `if let error = error`.
3. **`audit_token_to_pid` undefined symbol** — Needed to link `libbsm`. Added `OTHER_LDFLAGS: "-lbsm"` to ChiselFilter target.
4. **Provisioning profile required** — Initial build used `CODE_SIGN_IDENTITY: "-"` (ad-hoc). Switched to automatic signing with team ID.

---

## Current Blocker: System Extension Installation

The system extension (`ChiselFilter.systemextension`) fails to install. The investigation revealed:

### Issue 1: App Must Be in `/Applications`

The error from sysextd logs:
```
App containing System Extension to be activated must be in /Applications folder.
Current location: file:///Users/meh/Library/Developer/Xcode/DerivedData/...
```

**Fix**: Copied built app to `/Applications/Chisel.app`

### Issue 2: Extension Activation Only on First Setup

The `ExtensionManager.shared.activate()` was only called from `SetupWizardView.save()`. If the setup wizard was completed when the app was in DerivedData (which failed), the config was saved but the extension never installed. When re-launched from `/Applications`, the wizard was skipped (config exists) so activation never retried.

**Fix**: Added `ExtensionManager.shared.activate()` call in `applicationDidFinishLaunching` so it runs on every launch.

### Issue 3: SIP Blocks Development-Signed System Extensions

Even after moving to `/Applications` and proper signing, sysextd logs show:
```
client activation request for cotl.chisel.app.ChiselFilter
attempting to realize extension with identifier cotl.chisel.app.ChiselFilter
no policy, cannot allow apps outside /Applications
```

The "no policy" message is misleading — it actually means: macOS requires either:
- **Developer ID signing + notarization** (for distribution), OR
- **SIP disabled + `systemextensionsctl developer on`** (for development)

Running `systemextensionsctl developer` returns:
```
At this time, this tool cannot be used if System Integrity Protection is enabled.
```

### Current Status

**The app builds and runs correctly** — it shows in the menu bar, config persists to the App Group container, and the schedule engine evaluates properly. But the **system extension cannot activate** because SIP prevents development-signed system extensions from loading.

### Next Steps (Two Options)

**Option A: Disable SIP for Development**
1. Restart Mac → Recovery Mode (hold Power)
2. Terminal → `csrutil disable`
3. Restart → `systemextensionsctl developer on`
4. Extension will load and filter will work
5. Re-enable SIP when done: `csrutil enable`

**Option B: Developer ID Signing for Production**
1. Get a "Developer ID Application" certificate from developer.apple.com
2. Request the Network Extension entitlement from Apple (https://developer.apple.com/contact/request/network-extension)
3. Sign with Developer ID instead of development certificate
4. Notarize the app
5. Extension will load without SIP changes

---

## Technical Details

### Process Matching Strategy

The filter identifies processes by their executable path (via `proc_pidpath()`). Matching is case-insensitive substring matching:

| Tool | Path Patterns |
|------|--------------|
| Cursor | `Cursor.app`, `cursor.app` |
| Claude Code | `/claude`, `claude-code` |
| GitHub Copilot | `copilot-agent`, `copilot-language-server`, `github-copilot` |
| Windsurf | `Windsurf.app`, `windsurf.app` |
| Tabnine | `tabnine`, `TabNine` |
| Codeium | `codeium`, `Codeium` |
| Supermaven | `supermaven`, `Supermaven` |
| Amazon Q | `amazon-q`, `codewhisperer` |
| Sourcegraph Cody | `cody`, `sourcegraph` |

On the test machine, Claude Code's binary is at `/Users/meh/.local/share/claude/versions/2.1.74` (symlinked from `/Users/meh/.local/bin/claude`), which would match the `/claude` pattern.

### Config Format (JSON in App Group Container)

```json
// ~/Library/Group Containers/group.cotl.chisel.app/chisel_config.json
{"mode":"normal","schedule":{"days":["fri"],"allDay":true}}

// ~/Library/Group Containers/group.cotl.chisel.app/chisel_state.json
{"filterActive":true,"mode":"normal","activatedAt":795109799.136632}
```

### Signing Identity

- **Team**: F8HXV863FX (COLOR OUTSIDE THE LINES LTD)
- **Certificate**: Apple Development: MD MEHEDI H KHAN (KYDW84YWVV)
- **Provisioning**: Mac Team Provisioning Profile: cotl.chisel.app (70557ca9-094e-4822-af9e-8144a6840521)
