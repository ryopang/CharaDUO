// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "ContentPipeline",
    platforms: [.macOS(.v14)],
    products: [
        .executable(name: "xlsx2json", targets: ["xlsx2json"])
    ],
    dependencies: [
        .package(path: "../Content")
    ],
    targets: [
        .target(
            name: "ContentPipelineCore",
            dependencies: ["Content"],
            exclude: ["Resources/ATTRIBUTION.md"],
            resources: [
                .copy("Resources/TSCharacters.txt"),
                .copy("Resources/TSPhrases.txt")
            ]
        ),
        .executableTarget(
            name: "xlsx2json",
            dependencies: ["ContentPipelineCore"]
        ),
        .testTarget(
            name: "ContentPipelineCoreTests",
            dependencies: ["ContentPipelineCore"]
        )
    ],
    swiftLanguageModes: [.v6]
)
