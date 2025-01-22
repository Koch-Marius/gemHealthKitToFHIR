// swift-tools-version: 6.0
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "gemHealthKitToFHIR",
    products: [
        // Products define the executables and libraries a package produces, making them visible to other packages.
        .library(
            name: "gemHealthKitToFHIR",
            targets: ["gemHealthKitToFHIR"]),
    ],
    dependencies: [
        .package(url: "https://github.com/apple/FHIRModels.git",
                    .upToNextMajor(from: "0.6.1"))
    ],
    targets: [
        // Targets are the basic building blocks of a package, defining a module or a test suite.
        // Targets can depend on other targets in this package and products from dependencies.
        .target(
                    name: "gemHealthKitToFHIR",
                    dependencies: [
                        .product(name: "ModelsR4", package: "FHIRModels")
                    ],
                    path: "Sources/gemHealthKitToFHIR"),
        .testTarget(
            name: "gemHealthKitToFHIRTests",
            dependencies: [
                "gemHealthKitToFHIR"
            ]
        ),
    ]
)
