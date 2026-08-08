// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "AutoTechno",
    platforms: [.macOS(.v14)],
    products: [
        .executable(name: "AutoTechno", targets: ["AutoTechnoApp"]),
        .executable(name: "AutoTechnoReference", targets: ["AutoTechnoReference"]),
        .executable(name: "AutoTechnoLeapReference", targets: ["AutoTechnoLeapReference"]),
        .executable(name: "AutoTechnoSynthReference", targets: ["AutoTechnoSynthReference"]),
        .library(name: "AutoTechnoCore", targets: ["AutoTechnoCore"]),
        .library(name: "AutoTechnoDSP", targets: ["AutoTechnoDSP"]),
    ],
    dependencies: [
        .package(url: "https://github.com/swiftlang/swift-testing.git", exact: "0.12.0"),
    ],
    targets: [
        .target(name: "AutoTechnoCore"),
        .target(name: "AutoTechnoDSP", dependencies: ["AutoTechnoCore"]),
        .executableTarget(name: "AutoTechnoApp", dependencies: ["AutoTechnoCore", "AutoTechnoDSP"]),
        .executableTarget(name: "AutoTechnoReference", dependencies: ["AutoTechnoCore", "AutoTechnoDSP"]),
        .executableTarget(name: "AutoTechnoLeapReference", dependencies: ["AutoTechnoCore", "AutoTechnoDSP"]),
        .executableTarget(name: "AutoTechnoSynthReference", dependencies: ["AutoTechnoCore", "AutoTechnoDSP"]),
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
