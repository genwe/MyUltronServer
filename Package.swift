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
            sources: ["MyUltronServer.m"],          // 明确源文件
            publicHeadersPath: "include",
            cSettings: [
                .headerSearchPath("include")        // 帮助编译器找到头文件
            ]
        ),
    ]
)