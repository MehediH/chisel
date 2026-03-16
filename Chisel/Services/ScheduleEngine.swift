import Foundation
import os.log

/// Periodically evaluates the schedule and activates/deactivates the filter.
class ScheduleEngine {
    static let shared = ScheduleEngine()

    private let logger = Logger(subsystem: "cotl.chisel.app", category: "schedule")
    private var timer: Timer?

    func start() {
        // Check immediately
        evaluate()

        // Then check every 30 seconds
        timer = Timer.scheduledTimer(withTimeInterval: 30, repeats: true) { [weak self] _ in
            self?.evaluate()
        }
    }

    func stop() {
        timer?.invalidate()
        timer = nil
    }

    private func evaluate() {
        guard let config = ChiselStore.loadConfig() else { return }

        let state = ChiselStore.loadState()
        let shouldBeBlocking = ScheduleEvaluator.isBlockedNow(config: config)

        if shouldBeBlocking && !state.filterActive {
            // Schedule says block — auto-activate
            logger.info("Schedule triggered: activating filter")
            FilterManager.shared.enableFilter { success in
                if success {
                    let newState = ChiselState(
                        filterActive: true,
                        activatedAt: Date(),
                        mode: config.mode
                    )
                    ChiselStore.saveState(newState)
                    DispatchQueue.main.async {
                        AppState.shared.reload()
                    }
                }
            }
        } else if !shouldBeBlocking && state.filterActive {
            // Outside schedule — auto-deactivate
            logger.info("Schedule ended: deactivating filter")
            FilterManager.shared.disableFilter { success in
                if success {
                    ChiselStore.saveState(.inactive)
                    DispatchQueue.main.async {
                        AppState.shared.reload()
                    }
                }
            }
        }
    }
}
