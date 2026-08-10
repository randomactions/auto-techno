// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "AutoTechno",
    platforms: [.macOS(.v14)],
    products: [
        .executable(name: "AutoTechno", targets: ["AutoTechnoApp"]),
    ],
    dependencies: [
        .package(url: "https://github.com/swiftlang/swift-testing.git", exact: "0.12.0"),
    ],
    targets: [
        .target(name: "AutoTechnoCore"),
        .target(
            name: "AutoTechnoDSP",
            dependencies: ["AutoTechnoCore"],
            resources: [.process("Resources")]
        ),
        .executableTarget(name: "AutoTechnoApp", dependencies: ["AutoTechnoCore", "AutoTechnoDSP"]),
        .testTarget(
            name: "AutoTechnoCoreTests",
            dependencies: [
                "AutoTechnoCore",
                "AutoTechnoDSP",
                .product(name: "Testing", package: "swift-testing"),
            ]
        ),
    ]
)
