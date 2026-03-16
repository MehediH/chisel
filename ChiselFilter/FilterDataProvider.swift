import NetworkExtension
import os.log

class FilterDataProvider: NEFilterDataProvider {

    private let logger = Logger(subsystem: "cotl.chisel.filter", category: "filter")

    // MARK: - Filter Lifecycle

    override func startFilter(completionHandler: @escaping (Error?) -> Void) {
        logger.info("Starting Chisel network filter")

        // Filter all outbound TCP and UDP (IPv4 + IPv6)
        let filterRules: [NEFilterRule] = [
            NEFilterRule(networkRule: NENetworkRule(
                remoteNetwork: NWHostEndpoint(hostname: "0.0.0.0", port: "0"),
                remotePrefix: 0,
                localNetwork: nil,
                localPrefix: 0,
                protocol: .TCP,
                direction: .outbound
            ), action: .filterData),
            NEFilterRule(networkRule: NENetworkRule(
                remoteNetwork: NWHostEndpoint(hostname: "0.0.0.0", port: "0"),
                remotePrefix: 0,
                localNetwork: nil,
                localPrefix: 0,
                protocol: .UDP,
                direction: .outbound
            ), action: .filterData),
            NEFilterRule(networkRule: NENetworkRule(
                remoteNetwork: NWHostEndpoint(hostname: "::", port: "0"),
                remotePrefix: 0,
                localNetwork: nil,
                localPrefix: 0,
                protocol: .TCP,
                direction: .outbound
            ), action: .filterData),
            NEFilterRule(networkRule: NENetworkRule(
                remoteNetwork: NWHostEndpoint(hostname: "::", port: "0"),
                remotePrefix: 0,
                localNetwork: nil,
                localPrefix: 0,
                protocol: .UDP,
                direction: .outbound
            ), action: .filterData),
        ]

        let filterSettings = NEFilterSettings(rules: filterRules, defaultAction: .allow)
        apply(filterSettings) { error in
            if let error = error {
                self.logger.error("Failed to apply filter rules: \(error.localizedDescription)")
            } else {
                self.logger.info("Filter rules applied successfully")
            }
            completionHandler(nil)
        }
    }

    override func stopFilter(with reason: NEProviderStopReason, completionHandler: @escaping () -> Void) {
        logger.info("Stopping filter, reason: \(String(describing: reason))")
        completionHandler()
    }

    // MARK: - Flow Handling

    override func handleNewFlow(_ flow: NEFilterFlow) -> NEFilterNewFlowVerdict {
        // Check if blocking is currently active
        guard shouldBlock() else {
            return .allow()
        }

        // Get the source process path from the audit token
        guard let path = executablePath(from: flow) else {
            return .allow()
        }

        // Check if this process is in our blocklist
        if ChiselProcessList.isBlocked(executablePath: path) {
            if let toolName = ChiselProcessList.matchedToolName(executablePath: path) {
                logger.info("Blocked connection from \(toolName) (\(path))")
            }
            return .drop()
        }

        return .allow()
    }

    // MARK: - Private

    private func shouldBlock() -> Bool {
        guard let config = ChiselStore.loadConfig() else { return false }
        let state = ChiselStore.loadState()
        // Blocking is active if the state says so AND we're in the schedule window
        return state.filterActive && ScheduleEvaluator.isBlockedNow(config: config)
    }

    private func executablePath(from flow: NEFilterFlow) -> String? {
        guard let auditTokenData = flow.sourceAppAuditToken else { return nil }

        return auditTokenData.withUnsafeBytes { (ptr: UnsafeRawBufferPointer) -> String? in
            guard ptr.count == MemoryLayout<audit_token_t>.size else { return nil }
            let token = ptr.load(as: audit_token_t.self)
            let pid = audit_token_to_pid(token)

            // Use proc_pidpath to get the executable path
            let pathBuffer = UnsafeMutablePointer<CChar>.allocate(capacity: Int(MAXPATHLEN))
            defer { pathBuffer.deallocate() }

            let pathLength = proc_pidpath(pid, pathBuffer, UInt32(MAXPATHLEN))
            guard pathLength > 0 else { return nil }

            return String(cString: pathBuffer)
        }
    }
}
