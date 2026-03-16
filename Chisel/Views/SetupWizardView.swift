import SwiftUI

struct SetupWizardView: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.dismiss) var dismiss

    @State private var step = 0
    @State private var selectedDays: Set<String> = []
    @State private var allDay = true
    @State private var startTime = "09:00"
    @State private var endTime = "17:00"
    @State private var mode: ChiselConfig.Mode = .normal
    @State private var showExtremeConfirm = false

    private let dayOptions: [(key: String, label: String)] = [
        ("mon", "Monday"),
        ("tue", "Tuesday"),
        ("wed", "Wednesday"),
        ("thu", "Thursday"),
        ("fri", "Friday"),
        ("sat", "Saturday"),
        ("sun", "Sunday"),
    ]

    var body: some View {
        VStack(spacing: 0) {
            // Banner
            VStack(spacing: 4) {
                Text("chisel")
                    .font(.system(size: 28, weight: .bold, design: .monospaced))
                Text("train your brain. code without ai.")
                    .font(.system(size: 12, design: .monospaced))
                    .foregroundColor(.secondary)
            }
            .padding(.top, 32)
            .padding(.bottom, 24)

            // Step indicator
            HStack(spacing: 8) {
                ForEach(0..<4) { i in
                    Circle()
                        .fill(i <= step ? Color.accentColor : Color.gray.opacity(0.3))
                        .frame(width: 8, height: 8)
                }
            }
            .padding(.bottom, 24)

            // Content
            Group {
                switch step {
                case 0: daysStep
                case 1: hoursStep
                case 2: modeStep
                case 3: confirmStep
                default: EmptyView()
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .padding(.horizontal, 32)

            // Navigation
            HStack {
                if step > 0 {
                    Button("Back") { step -= 1 }
                        .keyboardShortcut(.escape, modifiers: [])
                }
                Spacer()
                if step < 3 {
                    Button("Next") { advance() }
                        .keyboardShortcut(.return, modifiers: [])
                        .buttonStyle(.borderedProminent)
                        .disabled(step == 0 && selectedDays.isEmpty)
                } else {
                    Button("Save & Start") { save() }
                        .keyboardShortcut(.return, modifiers: [])
                        .buttonStyle(.borderedProminent)
                }
            }
            .padding(24)
        }
        .frame(width: 480, height: 560)
        .onAppear { loadExisting() }
    }

    // MARK: - Steps

    private var daysStep: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Which days do you want to code without AI?")
                .font(.headline)

            VStack(spacing: 4) {
                ForEach(dayOptions, id: \.key) { day in
                    Toggle(day.label, isOn: Binding(
                        get: { selectedDays.contains(day.key) },
                        set: { isOn in
                            if isOn { selectedDays.insert(day.key) }
                            else { selectedDays.remove(day.key) }
                        }
                    ))
                    .toggleStyle(.checkbox)
                }
            }
            .padding(.leading, 4)

            HStack(spacing: 12) {
                Button("Weekdays") {
                    selectedDays = Set(["mon", "tue", "wed", "thu", "fri"])
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                Button("All") {
                    selectedDays = Set(dayOptions.map(\.key))
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                Button("Clear") {
                    selectedDays.removeAll()
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            }
        }
    }

    private var hoursStep: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Block all day or set specific hours?")
                .font(.headline)

            Picker("", selection: $allDay) {
                Text("All day").tag(true)
                Text("Specific hours").tag(false)
            }
            .pickerStyle(.radioGroup)

            if !allDay {
                HStack(spacing: 16) {
                    VStack(alignment: .leading) {
                        Text("Start").font(.caption).foregroundColor(.secondary)
                        TextField("09:00", text: $startTime)
                            .textFieldStyle(.roundedBorder)
                            .frame(width: 80)
                    }
                    VStack(alignment: .leading) {
                        Text("End").font(.caption).foregroundColor(.secondary)
                        TextField("17:00", text: $endTime)
                            .textFieldStyle(.roundedBorder)
                            .frame(width: 80)
                    }
                }
                Text("Use 24-hour format (e.g. 09:00, 17:00)")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
    }

    private var modeStep: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Choose your mode")
                .font(.headline)

            VStack(alignment: .leading, spacing: 12) {
                modeCard(
                    mode: .normal,
                    title: "Normal",
                    subtitle: "You can turn off blocking anytime",
                    icon: "shield"
                )
                modeCard(
                    mode: .extreme,
                    title: "Extreme",
                    subtitle: "No way to turn off during scheduled time",
                    icon: "shield.fill"
                )
            }

            if mode == .extreme {
                HStack(spacing: 6) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(.orange)
                    Text("In extreme mode, you cannot disable blocking during your scheduled time. There is no override.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding(8)
                .background(Color.orange.opacity(0.1))
                .cornerRadius(6)
            }
        }
    }

    private func modeCard(mode: ChiselConfig.Mode, title: String, subtitle: String, icon: String) -> some View {
        Button {
            self.mode = mode
        } label: {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.title2)
                    .frame(width: 32)
                VStack(alignment: .leading, spacing: 2) {
                    Text(title).fontWeight(.medium)
                    Text(subtitle)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                Spacer()
                if self.mode == mode {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.accentColor)
                }
            }
            .padding(12)
            .background(self.mode == mode ? Color.accentColor.opacity(0.1) : Color.gray.opacity(0.05))
            .cornerRadius(8)
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(self.mode == mode ? Color.accentColor : Color.clear, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }

    private var confirmStep: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Review your settings")
                .font(.headline)

            VStack(alignment: .leading, spacing: 8) {
                settingRow("Days", value: selectedDays.sorted { dayOrder($0) < dayOrder($1) }
                    .map(\.capitalized)
                    .joined(separator: ", "))
                settingRow("Hours", value: allDay ? "All day" : "\(startTime) – \(endTime)")
                settingRow("Mode", value: mode.rawValue.capitalized)
            }
            .padding(16)
            .background(Color.gray.opacity(0.05))
            .cornerRadius(8)

            if mode == .extreme {
                Text("Extreme mode: blocking cannot be turned off during scheduled time.")
                    .font(.caption)
                    .foregroundColor(.orange)
            }
        }
    }

    private func settingRow(_ label: String, value: String) -> some View {
        HStack {
            Text(label)
                .foregroundColor(.secondary)
                .frame(width: 60, alignment: .leading)
            Text(value)
                .fontWeight(.medium)
        }
        .font(.system(size: 13))
    }

    // MARK: - Logic

    private func advance() {
        if step == 0 && selectedDays.isEmpty { return }
        step += 1
    }

    private func save() {
        let config = ChiselConfig(
            schedule: ChiselConfig.Schedule(
                days: Array(selectedDays),
                allDay: allDay,
                startTime: allDay ? nil : startTime,
                endTime: allDay ? nil : endTime
            ),
            mode: mode
        )
        ChiselStore.saveConfig(config)
        appState.reload()

        // Install the extension
        ExtensionManager.shared.activate()

        dismiss()
    }

    private func loadExisting() {
        guard let config = appState.config else { return }
        selectedDays = Set(config.schedule.days)
        allDay = config.schedule.allDay
        startTime = config.schedule.startTime ?? "09:00"
        endTime = config.schedule.endTime ?? "17:00"
        mode = config.mode
    }

    private func dayOrder(_ key: String) -> Int {
        switch key {
        case "mon": return 0; case "tue": return 1; case "wed": return 2
        case "thu": return 3; case "fri": return 4; case "sat": return 5
        case "sun": return 6; default: return 7
        }
    }
}
