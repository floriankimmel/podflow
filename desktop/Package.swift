// swift-tools-version:6.0
import PackageDescription

let package = Package(
    name: "Podflow",
    platforms: [.macOS(.v15)],
    dependencies: [
        .package(url: "https://github.com/sparkle-project/Sparkle.git", from: "2.9.0"),
    ],
    targets: [
        .executableTarget(
            name: "Podflow",
            dependencies: [.product(name: "Sparkle", package: "Sparkle")],
            path: "Sources/Podflow",
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
