import Cocoa
import SystemExtensions
import NetworkExtension
import os.log

class AppDelegate: NSObject, NSApplicationDelegate {
    private let logger = Logger(subsystem: "cotl.chisel.app", category: "delegate")

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Hide dock icon (menu bar only)
        NSApp.setActivationPolicy(.accessory)

        // Check if first run
        if ChiselStore.loadConfig() == nil {
            openSetupWizard()
        }

        // Always ensure the system extension is installed
        ExtensionManager.shared.activate()

        // Start the schedule engine
        ScheduleEngine.shared.start()
    }

    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        // In extreme mode during schedule, prevent quitting
        if let config = ChiselStore.loadConfig(),
           config.mode == .extreme,
           ScheduleEvaluator.isBlockedNow(config: config) {
            logger.info("Quit blocked — extreme mode active")
            return .terminateCancel
        }
        return .terminateNow
    }

    func openSetupWizard() {
        if let url = URL(string: "chisel://setup") {
            NSWorkspace.shared.open(url)
        }
        // Fallback: just open the window via Environment
        for window in NSApp.windows {
            if window.identifier?.rawValue == "setup" {
                window.makeKeyAndOrderFront(nil)
                NSApp.activate(ignoringOtherApps: true)
                return
            }
        }
        // Open via SwiftUI window
        NSApp.activate(ignoringOtherApps: true)
    }
}

// MARK: - System Extension Management

extension AppDelegate {
    func activateExtension() {
        let request = OSSystemExtensionRequest.activationRequest(
            forExtensionWithIdentifier: ChiselConstants.extensionBundleID,
            queue: .main
        )
        request.delegate = ExtensionManager.shared
        OSSystemExtensionManager.shared.submitRequest(request)
    }

    func deactivateExtension() {
        let request = OSSystemExtensionRequest.deactivationRequest(
            forExtensionWithIdentifier: ChiselConstants.extensionBundleID,
            queue: .main
        )
        request.delegate = ExtensionManager.shared
        OSSystemExtensionManager.shared.submitRequest(request)
    }
}
