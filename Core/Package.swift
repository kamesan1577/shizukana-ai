// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "QuietCore",
    platforms: [.iOS(.v27)],
    products: [.library(name: "QuietCore", targets: ["QuietCore"])],
    targets: [
        .target(name: "QuietCore"),
        .testTarget(name: "QuietCoreTests", dependencies: ["QuietCore"]),
    ]
)
