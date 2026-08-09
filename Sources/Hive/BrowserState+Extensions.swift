//
//  BrowserState+Extensions.swift
//  Hive
//
//  Carved out of BrowserState.swift by scripts/split_browser_state.py.
//  Pure extension split, no behavior change. Access was widened from
//  `private`/`private(set)` to internal so the cross-file extensions
//  compile; this app target has no external API surface.
//
//  Sections: - Extensions
//

import SwiftUI
import Observation
import CefSwiftUI
import CefKit
import HiveCore
import AppKit


// MARK: - BrowserState + Extensions

@MainActor
extension BrowserState {


    // MARK: - Extensions

    func toggleExtensionPin(id: UUID) {
        guard let index = installedExtensions.firstIndex(where: { $0.id == id }) else { return }
        installedExtensions[index].isPinned.toggle()
    }


    func toggleExtensionEnabled(id: UUID) {
        guard let index = installedExtensions.firstIndex(where: { $0.id == id }) else { return }
        installedExtensions[index].isEnabled.toggle()
    }


    /// Install an extension from its unpacked folder (must contain manifest.json).
    /// Validates the manifest, extracts metadata, and copies the extension into
    /// the Hive extensions directory. Returns the new ExtensionItem on success.
    func installExtension(from folderURL: URL) -> ExtensionItem? {
        let manifestURL = folderURL.appendingPathComponent("manifest.json")
        guard FileManager.default.fileExists(atPath: manifestURL.path),
              let data = try? Data(contentsOf: manifestURL),
              let manifest = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
        else { return nil }

        let name = (manifest["name"] as? String) ?? folderURL.lastPathComponent
        // manifest["version"] is the extension version; manifest["manifest_version"] is the format version (2 or 3)
        let version = (manifest["version"] as? String) ?? "1.0"
        let desc = (manifest["description"] as? String) ?? ""
        var iconName = "puzzlepiece.extension"
        if let browserAction = manifest["browser_action"] as? [String: Any] {
            iconName = "square.grid.2x2"
        } else if let pageAction = manifest["page_action"] as? [String: Any] {
            iconName = "rectangle.on.rectangle"
        } else if let permissions = manifest["permissions"] as? [String],
                  permissions.contains(where: { $0 == "activeTab" || $0.hasPrefix("http") }) {
            iconName = "globe"
        }

        // Copy extension into Hive's app support directory
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let extensionsDir = appSupport.appendingPathComponent("Hive/Extensions", isDirectory: true)
        try? FileManager.default.createDirectory(at: extensionsDir, withIntermediateDirectories: true)

        let destDir = extensionsDir.appendingPathComponent(name.replacingOccurrences(of: " ", with: "_"))
        try? FileManager.default.removeItem(at: destDir)

        do {
            try FileManager.default.copyItem(at: folderURL, to: destDir)
        } catch {
            return nil // Copy failed — don't register the extension
        }

        let item = ExtensionItem(
            name: name,
            iconName: iconName,
            isPinned: true,
            isEnabled: true,
            version: version,
            description: desc,
            manifestPath: destDir.appendingPathComponent("manifest.json").path
        )
        installedExtensions.append(item)
        return item
    }


    /// Uninstall an extension by ID, removing it from the extensions directory.
    func uninstallExtension(id: UUID) {
        guard let index = installedExtensions.firstIndex(where: { $0.id == id }) else { return }
        let ext = installedExtensions[index]
        if let manifestPath = ext.manifestPath {
            let extDir = URL(fileURLWithPath: manifestPath).deletingLastPathComponent()
            try? FileManager.default.removeItem(at: extDir)
        }
        installedExtensions.remove(at: index)
    }
}
