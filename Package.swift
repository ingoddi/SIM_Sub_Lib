// swift-tools-version: 6.0
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "SIMSub",
    platforms: [
        .iOS(.v13)
    ],
    products: [
        .library(
            name: "SIMSub",
            targets: ["SIMSub"]
        ),
    ],
    dependencies: [
        .package(url: "https://github.com/adjust/ios_sdk.git", exact: "4.38.4"),
        .package(url: "https://github.com/Pushwoosh/Pushwoosh-XCFramework.git", exact: "6.7.15"),
    ],
    targets: [
        .target(
            name: "SIMSub",
            dependencies: [
                .product(name: "Adjust", package: "ios_sdk"),
                .product(name: "PushwooshFramework", package: "Pushwoosh-XCFramework"),
            ]
        ),
        .testTarget(
            name: "SIMSubTests",
            dependencies: ["SIMSub"]
        ),
    ]
)
