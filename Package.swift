// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "Nelyr",
    platforms: [.macOS(.v14)],
    products: [
        .library(name: "NelyrCore", targets: ["NelyrCore"]),
        .library(name: "NelyrCommunity", targets: ["NelyrCommunity"]),
        .executable(name: "Nelyr", targets: ["Nelyr"])
    ],
    dependencies: [
        .package(url: "https://github.com/argmaxinc/argmax-oss-swift.git", from: "0.9.0"),
        .package(url: "https://github.com/sindresorhus/KeyboardShortcuts.git", exact: "2.4.0")
    ],
    targets: [
        .target(
            name: "NelyrCore",
            path: "Sources/NelyrCore"
        ),
        .target(
            name: "NelyrCommunity",
            dependencies: ["NelyrCore"],
            path: "Sources/NelyrCommunity"
        ),
        .executableTarget(
            name: "Nelyr",
            dependencies: [
                "NelyrCore",
                "NelyrCommunity",
                .product(name: "WhisperKit", package: "argmax-oss-swift"),
                .product(name: "KeyboardShortcuts", package: "KeyboardShortcuts")
            ],
            path: "Sources/DailyDesk"
        ),
        .testTarget(
            name: "NelyrTests",
            dependencies: ["Nelyr", "NelyrCore", "NelyrCommunity"],
            path: "Tests/DailyDeskTests"
        )
    ]
)
