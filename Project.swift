import ProjectDescription
import ProjectDescriptionHelpers

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
        .remote(url: "https://github.com/kishikawakatsumi/KeychainAccess.git", requirement: .upToNextMajor(from: "4.2.2")),
        .remote(url: "https://github.com/sparkle-project/Sparkle.git", requirement: .upToNextMajor(from: "2.0.0")),
        .remote(url: "https://github.com/sindresorhus/KeyboardShortcuts", requirement: .upToNextMajor(from: "2.0.0")),
        .remote(url: "https://github.com/orchetect/MenuBarExtraAccess.git", requirement: .upToNextMajor(from: "1.2.1")),
        .remote(url: "https://github.com/MacPaw/OpenAI", requirement: .upToNextMajor(from: "0.3.0")),
        .remote(url: "https://github.com/loopwork-ai/ollama-swift", requirement: .upToNextMajor(from: "1.0.0")),
        .local(path: "AXorcist"),
        .local(path: "AXpector"),
        .local(path: "DesignSystem")
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
            "ENABLE_STRICT_CONCURRENCY_CHECKS": "YES"
        ],
        configurations: [
            .debug(name: "Debug", settings: ["OTHER_SWIFT_FLAGS": "$(inherited) -warn-concurrency -enable-actor-data-race-checks"]),
            .release(name: "Release", settings: [:])
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
            sources: ["Sources/Diagnostics/**"],
            dependencies: [
                .package(product: "Logging"),
                .package(product: "AXorcist")
            ],
            settings: .settings(
                base: [
                    "SWIFT_VERSION": "6.0",
                    "MACOSX_DEPLOYMENT_TARGET": "14.0",
                    "OTHER_SWIFT_FLAGS": "-strict-concurrency=complete",
                    "ENABLE_STRICT_CONCURRENCY_CHECKS": "YES"
                ]
            )
        ),
        .target(
            name: "CodeLooper",
            destinations: [.mac],
            product: .app,
            bundleId: "me.steipete.codelooper",
            deploymentTargets: .macOS("14.0"),
            infoPlist: .file(path: "CodeLooper/Info.plist"),
            sources: [
                "Sources/**"
            ],
            resources: [
                "Resources/CodeLooper.sdef",
                "Resources/MainMenu.nib",
                "Resources/JavaScript/**",
                "CodeLooper/Assets.xcassets",
                "CodeLooper/Base.lproj/**"
            ],
            entitlements: .file(path: "CodeLooper/CodeLooper.entitlements"),
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
                .package(product: "Ollama")
            ],
            settings: .settings(
                base: [
                    "INFOPLIST_FILE": "CodeLooper/Info.plist",
                    "PRODUCT_BUNDLE_IDENTIFIER": "me.steipete.codelooper",
                    "MARKETING_VERSION": "2025.5.2",
                    "CURRENT_PROJECT_VERSION": "2"
                    // Team ID will be inherited from project-level if not specified per target/config
                ],
                configurations: [
                    .debug(name: "Debug", settings: [
                        "CODE_SIGN_IDENTITY": "Apple Development",
                        "CODE_SIGN_STYLE": "Automatic",
                        "DEVELOPMENT_TEAM": "Y5PE65HELJ" // Updated with your Team ID
                    ]),
                    .release(name: "Release", settings: [
                        // Release signing settings can be more specific if needed, e.g., Apple Distribution
                        // "CODE_SIGN_IDENTITY": "Apple Distribution",
                        "DEVELOPMENT_TEAM": "Y5PE65HELJ" // Updated with your Team ID for consistency
                    ])
                ]
            )
        )
    ],
    schemes: [
        .scheme(
            name: "CodeLooper",
            shared: true,
            buildAction: .buildAction(targets: ["CodeLooper"]),
            testAction: nil,
            runAction: .runAction(executable: "CodeLooper"),
            archiveAction: .archiveAction(configuration: "Release"),
            profileAction: .profileAction(configuration: "Release", executable: "CodeLooper"),
            analyzeAction: .analyzeAction(configuration: "Debug")
        )
    ]
)