// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "NagBarCore",
    platforms: [
        .macOS(.v12),
    ],
    products: [
        .library(name: "NagBarCore", targets: ["NagBarCore"]),
    ],
    targets: [
        .target(name: "NagBarCore"),
        .testTarget(name: "NagBarCoreTests", dependencies: ["NagBarCore"]),
    ],
    swiftLanguageModes: [.v5]
)
