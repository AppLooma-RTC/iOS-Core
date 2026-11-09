// swift-tools-version:6.2
// Media transport core for the AppLooma RTC iOS SDK.
//
// Picked up by Swift 6.2 and newer toolchains; adds visionOS support.
//
// This is a modified redistribution of open source work; see NOTICE for the
// attribution and the list of changes. You do not depend on this package
// directly — depend on AppLoomaRTC.

import PackageDescription

let package = Package(
    name: "AppLoomaCore",
    platforms: [
        .iOS(.v13),
        .macOS(.v10_15),
        .macCatalyst(.v14),
        .visionOS(.v26),
        .tvOS(.v17),
    ],
    products: [
        .library(
            name: "AppLoomaCore",
            targets: ["AppLoomaCore"],
        ),
    ],
    dependencies: [
        .package(url: "https://github.com/AppLooma-RTC/iOS-WebRTC.git", exact: "150.7871.01"),
        .package(url: "https://github.com/AppLooma-RTC/iOS-UniFFI.git", exact: "0.1.9"),
    ],
    targets: [
        // The C and Objective-C helper targets keep their upstream names: they
        // are internal build units, never written by anyone integrating the SDK,
        // and renaming them would mean rewriting module maps and headers.
        .target(
            name: "CAppLoomaProto",
            exclude: ["LICENSE-nanopb.txt", "module.modulemap"],
            publicHeadersPath: "include",
            cSettings: [
                .headerSearchPath("include"),
            ],
        ),
        .target(
            name: "AppLoomaNanopb",
            dependencies: ["CAppLoomaProto"],
        ),
        .target(
            name: "LKObjCHelpers",
            publicHeadersPath: "include",
        ),
        .target(
            name: "AppLoomaCore",
            dependencies: [
                .product(name: "AppLoomaWebRTC", package: "iOS-WebRTC"),
                .product(name: "AppLoomaUniFFI", package: "iOS-UniFFI"),
                "AppLoomaNanopb",
                "LKObjCHelpers",
            ],
            exclude: [
                "Broadcast/NOTICE",
            ],
            resources: [
                .process("PrivacyInfo.xcprivacy"),
            ],
        ),
    ]
)
