import Foundation
import NetworkExtension
import os.log

class FilterManager: NSObject {
    static let shared = FilterManager()

    private let logger = Logger(subsystem: "cotl.chisel.app", category: "filter-manager")

    func loadFromPreferences(completion: @escaping (NEFilterManager) -> Void) {
        NEFilterManager.shared().loadFromPreferences { error in
            if let error = error {
                self.logger.error("Failed to load filter prefs: \(error.localizedDescription)")
            }
            completion(NEFilterManager.shared())
        }
    }

    func enableFilter(completion: @escaping (Bool) -> Void) {
        loadFromPreferences { manager in
            manager.localizedDescription = "Chisel AI Blocker"
            manager.isEnabled = true

            if manager.providerConfiguration == nil {
                let providerConfig = NEFilterProviderConfiguration()
                providerConfig.filterSockets = true
                providerConfig.filterPackets = false
                manager.providerConfiguration = providerConfig
            }

            manager.saveToPreferences { error in
                if let error = error {
                    self.logger.error("Failed to enable filter: \(error.localizedDescription)")
                    completion(false)
                } else {
                    self.logger.info("Filter enabled successfully")
                    completion(true)
                }
            }
        }
    }

    func disableFilter(completion: @escaping (Bool) -> Void) {
        loadFromPreferences { manager in
            manager.isEnabled = false
            manager.saveToPreferences { error in
                if let error = error {
                    self.logger.error("Failed to disable filter: \(error.localizedDescription)")
                    completion(false)
                } else {
                    self.logger.info("Filter disabled successfully")
                    completion(true)
                }
            }
        }
    }

    func isFilterEnabled(completion: @escaping (Bool) -> Void) {
        loadFromPreferences { manager in
            completion(manager.isEnabled)
        }
    }
}
