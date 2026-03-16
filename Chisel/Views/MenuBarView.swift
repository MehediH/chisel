import SwiftUI

struct MenuBarView: View {
    @EnvironmentObject var appState: AppState

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header
            HStack {
                Text("chisel")
                    .font(.system(size: 16, weight: .bold, design: .monospaced))
                Spacer()
                if appState.isBlocking {
                    Text("ACTIVE")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(.green)
                } else {
                    Text("INACTIVE")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(.secondary)
                }
            }

            Divider()

            if !appState.hasConfig {
                // No config — prompt setup
                VStack(spacing: 8) {
                    Text("Welcome to Chisel")
                        .font(.headline)
                    Text("Set up your training schedule to get started.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Button("Open Setup") {
                        openSetupWindow()
                    }
                    .buttonStyle(.borderedProminent)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
            } else {
                // Status section
                VStack(alignment: .leading, spacing: 6) {
                    if appState.isBlocking {
                        HStack(spacing: 6) {
                            Circle()
                                .fill(.green)
                                .frame(width: 8, height: 8)
                            Text("Blocking AI tools")
                                .font(.system(size: 13, weight: .medium))
                            if !appState.activatedAtDescription.isEmpty {
                                Text(appState.activatedAtDescription)
                                    .font(.system(size: 11))
                                    .foregroundColor(.secondary)
                            }
                        }
                    } else {
                        HStack(spacing: 6) {
                            Circle()
                                .fill(.gray.opacity(0.4))
                                .frame(width: 8, height: 8)
                            Text("Not blocking")
                                .font(.system(size: 13, weight: .medium))
                                .foregroundColor(.secondary)
                        }
                    }

                    HStack {
                        Text("Mode:")
                            .foregroundColor(.secondary)
                        Text(appState.modeName.capitalized)
                            .fontWeight(.medium)
                    }
                    .font(.system(size: 12))

                    HStack {
                        Text("Schedule:")
                            .foregroundColor(.secondary)
                        Text(appState.scheduleDescription)
                    }
                    .font(.system(size: 12))

                    if !appState.isBlocking, !appState.nextSession.isEmpty {
                        HStack {
                            Text("Next:")
                                .foregroundColor(.secondary)
                            Text(appState.nextSession)
                        }
                        .font(.system(size: 12))
                    }
                }

                Divider()

                // Controls
                VStack(spacing: 4) {
                    if appState.isBlocking {
                        Button(action: deactivate) {
                            Label("Turn Off Blocking", systemImage: "stop.circle")
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        .buttonStyle(.plain)
                        .disabled(appState.isExtremeAndBlocked)
                        .help(appState.isExtremeAndBlocked
                              ? "Extreme mode: blocking can't be turned off during schedule"
                              : "Stop blocking AI tools")
                    } else {
                        Button(action: activate) {
                            Label("Turn On Blocking", systemImage: "play.circle")
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        .buttonStyle(.plain)
                    }

                    Button(action: openSetupWindow) {
                        Label("Settings...", systemImage: "gear")
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .buttonStyle(.plain)
                    .disabled(appState.isExtremeAndBlocked)
                }
            }

            Divider()

            Button(action: { NSApplication.shared.terminate(nil) }) {
                Label("Quit Chisel", systemImage: "xmark.circle")
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .buttonStyle(.plain)
        }
        .padding(12)
        .frame(width: 260)
    }

    // MARK: - Actions

    private func activate() {
        FilterManager.shared.enableFilter { success in
            if success {
                let state = ChiselState(
                    filterActive: true,
                    activatedAt: Date(),
                    mode: appState.config?.mode ?? .normal
                )
                ChiselStore.saveState(state)
                appState.reload()
            }
        }
    }

    private func deactivate() {
        if appState.isExtremeAndBlocked { return }

        FilterManager.shared.disableFilter { success in
            if success {
                ChiselStore.saveState(.inactive)
                appState.reload()
            }
        }
    }

    private func openSetupWindow() {
        for window in NSApp.windows {
            if window.identifier?.rawValue == "setup" {
                window.makeKeyAndOrderFront(nil)
                NSApp.activate(ignoringOtherApps: true)
                return
            }
        }
        if let url = URL(string: "chisel://setup") {
            NSWorkspace.shared.open(url)
        }
        NSApp.activate(ignoringOtherApps: true)
    }
}
