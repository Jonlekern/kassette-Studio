// swift-tools-version:5.10
// Kassette Recorder : prépare une mixtape (Spotify + Claude) et la joue face par face vers une platine K7.
import PackageDescription

let package = Package(
    name: "KassetteRecorder",
    defaultLocalization: "fr",
    platforms: [.macOS(.v14)],
    targets: [
        // Logique pure (modèles, répartition, exports, clients HTTP) : testable sans interface.
        .target(name: "KassetteCore"),
        .executableTarget(name: "KassetteRecorder", dependencies: ["KassetteCore"]),
        .testTarget(name: "KassetteCoreTests", dependencies: ["KassetteCore"]),
    ]
)
