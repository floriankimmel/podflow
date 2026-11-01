// swift-tools-version:6.0
import PackageDescription

let package = Package(
    name: "Podflow",
    platforms: [.macOS(.v15)],
    dependencies: [
        .package(url: "https://github.com/jpsim/Yams.git", from: "5.1.0")
    ],
    targets: [
        .executableTarget(
            name: "Podflow",
            dependencies: ["Yams"],
            path: "Sources/Podflow",
            resources: [
                .copy("Resources/prompts"),
                .copy("Resources/reaper")
            ],
            swiftSettings: [.swiftLanguageMode(.v5)]
        ),
        .testTarget(
            name: "PodflowTests",
            dependencies: ["Podflow"],
            path: "Tests/PodflowTests",
            swiftSettings: [.swiftLanguageMode(.v5)]
        )
    ]
)
