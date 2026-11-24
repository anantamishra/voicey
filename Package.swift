// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "Voicey",
    platforms: [.macOS(.v13)],
    targets: [
        .executableTarget(name: "Voicey", path: "Sources/Voicey"),
        .testTarget(name: "VoiceyTests", dependencies: ["Voicey"], path: "Tests/VoiceyTests"),
    ]
)
