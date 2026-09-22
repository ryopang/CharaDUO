// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "Design",
    platforms: [.iOS(.v17), .macOS(.v14)],
    products: [
        .library(name: "Design", targets: ["Design"])
    ],
    targets: [
        .target(name: "Design"),
        .testTarget(name: "DesignTests", dependencies: ["Design"])
    ],
    swiftLanguageModes: [.v6]
)
