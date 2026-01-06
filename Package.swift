// swift-tools-version: 6.0
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "Pomafocus",
    platforms: [
        .macOS(.v13),
        .iOS(.v18)
    ],
    products: [
        .library(
            name: "PomafocusKit",
            targets: ["PomafocusKit"]
        )
    ],
    targets: [
        .target(
            name: "PomafocusKit",
            linkerSettings: [
                .linkedFramework("CloudKit"),
                .linkedFramework("FamilyControls", .when(platforms: [.iOS])),
                .linkedFramework("ManagedSettings", .when(platforms: [.iOS]))
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
