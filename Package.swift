// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "Soundfork",
    platforms: [.macOS(.v26)],
    targets: [
        .target(name: "SoundforkCore"),
        .executableTarget(name: "Soundfork", dependencies: ["SoundforkCore"]),
        .executableTarget(name: "TapSpike", dependencies: ["SoundforkCore"]),
        .testTarget(name: "SoundforkCoreTests", dependencies: ["SoundforkCore"]),
    ]
)
