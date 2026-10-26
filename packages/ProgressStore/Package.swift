// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "ProgressStore",
    platforms: [.iOS(.v17), .macOS(.v14)],
    products: [
        .library(name: "ProgressStore", targets: ["ProgressStore"]),
    ],
    dependencies: [
        .package(path: "../LearningCore"),
    ],
    targets: [
        .target(name: "ProgressStore", dependencies: ["LearningCore"]),
        .testTarget(name: "ProgressStoreTests", dependencies: ["ProgressStore"]),
    ],
    swiftLanguageModes: [.v6]
)
