// swift-tools-version:5.5
import PackageDescription

let package = Package(
    name: "MyUltronServer",
    platforms: [
        .iOS(.v10)
    ],
    products: [
        .library(
            name: "MyUltronServer",
            targets: ["MyUltronServer"]
        ),
    ],
    targets: [
        .target(
            name: "MyUltronServer",
            path: "Sources/MyUltronServer",
            publicHeadersPath: "include"
        ),
    ]
)
