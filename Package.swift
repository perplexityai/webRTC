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
            url: "https://github.com/perplexityai/webRTC/releases/download/141.2.0/WebRTC.xcframework.zip",
            checksum: "e1f64eef6f52b9ba4bb21444e6dacf3eb79dc5166ff3afe0207f43213209288d"
        ),
    ]
)
