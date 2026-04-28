// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "GestureApp",
    platforms: [.macOS(.v13)],
    dependencies: [
        .package(url: "https://github.com/jpsim/Yams.git", from: "5.0.0"),
    ],
    targets: [
        .executableTarget(
            name: "GestureApp",
            dependencies: ["Yams"],
            path: "Sources/GestureApp"
        ),
        .testTarget(
            name: "GestureAppTests",
            dependencies: ["GestureApp"],
            path: "Tests/GestureAppTests"
        ),
    ]
)
