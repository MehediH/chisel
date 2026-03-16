import Foundation
import SystemExtensions
import os.log

class ExtensionManager: NSObject, OSSystemExtensionRequestDelegate {
    static let shared = ExtensionManager()

    private let logger = Logger(subsystem: "cotl.chisel.app", category: "extension")
    private var activationCompletion: ((Bool) -> Void)?

    func activate(completion: ((Bool) -> Void)? = nil) {
        activationCompletion = completion
        let request = OSSystemExtensionRequest.activationRequest(
            forExtensionWithIdentifier: ChiselConstants.extensionBundleID,
            queue: .main
        )
        request.delegate = self
        OSSystemExtensionManager.shared.submitRequest(request)
        logger.info("Submitted extension activation request")
    }

    func deactivate(completion: ((Bool) -> Void)? = nil) {
        activationCompletion = completion
        let request = OSSystemExtensionRequest.deactivationRequest(
            forExtensionWithIdentifier: ChiselConstants.extensionBundleID,
            queue: .main
        )
        request.delegate = self
        OSSystemExtensionManager.shared.submitRequest(request)
        logger.info("Submitted extension deactivation request")
    }

    // MARK: - OSSystemExtensionRequestDelegate

    func request(_ request: OSSystemExtensionRequest,
                 didFinishWithResult result: OSSystemExtensionRequest.Result) {
        logger.info("Extension request finished: \(result.rawValue)")
        switch result {
        case .completed:
            activationCompletion?(true)
        case .willCompleteAfterReboot:
            logger.info("Extension will complete after reboot")
            activationCompletion?(false)
        @unknown default:
            activationCompletion?(false)
        }
        activationCompletion = nil
    }

    func request(_ request: OSSystemExtensionRequest,
                 didFailWithError error: Error) {
        logger.error("Extension request failed: \(error.localizedDescription)")
        activationCompletion?(false)
        activationCompletion = nil
    }

    func requestNeedsUserApproval(_ request: OSSystemExtensionRequest) {
        logger.info("Extension needs user approval — opening System Settings")
    }

    func request(_ request: OSSystemExtensionRequest,
                 actionForReplacingExtension existing: OSSystemExtensionProperties,
                 withExtension ext: OSSystemExtensionProperties) -> OSSystemExtensionRequest.ReplacementAction {
        logger.info("Replacing existing extension \(existing.bundleVersion) with \(ext.bundleVersion)")
        return .replace
    }
}
