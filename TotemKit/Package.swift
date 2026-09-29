// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "TotemKit",
    platforms: [.iOS(.v26), .macOS(.v15)],
    products: [
        .library(name: "TotemCore", targets: ["TotemCore"]),
        .library(name: "TotemUI", targets: ["TotemUI"]),
    ],
    targets: [
        .target(name: "TotemCore"),
        .target(name: "TotemUI", dependencies: ["TotemCore"]),
        .testTarget(name: "TotemCoreTests", dependencies: ["TotemCore"]),
    ]
)
