// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "Core",
    platforms: [.iOS(.v17), .macOS(.v14)],
    products: [
        .library(name: "Core", targets: ["Core"])
    ],
    dependencies: [
        .package(path: "../Content")
    ],
    targets: [
        .target(
            name: "Core",
            dependencies: ["Content"]
        ),
        .testTarget(
            name: "CoreTests",
            dependencies: ["Core"]
        )
    ],
    swiftLanguageModes: [.v6]
)
