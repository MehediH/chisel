import Foundation

struct ChiselConfig: Codable, Equatable {
    var schedule: Schedule
    var mode: Mode

    struct Schedule: Codable, Equatable {
        var days: [String]      // "mon", "tue", etc.
        var allDay: Bool
        var startTime: String?  // "09:00"
        var endTime: String?    // "17:00"
    }

    enum Mode: String, Codable, Equatable {
        case normal
        case extreme
    }

    static let `default` = ChiselConfig(
        schedule: Schedule(days: [], allDay: true, startTime: nil, endTime: nil),
        mode: .normal
    )
}

struct ChiselState: Codable {
    var filterActive: Bool
    var activatedAt: Date?
    var mode: ChiselConfig.Mode

    static let inactive = ChiselState(filterActive: false, activatedAt: nil, mode: .normal)
}

// MARK: - Persistence via App Group container

enum ChiselStore {
    static var containerURL: URL? {
        FileManager.default.containerURL(
            forSecurityApplicationGroupIdentifier: ChiselConstants.appGroupID
        )
    }

    static func loadConfig() -> ChiselConfig? {
        guard let url = containerURL?.appendingPathComponent(ChiselConstants.configFileName),
              let data = try? Data(contentsOf: url) else { return nil }
        return try? JSONDecoder().decode(ChiselConfig.self, from: data)
    }

    static func saveConfig(_ config: ChiselConfig) {
        guard let url = containerURL?.appendingPathComponent(ChiselConstants.configFileName),
              let data = try? JSONEncoder().encode(config) else { return }
        try? data.write(to: url, options: .atomic)
    }

    static func loadState() -> ChiselState {
        guard let url = containerURL?.appendingPathComponent(ChiselConstants.stateFileName),
              let data = try? Data(contentsOf: url),
              let state = try? JSONDecoder().decode(ChiselState.self, from: data) else {
            return .inactive
        }
        return state
    }

    static func saveState(_ state: ChiselState) {
        guard let url = containerURL?.appendingPathComponent(ChiselConstants.stateFileName),
              let data = try? JSONEncoder().encode(state) else { return }
        try? data.write(to: url, options: .atomic)
    }
}
