import SwiftUI
import Combine

class AppState: ObservableObject {
    static let shared = AppState()

    @Published var config: ChiselConfig?
    @Published var isBlocking: Bool = false
    @Published var isExtensionInstalled: Bool = false
    @Published var activatedAt: Date?

    private init() {
        reload()
    }

    func reload() {
        config = ChiselStore.loadConfig()
        let state = ChiselStore.loadState()
        isBlocking = state.filterActive
        activatedAt = state.activatedAt
    }

    var hasConfig: Bool { config != nil }

    var modeName: String {
        config?.mode.rawValue ?? "normal"
    }

    var isExtremeAndBlocked: Bool {
        guard let config = config else { return false }
        return config.mode == .extreme && ScheduleEvaluator.isBlockedNow(config: config)
    }

    var scheduleDescription: String {
        guard let config = config else { return "Not configured" }
        let days = config.schedule.days.map { $0.capitalized }.joined(separator: ", ")
        let time = config.schedule.allDay ? "All day" : "\(config.schedule.startTime ?? "09:00") – \(config.schedule.endTime ?? "17:00")"
        return "\(days) — \(time)"
    }

    var nextSession: String {
        guard let config = config else { return "" }
        return ScheduleEvaluator.nextSessionDescription(config: config)
    }

    var activatedAtDescription: String {
        guard let date = activatedAt else { return "" }
        let formatter = DateFormatter()
        formatter.dateFormat = "h:mm a"
        return "since \(formatter.string(from: date))"
    }
}
