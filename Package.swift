// swift-tools-version: 6.1
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "Sqlite2CoreData",
    
    products: [
        // Products define the executables and libraries a package produces, making them visible to other packages.
        .executable(
            name: "Sqlite2CoreData",
            targets: ["Sqlite2CoreData"]),
    ],
    dependencies: [
        .package(
            url: "https://github.com/ccgus/fmdb",
            .upToNextMinor(from: "2.7.12")),
    ],
    targets: [
        // Targets are the basic building blocks of a package, defining a module or a test suite.
        // Targets can depend on other targets in this package and products from dependencies.
        .executableTarget(
            name: "Sqlite2CoreData", dependencies: [
                "SqliteExtractor", .product(name: "FMDB", package: "fmdb"),
                "SQCDHelper"
            ]),
        .target(name: "SQCDHelper", dependencies: [
            "SqliteExtractor",
        ]),
        .target(name: "SqliteExtractor", dependencies: [ "_SqliteExtractor_constant"]),
        .target(name: "_SqliteExtractor_constant"),
        .testTarget(
            name: "Sqlite2CoreDataTests",
            dependencies: ["Sqlite2CoreData"],
            resources: [
                .process("Resources")
            ]
           
        ),
    ]
)
