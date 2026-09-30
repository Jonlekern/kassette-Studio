// swift-tools-version:5.10
// LaFleurStudio : jaquettes de K7 et enregistrement de cassettes, avec Claude et Spotify.
import PackageDescription

let package = Package(
    name: "LaFleurStudio",
    defaultLocalization: "fr",
    platforms: [.macOS(.v14)],
    targets: [
        // Logique sans interface : modèles, faces, fichiers audio, Spotify, Claude, sauvegarde.
        .target(name: "LaFleurCore"),
        .executableTarget(name: "LaFleurStudio", dependencies: ["LaFleurCore"]),
        .testTarget(name: "LaFleurCoreTests", dependencies: ["LaFleurCore"]),
    ]
)
