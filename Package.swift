// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "PEPEPTZController",
    platforms: [.macOS(.v13)],
    products: [
        .executable(name: "PEPEPTZController", targets: ["PEPEPTZController"]),
        .library(name: "PTZCore", targets: ["PTZCore"]),
    ],
    targets: [
        // Camera models, storage and (later) the Panasonic protocol. No UI code here.
        .target(name: "PTZCore"),
        // The SwiftUI Mac app.
        .executableTarget(name: "PEPEPTZController", dependencies: ["PTZCore"]),
        .testTarget(name: "PTZCoreTests", dependencies: ["PTZCore"]),
    ]
)
