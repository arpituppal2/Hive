// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "Hive",
    platforms: [
        .macOS(.v14),
        .iOS(.v17),
        .watchOS(.v10)
    ],
    products: [
        .library(name: "HiveCore", targets: ["HiveCore"]),
        .library(name: "HiveMetalRenderer", targets: ["HiveMetalRenderer"]),
        .library(name: "HiveDesignSystem", targets: ["HiveDesignSystem"]),
        .library(name: "HiveUI", targets: ["HiveUI"]),
        .library(name: "HiveMacApp", targets: ["HiveMacApp"]),
        .library(name: "HiveMobileApp", targets: ["HiveMobileApp"]),
        .library(name: "HiveWatchApp", targets: ["HiveWatchApp"]),
        .library(name: "HiveWidgets", targets: ["HiveWidgets"]),
        .executable(name: "HiveApp", targets: ["HiveApp"]),
        .executable(name: "HiveDaemon", targets: ["HiveDaemon"])
    ],
    dependencies: [
        .package(url: "https://github.com/ml-explore/mlx-swift-lm", .upToNextMajor(from: "3.31.3")),
        .package(url: "https://github.com/huggingface/swift-huggingface", from: "0.9.0"),
        .package(url: "https://github.com/huggingface/swift-transformers", from: "1.3.0")
    ],
    targets: [
        .target(
            name: "HiveCore",
            dependencies: [
                .product(name: "MLXLLM", package: "mlx-swift-lm", condition: .when(platforms: [.macOS])),
                .product(name: "MLXLMCommon", package: "mlx-swift-lm", condition: .when(platforms: [.macOS])),
                .product(name: "MLXHuggingFace", package: "mlx-swift-lm", condition: .when(platforms: [.macOS])),
                .product(name: "HuggingFace", package: "swift-huggingface", condition: .when(platforms: [.macOS])),
                .product(name: "Tokenizers", package: "swift-transformers", condition: .when(platforms: [.macOS]))
            ],
            linkerSettings: [
                .linkedLibrary("sqlite3")
            ]
        ),
        .target(
            name: "HiveDesignSystem",
            dependencies: ["HiveCore"],
            resources: [
                .process("Resources")
            ]
        ),
        .target(
            name: "HiveMetalRenderer",
            dependencies: ["HiveDesignSystem"],
            resources: [
                .process("Resources")
            ]
        ),
        .target(
            name: "HiveUI",
            dependencies: ["HiveCore", "HiveDesignSystem", "HiveMetalRenderer"]
        ),
        .target(
            name: "HiveMacApp",
            dependencies: ["HiveCore", "HiveDesignSystem", "HiveMetalRenderer", "HiveUI"],
            path: "Sources/HiveMacApp",
            sources: [
                "HiveAppKitGraphSurface.swift",
                "HiveGraphCanvasView.swift",
                "HiveMacRootView.swift",
                "HiveMacWindowPresenter.swift"
            ]
        ),
        .target(
            name: "HiveMobileApp",
            dependencies: ["HiveCore", "HiveDesignSystem", "HiveUI"],
            resources: [
                .process("Resources")
            ]
        ),
        .target(
            name: "HiveWatchApp",
            dependencies: ["HiveCore", "HiveDesignSystem"],
            resources: [
                .process("Resources")
            ]
        ),
        .target(
            name: "HiveWidgets",
            dependencies: ["HiveCore", "HiveDesignSystem"]
        ),
        .executableTarget(
            name: "HiveApp",
            dependencies: ["HiveMacApp"],
            resources: [
                .process("Resources")
            ]
        ),
        .executableTarget(
            name: "HiveDaemon",
            dependencies: ["HiveCore"]
        ),
        .testTarget(
            name: "HiveCoreTests",
            dependencies: ["HiveCore"]
        ),
        .testTarget(
            name: "HiveRebuildTests",
            dependencies: ["HiveCore", "HiveDesignSystem", "HiveMetalRenderer", "HiveUI", "HiveWidgets", "HiveMobileApp", "HiveWatchApp"]
        )
    ]
)
