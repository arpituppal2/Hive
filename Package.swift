// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "Hive",
    platforms: [.macOS(.v14)],
    products: [
        .executable(name: "Hive", targets: ["Hive"]),
        .library(name: "HiveCore", targets: ["HiveCore"]),
    ],
    dependencies: [
        // Vendored CEF wrapper (MIT, pinned upstream 0.1.0 @ 2dca11e) with the
        // per-request-context scheme-handler replay fix. See docs/SALVAGE-MANIFEST.md.
        .package(path: "Vendor/CefSwift"),
    ],
    targets: [
        // Platform-agnostic wedge core: models, capture store (SQLite+FTS5),
        // span splitter, retrieval, grounded-ask engine, provider abstraction.
        .target(
            name: "HiveCore",
            linkerSettings: [.linkedLibrary("sqlite3")]
        ),
        // The browser app: CEF shell + web chrome bridge. One chrome layer.
        .executableTarget(
            name: "Hive",
            dependencies: [
                .product(name: "CefKit", package: "CefSwift"),
                .product(name: "CefSwiftUI", package: "CefSwift"),
                "HiveCore",
            ],
            path: "Sources/Hive",
            resources: [
                .copy("WebChrome"),
                .copy("Resources/Readability.js"),
            ]
        ),
        .testTarget(
            name: "HiveCoreTests",
            dependencies: ["HiveCore"],
            path: "Tests/HiveCoreTests"
        ),
    ]
)
