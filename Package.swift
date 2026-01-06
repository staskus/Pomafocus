// swift-tools-version: 6.2
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "Pomafocus",
    platforms: [
        .macOS(.v13),
        .iOS(.v16)
    ],
    products: [
        .library(
            name: "PomafocusKit",
            targets: ["PomafocusKit"]
        ),
        .executable(
            name: "Pomafocus",
            targets: ["Pomafocus"]
        )
    ],
    targets: [
        .target(
            name: "PomafocusKit"
        ),
        .executableTarget(
            name: "Pomafocus",
            dependencies: [
                "PomafocusKit"
            ],
            linkerSettings: [
                .linkedFramework("AppKit"),
                .linkedFramework("Carbon")
            ]
        ),
        .testTarget(
            name: "PomafocusKitTests",
            dependencies: [
                "PomafocusKit"
            ],
            swiftSettings: [
                .enableExperimentalFeature("SwiftTesting")
            ]
        )
    ]
)
