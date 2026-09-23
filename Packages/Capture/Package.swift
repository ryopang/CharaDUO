// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "Capture",
    platforms: [.iOS(.v18), .macOS(.v15)],
    products: [
        .library(name: "Capture", targets: ["Capture"])
    ],
    targets: [
        .target(name: "Capture"),
        .testTarget(name: "CaptureTests", dependencies: ["Capture"])
    ],
    swiftLanguageModes: [.v6]
)
