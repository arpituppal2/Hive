// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "Hive",
    platforms: [.macOS(.v14)],
    products: [
        .executable(name: "Hive", targets: ["Hive"]),
        .library(name: "HiveCore", targets: ["HiveCore"]),
        .executable(name: "HiveChromium", targets: ["HiveChromium"]),
    ],
    dependencies: [
        // On-device inference. Pinned: mlx-swift-examples 2.29.1 pulls mlx-swift core
        // (>= 0.29.1 up-to-next-minor; latest 0.31.x satisfies). HiveCore links MLXLLM
        // (the model registry + trampoline that registers itself with ModelFactoryRegistry
        // so the free `loadModelContainer(directory:)` can build a LanguageModel) and
        // MLXLMCommon (load/generate/UserInput/LoRAContainer). At 2.29.1 the *examples*
        // renamed the old `MLXLlama` product to `MLXLLM` — the public surface the runtime
        // is written against is `LLMModelFactory`/`ModelContainer`/`Chat.Message`, not the
        // removed `loadModel(configuration:adapters:)'. When weights are present the
        // #if canImport(MLXLMCommon) path lights up; until then MLXRuntime honestly falls
        // back to base/Mock (provider-labelled) — never silent, never fake.
        .package(url: "https://github.com/ml-explore/mlx-swift-examples", from: "2.29.1"),

        // Chromium Embedded Framework wrapper for the Chromium-backed browser reset.
        // CefSwift downloads and bundles the CEF binaries via a SwiftPM command plugin.
        // VENDORED at Vendor/CefSwift (MIT, pinned upstream 0.1.0 @ 2dca11e) so the
        // per-request-context scheme handler fix can ship with the product; upstream
        // had no fix for profile-scoped custom schemes (verified 2026-08-07).
        .package(path: "Vendor/CefSwift"),
    ],
    targets: [
        // The original Hive Browser — one macOS product, currently WKWebView-based.
        // Kept buildable while the new HiveChromium target is brought up.
        .executableTarget(
            name: "Hive",
            dependencies: ["HiveCore"],
            path: "Sources/Hive",
            resources: [
                .copy("Resources/Swarm_System_Prompts")
            ]
        ),

        // The new Chromium-backed Hive browser. Built from scratch around CefSwiftUI.
        .executableTarget(
            name: "HiveChromium",
            dependencies: [
                .product(name: "CefSwiftUI", package: "CefSwift"),
                "HiveCore",
            ],
            path: "Sources/HiveChromium",
            // The Rust worker is staged here by scripts/build-research-worker.sh
            // during an app release build. Keep it isolated from icons/source
            // assets; Bundle.module can then address only this helper.
            resources: [
                .copy("Resources/AppIcon.icns"),
                .copy("Resources/ResearchWorker")
            ]
        ),

        // Opt-in developer/runtime smoke target. It is intentionally not exposed
        // as a package product or included in the normal test target: it requires
        // a live macOS window server and launches a real WKWebView process.
        .executableTarget(
            name: "HiveWebKitSmoke",
            path: "Sources/HiveWebKitSmoke"
        ),

        .target(
            name: "HiveCore",
            dependencies: [
                .product(name: "MLXLMCommon", package: "mlx-swift-examples"),
                .product(name: "MLXLLM", package: "mlx-swift-examples"),
            ],
            path: "Sources/HiveCore"
        ),
        .testTarget(
            name: "HiveCoreTests",
            dependencies: ["HiveCore"],
            path: "Tests/HiveCoreTests"
        ),
    ]
)
