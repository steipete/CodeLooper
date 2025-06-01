import ProjectDescription
import ProjectDescriptionHelpers

// Test CI build trigger

let project = Project(
    name: "CodeLooper",
    organizationName: "Anantus Machina",
    options: .options(
        textSettings: .textSettings(
            usesTabs: false,
            indentWidth: 4,
            tabWidth: 4,
            wrapsLines: true
        )
    ),
    packages: [
        .remote(url: "https://github.com/sindresorhus/Defaults", requirement: .upToNextMajor(from: "9.0.2")),
        .remote(url: "https://github.com/siteline/SwiftUI-Introspect.git", requirement: .upToNextMajor(from: "0.9.0")),
        .remote(url: "https://github.com/apple/swift-log.git", requirement: .upToNextMajor(from: "1.5.0")),
        .remote(url: "https://github.com/sindresorhus/LaunchAtLogin", requirement: .upToNextMajor(from: "5.0.0")),
        .remote(
            url: "https://github.com/kishikawakatsumi/KeychainAccess.git",
            requirement: .upToNextMajor(from: "4.2.2")
        ),
        .remote(url: "https://github.com/sparkle-project/Sparkle.git", requirement: .upToNextMajor(from: "2.0.0")),
        .remote(url: "https://github.com/sindresorhus/KeyboardShortcuts", requirement: .upToNextMajor(from: "2.0.0")),
        .remote(url: "https://github.com/orchetect/MenuBarExtraAccess.git", requirement: .upToNextMajor(from: "1.2.1")),
        .remote(url: "https://github.com/MacPaw/OpenAI", requirement: .upToNextMajor(from: "0.3.0")),
        .remote(url: "https://github.com/loopwork-ai/ollama-swift", requirement: .upToNextMajor(from: "1.0.0")),
        .remote(url: "https://github.com/airbnb/lottie-ios", requirement: .upToNextMajor(from: "4.5.0")),
        .remote(url: "https://github.com/apple/swift-testing.git", requirement: .upToNextMajor(from: "0.12.0")),
        .local(path: "AXorcist"),
        .local(path: "AXpector"),
        .local(path: "DesignSystem"),
        .local(path: "/Users/steipete/Projects/Demark"),
    ],
    settings: .settings(
        base: [
            "MACOSX_DEPLOYMENT_TARGET": "14.0",
            "SWIFT_VERSION": "6.0",
            "CODE_SIGN_IDENTITY": "Apple Development",
            "CODE_SIGN_STYLE": "Automatic",
            "OTHER_SWIFT_FLAGS": "-strict-concurrency=complete",
            // Enable modern build security measures
            "ENABLE_USER_SCRIPT_SANDBOXING": "YES",
            // Enable Hardened Runtime for Apple notarization
            "ENABLE_HARDENED_RUNTIME": "YES",
            // Enable Asset Symbol Extensions
            "ASSETCATALOG_COMPILER_GENERATE_SWIFT_ASSET_SYMBOL_EXTENSIONS": "YES",
            // Enable modern build security measures
            "ENABLE_STRICT_CONCURRENCY_CHECKS": "YES",
        ],
        configurations: [
            .debug(name: "Debug", settings: [
                "OTHER_SWIFT_FLAGS": "$(inherited) -warn-concurrency -enable-actor-data-race-checks",
                "ENABLE_HARDENED_RUNTIME": "YES",
            ]),
            .release(name: "Release", settings: [:]),
        ],
        defaultSettings: .recommended
    ),
    targets: [
        .target(
            name: "Diagnostics",
            destinations: [.mac],
            product: .staticFramework,
            bundleId: "me.steipete.codelooper.Diagnostics",
            deploymentTargets: .macOS("14.0"),
            sources: ["Core/Diagnostics/**"],
            dependencies: [
                .package(product: "Logging"),
                .package(product: "AXorcist"),
            ],
            settings: .settings(
                base: [
                    "SWIFT_VERSION": "6.0",
                    "MACOSX_DEPLOYMENT_TARGET": "14.0",
                    "OTHER_SWIFT_FLAGS": "-strict-concurrency=complete",
                    "ENABLE_STRICT_CONCURRENCY_CHECKS": "YES",
                    "CLANG_ENABLE_MODULE_DEBUGGING": "YES",
                ]
            )
        ),
        .target(
            name: "CodeLooper",
            destinations: [.mac],
            product: .app,
            bundleId: "me.steipete.codelooper",
            deploymentTargets: .macOS("14.0"),
            infoPlist: .file(path: "App/Info.plist"),
            sources: [
                "App/**",
                "Features/**",
                "Core/**",
            ],
            resources: [
                "Resources/CodeLooper.sdef",
                "Resources/MainMenu.nib",
                "Resources/JavaScript/**",
                "Resources/chain_link_lottie.json",
                "App/Resources/Assets.xcassets",
                "CodeLooper/Base.lproj/Main.storyboard",
            ],
            entitlements: .file(path: "App/Resources/Entitlements/CodeLooper.entitlements"),
            dependencies: [
                .target(name: "Diagnostics"),
                .package(product: "Defaults"),
                .package(product: "LaunchAtLogin"),
                .package(product: "KeychainAccess"),
                .package(product: "SwiftUIIntrospect"),
                .package(product: "Logging"),
                .package(product: "AXorcist"),
                .package(product: "AXpector"),
                .package(product: "Sparkle"),
                .package(product: "KeyboardShortcuts"),
                .package(product: "DesignSystem"),
                .package(product: "MenuBarExtraAccess"),
                .package(product: "OpenAI"),
                .package(product: "Ollama"),
                .package(product: "Lottie"),
                .package(product: "Demark"),
            ],
            settings: .settings(
                base: [
                    "INFOPLIST_FILE": "App/Info.plist",
                    "PRODUCT_BUNDLE_IDENTIFIER": "me.steipete.codelooper",
                    "MARKETING_VERSION": "2025.5.29",
                    "CURRENT_PROJECT_VERSION": "2",
                    // Team ID will be inherited from project-level if not specified per target/config
                ],
                configurations: [
                    .debug(name: "Debug", settings: [
                        "CODE_SIGN_IDENTITY": "Apple Development",
                        "CODE_SIGN_STYLE": "Automatic",
                        "DEVELOPMENT_TEAM": "Y5PE65HELJ", // Updated with your Team ID
                        "ENABLE_HARDENED_RUNTIME": "YES",
                    ]),
                    .release(name: "Release", settings: [
                        // Release signing settings can be more specific if needed, e.g., Apple Distribution
                        // "CODE_SIGN_IDENTITY": "Apple Distribution",
                        "DEVELOPMENT_TEAM": "Y5PE65HELJ", // Updated with your Team ID for consistency
                    ]),
                ]
            )
        ),
        .target(
            name: "CodeLooperTests",
            destinations: [.mac],
            product: .unitTests,
            bundleId: "me.steipete.codelooper.tests",
            deploymentTargets: .macOS("14.0"),
            sources: ["Tests/**"],
            resources: [
                "Tests/Resources/**",
            ],
            dependencies: [
                .target(name: "CodeLooper"),
                .target(name: "Diagnostics"),
                .package(product: "Testing"),
            ],
            settings: .settings(
                base: [
                    "SWIFT_VERSION": "6.0",
                    "MACOSX_DEPLOYMENT_TARGET": "14.0",
                    "OTHER_SWIFT_FLAGS": "-strict-concurrency=complete",
                    "ENABLE_STRICT_CONCURRENCY_CHECKS": "YES",
                    "ENABLE_TESTING": "YES",
                    "FRAMEWORK_SEARCH_PATHS": "$(inherited) $(PLATFORM_DIR)/Developer/Library/Frameworks",
                    // Enable automatic macro trust for Swift Testing
                    "ENABLE_USER_SCRIPT_SANDBOXING": "NO",
                    "SWIFT_PACKAGE_MACRO_VALIDATION": "NO",
                ]
            )
        ),
    ],
    schemes: [
        .scheme(
            name: "CodeLooper",
            shared: true,
            buildAction: .buildAction(targets: ["CodeLooper"]),
            testAction: TestAction.targets(
                ["CodeLooperTests"],
                configuration: "Debug",
                options: TestActionOptions.options(
                    coverage: true,
                    codeCoverageTargets: ["CodeLooper"]
                )
            ),
            runAction: .runAction(executable: "CodeLooper"),
            archiveAction: .archiveAction(configuration: "Release"),
            profileAction: .profileAction(configuration: "Release", executable: "CodeLooper"),
            analyzeAction: .analyzeAction(configuration: "Debug")
        ),
    ]
)
