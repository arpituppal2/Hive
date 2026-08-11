import Foundation
import Security

/// Runtime CloudKit configuration shared by BrowserState sync and the AppKit
/// notification delegate. CloudKit is deliberately opt-in: a plist key alone
/// is insufficient because hand-packed bundles can omit the corresponding
/// signed iCloud entitlement.
public enum CloudKitConfiguration {
    public static let containerInfoKey = "CloudKitContainerIdentifier"
    public static let containerEntitlementKey = "com.apple.developer.icloud-container-identifiers"
    public static let servicesEntitlementKey = "com.apple.developer.icloud-services"

    public static func configuredContainer(in bundle: Bundle = .main) -> String? {
        guard let raw = bundle.object(forInfoDictionaryKey: containerInfoKey) as? String else {
            return nil
        }
        let identifier = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard identifier.range(of: #"^iCloud\.[A-Za-z0-9._-]+$"#, options: .regularExpression) != nil,
              signedEntitlementArray(containerEntitlementKey).contains(identifier),
              signedEntitlementArray(servicesEntitlementKey).contains("CloudKit") else {
            return nil
        }
        return identifier
    }

    private static func signedEntitlementArray(_ key: String) -> [String] {
        guard let task = SecTaskCreateFromSelf(nil),
              let value = SecTaskCopyValueForEntitlement(task, key as CFString, nil) else {
            return []
        }
        return (value as? [String]) ?? []
    }
}
