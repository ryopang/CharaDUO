// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "Content",
    platforms: [.iOS(.v17), .macOS(.v14)],
    products: [
        .library(name: "Content", targets: ["Content"])
    ],
    targets: [
        .target(
            name: "Content",
            resources: [.copy("Resources/vocabulary.json")]
        ),
        .testTarget(
            name: "ContentTests",
            dependencies: ["Content"]
        )
    ],
    swiftLanguageModes: [.v6]
)
