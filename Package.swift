// swift-tools-version: 5.10
import PackageDescription

let package = Package(
    name: "Crossnest",
    platforms: [.macOS(.v14)],
    targets: [
        .executableTarget(
            name: "Crossnest",
            path: "Sources/Crossnest"
        )
    ]
)
