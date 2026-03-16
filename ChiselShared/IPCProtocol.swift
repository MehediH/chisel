import Foundation

/// Protocol for messages from the app to the filter extension.
@objc protocol AppToFilterProtocol {
    func updateConfig()
    func getStatus(reply: @escaping (Bool) -> Void)
}

/// Protocol for messages from the filter extension to the app.
@objc protocol FilterToAppProtocol {
    func filterDidBlock(processName: String, destination: String)
    func filterStatusChanged(isFiltering: Bool)
}
