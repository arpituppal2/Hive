import Foundation
import Testing
@testable import HiveCore

// MARK: - SafetyCheckPolicyTests

struct SafetyCheckPolicyTests {

    // MARK: Password strength

    @Test func emptyPasswordIsWeak() {
        #expect(SafetyCheckPolicy.passwordIsWeak(""))
    }

    @Test func shortPasswordIsWeak() {
        #expect(SafetyCheckPolicy.passwordIsWeak("hunter"))
        #expect(SafetyCheckPolicy.passwordIsWeak("abcdefg"))
    }

    @Test func boundaryLengthMixedClassesIsStrong() {
        // 8 characters, upper + lower classes.
        #expect(!SafetyCheckPolicy.passwordIsWeak("Abcdef12"))
    }

    @Test func singleClassLongPasswordIsWeak() {
        // Long but one class — still weak.
        #expect(SafetyCheckPolicy.passwordIsWeak("aaaaaaaaaaaa"))
        #expect(SafetyCheckPolicy.passwordIsWeak("123456789012"))
    }

    @Test func symbolOnlyPasswordIsWeak() {
        #expect(SafetyCheckPolicy.passwordIsWeak("!!!!!!"))
    }

    @Test func mixedClassPasswordIsStrong() {
        #expect(!SafetyCheckPolicy.passwordIsWeak("Tr0ub4dor&3"))
        #expect(!SafetyCheckPolicy.passwordIsWeak("c0rrect-h0rse!"))
    }

    @Test func unicodePasswordLengthCountsScalars() {
        // 8 unicode scalars but one class.
        #expect(SafetyCheckPolicy.passwordIsWeak("éééééééé"))
        #expect(!SafetyCheckPolicy.passwordIsWeak("ééééÉÉ12"))
    }

    // MARK: Reuse detection

    @Test func emptyPasswordListHasNoReuse() {
        #expect(SafetyCheckPolicy.reusedPasswordCount(passwords: []) == 0)
    }

    @Test func distinctPasswordsAreNotReused() {
        let passwords = [
            ("a.com", "alpha"),
            ("b.com", "beta"),
            ("c.com", "gamma"),
        ]
        #expect(SafetyCheckPolicy.reusedPasswordCount(passwords: passwords) == 0)
    }

    @Test func reusedAcrossTwoSitesCountsOnce() {
        let passwords = [
            ("a.com", "shared"),
            ("b.com", "shared"),
        ]
        #expect(SafetyCheckPolicy.reusedPasswordCount(passwords: passwords) == 1)
    }

    @Test func reusedAcrossThreeSitesStillCountsOnce() {
        let passwords = [
            ("a.com", "shared"),
            ("b.com", "shared"),
            ("c.com", "shared"),
        ]
        #expect(SafetyCheckPolicy.reusedPasswordCount(passwords: passwords) == 1)
    }

    @Test func multipleReusedValuesCountIndividually() {
        let passwords = [
            ("a.com", "s1"),
            ("b.com", "s1"),
            ("c.com", "s2"),
            ("d.com", "s2"),
            ("e.com", "unique"),
        ]
        #expect(SafetyCheckPolicy.reusedPasswordCount(passwords: passwords) == 2)
    }

    @Test func emptyPasswordsAreIgnoredForReuse() {
        let passwords = [
            ("a.com", ""),
            ("b.com", ""),
        ]
        #expect(SafetyCheckPolicy.reusedPasswordCount(passwords: passwords) == 0)
    }

    @Test func reuseMatchingIsCaseSensitive() {
        // Different case = different password; same exact value = reuse.
        let passwords = [
            ("a.com", "Alpha"),
            ("b.com", "alpha"),
        ]
        #expect(SafetyCheckPolicy.reusedPasswordCount(passwords: passwords) == 0)
        #expect(SafetyCheckPolicy.reusedPasswordCount(passwords: [("a.com", "Alpha"), ("b.com", "Alpha")]) == 1)
    }

    // MARK: Report assembly

    @Test func allClearReportIsAllPassInChromeOrder() {
        let items = SafetyCheckPolicy.report(
            passwords: [("a.com", "Tr0ub4dor&3")],
            safeBrowsingConfigured: true,
            extensionCount: 0,
            canCheckForUpdates: true,
            notificationGrantCount: 0,
            httpsOnlyEnabled: true
        )
        #expect(items.map(\.kind.rawValue) == ["passwords", "safeBrowsing", "extensions", "updates", "permissions", "https"])
        #expect(items.allSatisfy { $0.status == .pass })
    }

