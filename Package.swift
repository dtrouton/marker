// swift-tools-version: 5.10
import PackageDescription

let package = Package(
    name: "MDMgr",
    platforms: [
        .macOS(.v14)
    ],
    targets: [
        .executableTarget(
            name: "MDMgr",
            path: "Sources"
        ),
        .testTarget(
            name: "MDMgrTests",
            dependencies: ["MDMgr"],
            path: "Tests"
        )
    ]
)
