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
            url: "https://github.com/perplexityai/webRTC/releases/download/141.0.0/WebRTC.xcframework.zip",
            checksum: "8b3784ee69d02e4198cc852ca6450cea18735a15cdbc55f8b712f92334c6549e"
        ),
    ]
)
