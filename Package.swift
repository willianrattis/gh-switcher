// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "GHSwitcher",
    platforms: [.macOS(.v13)],
    targets: [
        .executableTarget(name: "GHSwitcher", path: "Sources/GHSwitcher"),
        .testTarget(name: "GHSwitcherTests", dependencies: ["GHSwitcher"], path: "Tests/GHSwitcherTests")
    ]
)
