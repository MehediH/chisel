import SwiftUI

@main
struct ChiselApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @StateObject private var appState = AppState.shared

    var body: some Scene {
        MenuBarExtra {
            MenuBarView()
                .environmentObject(appState)
        } label: {
            Image(systemName: appState.isBlocking ? "shield.fill" : "shield")
        }
        .menuBarExtraStyle(.window)

        // Setup wizard shown as a regular window when needed
        Window("Chisel Setup", id: "setup") {
            SetupWizardView()
                .environmentObject(appState)
        }
        .windowStyle(.hiddenTitleBar)
        .defaultSize(width: 480, height: 560)
    }
}
