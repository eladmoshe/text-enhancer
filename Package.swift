// swift-tools-version: 5.9
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "TextEnhancer",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(name: "TextEnhancer", targets: ["TextEnhancer"])
    ],
    dependencies: [
        // No external dependencies for Phase 1
    ],
    targets: [
        .executableTarget(
            name: "TextEnhancer",
            dependencies: [],
            path: "TextEnhancer",
            resources: [
                .copy("../config.default.json")
            ],
            swiftSettings: [
                .unsafeFlags(["-parse-as-library"])
            ]
        ),
        .testTarget(
            name: "TextEnhancerTests",
            dependencies: ["TextEnhancer"],
            path: "Tests/TextEnhancerTests"
        )
    ]
) 