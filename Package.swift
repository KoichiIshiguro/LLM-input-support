// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "LLMime",
    platforms: [.macOS(.v14)],
    targets: [
        .executableTarget(
            name: "LLMime",
            path: "LLMime",
            exclude: ["Info.plist", "LLMime.entitlements"],
            resources: [
                .process("Assets.xcassets")
            ]
        )
    ]
)
