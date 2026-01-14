// swift-tools-version: 5.9

import PackageDescription

let package = Package(
    name: "FolderIcon",
    platforms: [.macOS(.v12)],
    products: [
        .executable(name: "foldericon", targets: ["FolderIcon"])
    ],
    dependencies: [
        .package(url: "https://github.com/apple/swift-argument-parser", from: "1.2.0")
    ],
    targets: [
        .executableTarget(
            name: "FolderIcon",
            dependencies: [
                .product(name: "ArgumentParser", package: "swift-argument-parser")
            ]
        )
    ]
)
