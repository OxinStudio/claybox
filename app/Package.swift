// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "Claybox",
    platforms: [.macOS(.v14)],
    targets: [
        .executableTarget(name: "Claybox", path: "Sources/Claybox")
    ]
)
