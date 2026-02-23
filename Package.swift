// swift-tools-version: 5.9
// NOTE: `swift build` requires full Xcode (not CLI Tools) because SPM needs
// the platform SDK path that CLI Tools don't expose.
// Use `./build.sh` to build with CLI Tools, or open Tempo.xcodeproj in Xcode.
import PackageDescription

let package = Package(
    name: "Tempo",
    platforms: [
        .macOS(.v13)
    ],
    targets: [
        .executableTarget(
            name: "Tempo",
            path: "Tempo/Sources/Tempo"
        )
    ]
)
