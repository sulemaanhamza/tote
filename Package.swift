// swift-tools-version:6.0
import PackageDescription

let package = Package(
    name: "Stash",
    platforms: [.macOS(.v13)],
    targets: [
        .executableTarget(
            name: "Stash",
            path: "Sources/Stash"
        )
    ]
)
