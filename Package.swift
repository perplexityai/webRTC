// swift-tools-version:5.10
import PackageDescription

let package = Package(
    name: "WebRTC",
    platforms: [.iOS(.v17), .macOS(.v13)],
    products: [
        .library(name: "WebRTC", targets: ["WebRTC"]),
    ],
    targets: [
        .binaryTarget(
            name: "WebRTC",
            url: "https://github.com/perplexityai/webRTC/releases/download/141.1.0/WebRTC.xcframework.zip",
            checksum: "0b160625873be281aa170f1c84013f4c40c01fa40d38f61b79309f0105eb050c"
        ),
    ]
)
