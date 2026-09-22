// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "Posture",
    platforms: [.iOS(.v17), .macOS(.v14)],
    products: [
        .library(name: "Posture", targets: ["Posture"])
    ],
    targets: [
        .target(name: "Posture"),
        .testTarget(name: "PostureTests", dependencies: ["Posture"])
    ],
    swiftLanguageModes: [.v6]
)
