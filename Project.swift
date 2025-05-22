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
        .remote(url: "https://github.com/sindresorhus/Defaults", requirement: .upToNextMajor(from: "7.3.1")),
        .remote(url: "https://github.com/siteline/SwiftUI-Introspect.git", requirement: .upToNextMajor(from: "0.9.0")),
        .remote(url: "https://github.com/apple/swift-log.git", requirement: .upToNextMajor(from: "1.5.0")),
        .remote(url: "https://github.com/sindresorhus/LaunchAtLogin", requirement: .upToNextMajor(from: "5.0.0")),
        .local(path: "AXorcist")
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
            name: "CodeLooper",
            destinations: [.mac],
            product: .app,
            bundleId: "ai.amantusmachina.codelooper",
            deploymentTargets: .macOS("14.0"),
            infoPlist: .file(path: "CodeLooper/Info.plist"),
            sources: [
                "Sources/**"
            ],
            resources: [
                "Resources/**",
                "CodeLooper/Assets.xcassets",
                "CodeLooper/Base.lproj/**"
            ],
            entitlements: .file(path: "CodeLooper/CodeLooper.entitlements"),
            dependencies: [
                .package(product: "Defaults"),
                .package(product: "LaunchAtLogin"),
                .package(product: "SwiftUIIntrospect"),
                .package(product: "Logging"),
                .package(product: "AXorcist")
            ],
            settings: .settings(
                base: [
                    "INFOPLIST_FILE": "CodeLooper/Info.plist",
                    "PRODUCT_BUNDLE_IDENTIFIER": "ai.amantusmachina.codelooper",
                    "MARKETING_VERSION": "1.0",
                    "CURRENT_PROJECT_VERSION": "1"
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