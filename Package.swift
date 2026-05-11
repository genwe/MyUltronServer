// swift-tools-version:5.5
import PackageDescription

let package = Package(
    name: "MyUltronServer",
    platforms: [
        .iOS(.v13)
    ],
    products: [
        .library(
            name: "MyUltronServer",
            targets: ["MyUltronServer"]
        ),
    ],
    dependencies: [
        .package(url: "https://github.com/robbiehanson/CocoaAsyncSocket.git",
                 from: "7.6.0"),
    ],
    targets: [
        .target(
            name: "MyUltronServer",
            dependencies: ["CocoaAsyncSocket"],
            path: "Sources/MyUltronServer",
            exclude: [], // no exclusions — all .h/.m/.mm under this tree
            publicHeadersPath: "include",
            cxxSettings: [
                .define("SPM_BUILD"),
            ]
        ),
    ],
    cxxLanguageStandard: .cxx14
)