    @Test func emptyPasswordStoreReportsPassWithCopy() {
        let items = SafetyCheckPolicy.report(
            passwords: [],
            safeBrowsingConfigured: true,
            extensionCount: 0,
            canCheckForUpdates: true,
            notificationGrantCount: 0,
            httpsOnlyEnabled: true
        )
        let passwordsRow = items.first { $0.kind == .passwords }
        #expect(passwordsRow?.status == .pass)
        #expect(passwordsRow?.title == "No saved passwords")
    }

    @Test func weakAndReusedPasswordsWarn() {
        let items = SafetyCheckPolicy.report(
            passwords: [
                ("a.com", "short"),
                ("b.com", "sharedPass"),
                ("c.com", "sharedPass"),
            ],
            safeBrowsingConfigured: true,
            extensionCount: 0,
            canCheckForUpdates: true,
            notificationGrantCount: 0,
            httpsOnlyEnabled: true
        )
        let row = items.first { $0.kind == .passwords }
        #expect(row?.status == .warn)
        #expect(row?.title == "Review your passwords")
        #expect(row?.detail.contains("1 weak") == true)
        #expect(row?.detail.contains("1 reused") == true)
    }

    @Test func onlyWeakPasswordWarnsSingularCopy() {
        let items = SafetyCheckPolicy.report(
            passwords: [("a.com", "hunter")],
            safeBrowsingConfigured: true,
            extensionCount: 0,
            canCheckForUpdates: true,
            notificationGrantCount: 0,
            httpsOnlyEnabled: true
        )
        let row = items.first { $0.kind == .passwords }
        #expect(row?.status == .warn)
        #expect(row?.detail.contains("1 weak password") == true)
    }

    @Test func safeBrowsingUnconfiguredWarns() {
        let items = SafetyCheckPolicy.report(
            passwords: [("a.com", "Tr0ub4dor&3")],
            safeBrowsingConfigured: false,
            extensionCount: 0,
            canCheckForUpdates: true,
            notificationGrantCount: 0,
            httpsOnlyEnabled: true
        )
        let row = items.first { $0.kind == .safeBrowsing }
        #expect(row?.status == .warn)
        #expect(row?.title == "Safe Browsing isn't set up")
    }

    @Test func extensionsPresentReportInfo() {
        let items = SafetyCheckPolicy.report(
            passwords: [],
            safeBrowsingConfigured: true,
            extensionCount: 3,
            canCheckForUpdates: true,
            notificationGrantCount: 0,
            httpsOnlyEnabled: true
        )
        let row = items.first { $0.kind == .extensions }
        #expect(row?.status == .info)
        #expect(row?.title == "3 extensions installed")
    }

    @Test func noUpdateFeedReportsInfo() {
        let items = SafetyCheckPolicy.report(
            passwords: [],
            safeBrowsingConfigured: true,
            extensionCount: 0,
            canCheckForUpdates: false,
            notificationGrantCount: 0,
            httpsOnlyEnabled: true
        )
        let row = items.first { $0.kind == .updates }
        #expect(row?.status == .info)
        #expect(row?.title == "Automatic updates aren't configured")
    }

    @Test func notificationGrantsReportInfo() {
        let items = SafetyCheckPolicy.report(
            passwords: [],
            safeBrowsingConfigured: true,
            extensionCount: 0,
            canCheckForUpdates: true,
            notificationGrantCount: 2,
            httpsOnlyEnabled: true
        )
        let row = items.first { $0.kind == .permissions }
        #expect(row?.status == .info)
        #expect(row?.title == "2 sites can send notifications")
    }

    @Test func httpsOnlyOffReportsInfo() {
        let items = SafetyCheckPolicy.report(
            passwords: [],
            safeBrowsingConfigured: true,
            extensionCount: 0,
            canCheckForUpdates: true,
            notificationGrantCount: 0,
            httpsOnlyEnabled: false
        )
        let row = items.first { $0.kind == .https }
        #expect(row?.status == .info)
        #expect(row?.title == "Always use secure connections is off")
    }

    @Test func reportIdsAreStableKinds() {
        let items = SafetyCheckPolicy.report(
            passwords: [],
            safeBrowsingConfigured: true,
            extensionCount: 0,
            canCheckForUpdates: true,
            notificationGrantCount: 0,
            httpsOnlyEnabled: true
        )
        #expect(Set(items.map(\.id)).count == items.count)
    }
}
