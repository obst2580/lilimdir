// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "Lilim",
    platforms: [.macOS(.v14)],
    products: [.executable(name: "Lilim", targets: ["Lilim"])],
    targets: [
        .target(name: "PTYBridge"),
        .executableTarget(name: "Lilim", dependencies: ["PTYBridge"])
    ],
    swiftLanguageModes: [.v6]
)
