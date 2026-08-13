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

        // mlx-swift core (the MLX product). Referenced directly so HiveCore can
        // install a global MLX error handler: mlx-c's default handler calls
        // exit(-1) on ANY error (e.g. a missing default.metallib in the app
        // bundle), which would hard-kill the browser. Pinned to the same range
        // mlx-swift-examples 2.29.1 uses (.upToNextMinor 0.29.x) so resolution
        // stays at a single shared version.
        .package(url: "https://github.com/ml-explore/mlx-swift", .upToNextMinor(from: "0.29.1")),

        // Chromium Embedded Framework wrapper for the Chromium-backed browser reset.
        // CefSwift downloads and bundles the CEF binaries via a SwiftPM command plugin.
        // VENDORED at Vendor/CefSwift (MIT, pinned upstream 0.1.0 @ 2dca11e) so the
        // per-request-context scheme handler fix can ship with the product; upstream
        // had no fix for profile-scoped custom schemes (verified 2026-08-07).
        .package(path: "Vendor/CefSwift"),

        // Sparkle 2 — macOS auto-update framework. Powers automatic background
        // update checks and the "Check for Updates…" menu item. Used by Chrome,
        // Firefox, VS Code, and virtually every macOS app outside the App Store.
        .package(url: "https://github.com/sparkle-project/Sparkle", from: "2.6.0"),

    ],
    targets: [
        // The Hive Browser — Chromium-backed via CefSwiftUI, native SwiftUI chrome shell.
        // Built from scratch around CEF 148 (Chromium 148.0.7778.218).
        .executableTarget(
            name: "Hive",
            dependencies: [
                .product(name: "CefSwiftUI", package: "CefSwift"),
                .product(name: "Sparkle", package: "Sparkle"),
                "HiveCore",
            ],
            path: "Sources/Hive",
            // The Rust worker is staged here by scripts/build-research-worker.sh
            // during an app release build. Keep it isolated from icons/source
            // assets; Bundle.module can then address only this helper.
            resources: [
                .copy("Resources/AppIcon.icns"),
                .copy("Resources/ResearchWorker"),
                // Swarm Cell system prompts — only the loader-referenced role
                // subdirectories ship (~492 KB total). The top-level spec/
                // progress files and RESEARCH/ competitor dossiers stay in the
                // repo and out of the bundle. `CellPromptLoader(promptsDir:
                // Bundle.module.resourceURL)` resolves these subdirectories at
                // runtime (see BrowserState.setupAI()).
                .copy("Resources/Swarm_System_Prompts/guard"),
                .copy("Resources/Swarm_System_Prompts/router"),
                .copy("Resources/Swarm_System_Prompts/scribe"),
                .copy("Resources/Swarm_System_Prompts/orchestrator"),
                .copy("Resources/Swarm_System_Prompts/librarian"),
                .copy("Resources/Swarm_System_Prompts/summarizer"),
                .copy("Resources/Swarm_System_Prompts/auditor"),
                .copy("Resources/Swarm_System_Prompts/planner"),
                .copy("Resources/Swarm_System_Prompts/reasoner"),
                .copy("Resources/Swarm_System_Prompts/coder"),
                .copy("Resources/Swarm_System_Prompts/researcher"),
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
                .product(name: "MLX", package: "mlx-swift"),
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
