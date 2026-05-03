// swift-tools-version:6.0
import PackageDescription

let package = Package(
    name: "Tote",
    platforms: [.macOS(.v13)],
    targets: [
        .executableTarget(
            name: "Tote",
            path: "Sources/Tote"
        )
    ]
)
