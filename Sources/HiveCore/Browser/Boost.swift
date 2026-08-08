//
//  Boost.swift
//  HiveCore
//
//  A Boost is a per-site customization: custom CSS, JavaScript, force‑dark‑mode,
//  and element zaps.  Users create Boosts to make any site look and behave
//  exactly the way they want.  This is Hive's answer to Arc Boosts / Zen Boosts.
//
//  Each Boost targets a URL pattern (e.g. "*.github.com") so injections happen
//  only on matching pages.
//

import Foundation

// MARK: - Boost

public struct Boost: Sendable, Codable, Identifiable, Equatable, Hashable {
    public let id: String
    public var name: String
    /// A simple glob/pattern for matching URLs, e.g. "*.github.com" or "mail.google.com"
    public var urlPattern: String
    /// Custom CSS injected into every matching page
    public var css: String
    /// Custom JavaScript injected at document-end
    public var js: String
    /// Force a dark-mode colour inversion on this site
    public var forceDarkMode: Bool
    /// CSS selectors of elements the user has "zapped" (hidden)
    public var zappedSelectors: [String]
    /// User-visible on/off toggle
    public var isEnabled: Bool
    public let createdAt: Date
    public var updatedAt: Date

    // MARK: Init

    public init(
        id: String = UUID().uuidString,
        name: String,
        urlPattern: String,
        css: String = "",
        js: String = "",
        forceDarkMode: Bool = false,
        zappedSelectors: [String] = [],
        isEnabled: Bool = true,
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.name = name
        self.urlPattern = urlPattern
        self.css = css
        self.js = js
        self.forceDarkMode = forceDarkMode
        self.zappedSelectors = zappedSelectors
        self.isEnabled = isEnabled
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    // MARK: Codable

    enum CodingKeys: String, CodingKey {
        case id, name, urlPattern, css, js, forceDarkMode, zappedSelectors,
             isEnabled, createdAt, updatedAt
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(String.self, forKey: .id)
        name = try c.decode(String.self, forKey: .name)
        urlPattern = try c.decodeIfPresent(String.self, forKey: .urlPattern) ?? "*"
        css = try c.decodeIfPresent(String.self, forKey: .css) ?? ""
        js = try c.decodeIfPresent(String.self, forKey: .js) ?? ""
        forceDarkMode = try c.decodeIfPresent(Bool.self, forKey: .forceDarkMode) ?? false
        zappedSelectors = try c.decodeIfPresent([String].self, forKey: .zappedSelectors) ?? []
        isEnabled = try c.decodeIfPresent(Bool.self, forKey: .isEnabled) ?? true
        createdAt = try c.decodeIfPresent(Date.self, forKey: .createdAt) ?? Date()
        updatedAt = try c.decodeIfPresent(Date.self, forKey: .updatedAt) ?? Date()
    }
}

// MARK: - URL Matching

extension Boost {
    /// Returns true if `url` matches this Boost's `urlPattern`.
    ///
    /// Supports simple globs:
    ///   - `"*"` matches everything
    ///   - `"*.example.com"` matches any subdomain of example.com
    ///   - `"example.com"` matches exactly example.com (and its subdomains)
    ///   - `"example.com/path/*"` matches path prefixes
    public func matches(_ url: URL) -> Bool {
        guard let host = url.host?.lowercased() else { return false }
        let pattern = urlPattern.lowercased()

        // Wildcard — matches everything
        if pattern == "*" { return true }

        // Split into host and optional path pattern
        let parts = pattern.split(separator: "/", maxSplits: 1, omittingEmptySubsequences: false)
        let hostPattern = String(parts[0])

        // Check host match
        let hostMatch: Bool
        if hostPattern.hasPrefix("*.") {
            let suffix = String(hostPattern.dropFirst(2))
            hostMatch = host == suffix || host.hasSuffix("." + suffix)
        } else {
            hostMatch = host == hostPattern || host.hasSuffix("." + hostPattern)
        }

        guard hostMatch else { return false }

        // If there's a path pattern, check it
        if parts.count > 1, !parts[1].isEmpty {
            let pathPattern = "/" + parts[1]
            let pagePath = url.path
            if pathPattern.hasSuffix("*") {
                let prefix = String(pathPattern.dropLast())
                return pagePath.hasPrefix(prefix)
            } else {
                return pagePath == pathPattern
            }
        }

        return true
    }
}

// MARK: - BoostCollection

/// A Sendable container so we can hold `[Boost]` in an actor store.
public struct BoostCollection: Sendable, Codable {
    public var boosts: [Boost]

    public init(boosts: [Boost] = []) {
        self.boosts = boosts
    }
}
