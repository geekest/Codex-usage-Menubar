// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "CodexUsageMenu",
    platforms: [.macOS(.v14)],
    products: [
        .executable(name: "CodexUsageMenu", targets: ["CodexUsageMenu"])
    ],
    targets: [
        .executableTarget(name: "CodexUsageMenu"),
        .testTarget(name: "CodexUsageMenuTests", dependencies: ["CodexUsageMenu"])
    ]
)
