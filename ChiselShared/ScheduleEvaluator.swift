import Foundation

/// Pure logic for evaluating whether blocking should be active right now.
/// Used by both the app (for UI) and the extension (for enforcement).
enum ScheduleEvaluator {

    static func isBlockedNow(config: ChiselConfig) -> Bool {
        let now = Date()
        let calendar = Calendar.current
        let weekday = calendar.component(.weekday, from: now) // 1=Sun, 2=Mon, ...

        let todayKey = weekdayToKey(weekday)
        guard config.schedule.days.contains(todayKey) else { return false }

        if config.schedule.allDay { return true }

        guard let startStr = config.schedule.startTime,
              let endStr = config.schedule.endTime,
              let start = parseTime(startStr),
              let end = parseTime(endStr) else { return true }

        let hour = calendar.component(.hour, from: now)
        let minute = calendar.component(.minute, from: now)
        let currentMinutes = hour * 60 + minute

        return currentMinutes >= start && currentMinutes < end
    }

    static func nextSessionDescription(config: ChiselConfig) -> String {
        let calendar = Calendar.current
        let today = calendar.component(.weekday, from: Date())

        for offset in 1...7 {
            let candidate = ((today - 1 + offset) % 7) + 1
            let key = weekdayToKey(candidate)
            if config.schedule.days.contains(key) {
                guard let date = calendar.date(byAdding: .day, value: offset, to: Date()) else {
                    continue
                }
                let formatter = DateFormatter()
                formatter.dateFormat = "EEEE, MMM d"
                return formatter.string(from: date)
            }
        }
        return "No upcoming sessions"
    }

    static func blockingEndsAt(config: ChiselConfig) -> String {
        if config.schedule.allDay {
            return "end of day"
        }
        return config.schedule.endTime ?? "17:00"
    }

    // MARK: - Private

    private static func weekdayToKey(_ weekday: Int) -> String {
        switch weekday {
        case 1: return "sun"
        case 2: return "mon"
        case 3: return "tue"
        case 4: return "wed"
        case 5: return "thu"
        case 6: return "fri"
        case 7: return "sat"
        default: return ""
        }
    }

    private static func parseTime(_ str: String) -> Int? {
        let parts = str.split(separator: ":")
        guard parts.count == 2,
              let h = Int(parts[0]),
              let m = Int(parts[1]) else { return nil }
        return h * 60 + m
    }
}
