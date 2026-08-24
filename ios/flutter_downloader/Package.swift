// swift-tools-version: 5.9
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
  name: "flutter_downloader",
  platforms: [
    .iOS("12.0")
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
        .process("Resources")
      ],
      cSettings: [
        .headerSearchPath("include/flutter_downloader")
      ],
      linkerSettings: [
        .linkedLibrary("sqlite3")
      ]
    )
  ]
)
