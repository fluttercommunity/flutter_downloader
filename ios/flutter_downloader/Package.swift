// swift-tools-version: 5.9

import PackageDescription

let package = Package(
    name: "flutter_downloader",
    platforms: [
        .iOS("13.0")
    ],
    products: [
        .library(name: "flutter-downloader", targets: ["flutter_downloader"])
    ],
    dependencies: [
        .package(name: "FlutterFramework", path: "../FlutterFramework")
    ],
    targets: [
        .target(
            name: "flutter_downloader",
            dependencies: [
                .product(name: "FlutterFramework", package: "FlutterFramework")
            ],
            resources: [
              .process("download_tasks.sql"),
            ],
            publicHeadersPath: "include/flutter_downloader",
            linkerSettings: [
                .linkedLibrary("sqlite3")
            ]
        )
    ]
)
