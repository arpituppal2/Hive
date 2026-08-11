import Foundation
import Testing
@testable import HiveCore

@Suite("PasswordGenerator")
struct PasswordGeneratorTests {

    /// Deterministic, seedable RNG for reproducibility (SplitMix64).
    private struct SeededGenerator: RandomNumberGenerator {
        private var state: UInt64
        init(seed: UInt64) { state = seed }
        mutating func next() -> UInt64 {
            state &+= 0x9E3779B97F4A7C15
            var z = state
            z = (z ^ (z >> 30)) &* 0xBF58476D1CE4E5B9
            z = (z ^ (z >> 27)) &* 0x94D049BB133111EB
            return z ^ (z >> 31)
        }
    }

    private func generated(seed: UInt64, options: PasswordGenerator.Options = .init()) -> String {
        var random = SeededGenerator(seed: seed)
        return PasswordGenerator.generate(options: options, using: &random)
    }

    @Test func respectsRequestedLength() {
        for length in [8, 12, 20, 32] {
            #expect(generated(seed: 1, options: .init(length: length)).count == length)
        }
    }

    @Test func clampsLengthToBrowserRange() {
        #expect(generated(seed: 1, options: .init(length: 4)).count == 8)
        #expect(generated(seed: 1, options: .init(length: 80)).count == 64)
    }

    @Test func guaranteesEveryCharacterClass() {
        for seed in UInt64(1)...30 {
            let password = generated(seed: seed)
            #expect(password.contains { PasswordGenerator.lowercase.contains($0) })
            #expect(password.contains { PasswordGenerator.uppercase.contains($0) })
            #expect(password.contains { PasswordGenerator.digits.contains($0) })
            #expect(password.contains { PasswordGenerator.symbols.contains($0) })
        }
    }

    @Test func excludesAmbiguousCharacters() {
        let ambiguous = Set("0O1lI")
        for seed in UInt64(1)...30 {
            let password = generated(seed: seed)
            #expect(password.allSatisfy { !ambiguous.contains($0) })
        }
    }

    @Test func omitsSymbolsWhenDisabled() {
        let password = generated(seed: 7, options: .init(length: 24, includeSymbols: false))
        #expect(!password.contains { PasswordGenerator.symbols.contains($0) })
        #expect(password.count == 24)
    }

    @Test func differentSeedsProduceDifferentPasswords() {
        let a = generated(seed: 1)
        let b = generated(seed: 2)
        #expect(a != b)
    }

    @Test func sameSeedProducesSamePassword() {
        #expect(generated(seed: 42) == generated(seed: 42))
    }

    @Test func generatedPasswordsAreShuffledNotPredictablyPrefixed() {
        // The guaranteed classes are shuffled in; a large batch should never
        // all begin with the same class of character.
        var firsts = Set<Character>()
        for seed in UInt64(1)...50 {
            let password = generated(seed: seed)
            #expect(!password.isEmpty)
            firsts.insert(password.first!)
        }
        #expect(firsts.count > 1)
    }

    @Test func systemGeneratorProducesUsablePasswords() {
        for _ in 0..<20 {
            let password = PasswordGenerator.generate(options: .init(length: 16))
            #expect(password.count == 16)
            #expect(password.contains { PasswordGenerator.lowercase.contains($0) })
            #expect(password.contains { PasswordGenerator.uppercase.contains($0) })
            #expect(password.contains { PasswordGenerator.digits.contains($0) })
        }
    }
}

@Suite("CredentialSitePolicy")
struct CredentialSitePolicyTests {

    @Test func stripsSchemePathAndQuery() {
        #expect(CredentialSitePolicy.normalize("https://Example.com/path?q=1#frag") == "example.com")
        #expect(CredentialSitePolicy.normalize("http://github.com/user/repo") == "github.com")
    }

    @Test func handlesBareHosts() {
        #expect(CredentialSitePolicy.normalize("github.com") == "github.com")
        #expect(CredentialSitePolicy.normalize("Example.COM/login") == "example.com")
    }

    @Test func stripsCredentialsAndPort() {
        #expect(CredentialSitePolicy.normalize("https://user:pass@example.com:8080/x") == "example.com")
    }

    @Test func trailingDotIsEquivalent() {
        #expect(CredentialSitePolicy.normalize("example.com.") == "example.com")
        #expect(CredentialSitePolicy.normalize("EXAMPLE.COM.") == "example.com")
    }

    @Test func trimsWhitespaceAndRejectsEmpty() {
        #expect(CredentialSitePolicy.normalize("  ") == "")
        #expect(CredentialSitePolicy.normalize("") == "")
        #expect(CredentialSitePolicy.normalize("  Example.com  ") == "example.com")
    }
}
