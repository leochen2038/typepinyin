// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "DuelCore",
    platforms: [.iOS(.v17), .macOS(.v14)],
    products: [
        .library(name: "DuelCore", targets: ["DuelCore"]),
    ],
    targets: [
        .target(name: "DuelCore"),
        .testTarget(
            name: "DuelCoreTests",
            dependencies: ["DuelCore"],
            resources: [.copy("Fixtures")]
        ),
    ],
    swiftLanguageModes: [.v6]
)
