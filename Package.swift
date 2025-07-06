// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "Teatro",
    products: [
        .library(name: "Teatro", targets: ["Teatro"])
    ],
    targets: [
        .target(name: "Teatro", path: "Sources")
    ]
)
