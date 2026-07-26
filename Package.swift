// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "Hive",
    platforms: [.macOS(.v14)],
    products: [
        .executable(name: "Hive", targets: ["Hive"]),
        .library(name: "HiveCore", targets: ["HiveCore"]),
    ],
    targets: [
        // The Hive Browser — one macOS product.
        // Swarm lives inside Hive as an internal module/runtime surface, not a separate app.
        .executableTarget(
            name: "Hive",
            dependencies: ["HiveCore"],
            path: "Sources/Hive"
        ),
        .target(
            name: "HiveCore",
            path: "Sources/HiveCore"
        ),
        .testTarget(
            name: "HiveCoreTests",
            dependencies: ["HiveCore"],
            path: "Tests/HiveCoreTests"
        ),
    ]
)
