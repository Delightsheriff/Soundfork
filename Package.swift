// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "AudioRouter",
    platforms: [.macOS(.v26)],
    targets: [
        .target(name: "AudioRouterCore"),
        .executableTarget(name: "AudioRouterApp", dependencies: ["AudioRouterCore"]),
        .executableTarget(name: "TapSpike", dependencies: ["AudioRouterCore"]),
        .testTarget(name: "AudioRouterCoreTests", dependencies: ["AudioRouterCore"]),
    ]
)
