// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "DistanceCore",
    platforms: [
        .iOS(.v17),
        .macOS(.v13)
    ],
    products: [
        .library(name: "DistanceCore", targets: ["DistanceCore"])
    ],
    targets: [
        .target(name: "DistanceCore"),
        .testTarget(name: "DistanceCoreTests", dependencies: ["DistanceCore"])
    ]
)
