// swift-tools-version: 6.0
import PackageDescription

#if os(Windows)
let autoTechnoExecutableTarget = "AutoTechnoWindows"
#else
let autoTechnoExecutableTarget = "AutoTechnoApp"
#endif

let autoTechnoWindowsPlatformTarget = Target.target(
    name: "AutoTechnoWindowsPlatform",
    publicHeadersPath: "include",
    linkerSettings: [
        .linkedLibrary("gdi32", .when(platforms: [.windows])),
        .linkedLibrary("user32", .when(platforms: [.windows])),
        .linkedLibrary("winmm", .when(platforms: [.windows])),
    ]
)
let autoTechnoWindowsExecutableTarget = Target.executableTarget(
    name: "AutoTechnoWindows",
    dependencies: [
        "AutoTechnoCore",
        "AutoTechnoDSP",
        "AutoTechnoTransport",
        "AutoTechnoWindowsPlatform",
    ]
)

let autoTechnoCoreTestTarget = Target.testTarget(
    name: "AutoTechnoCoreTests",
    dependencies: [
        "CAutoTechnoRealtime",
        "AutoTechnoCore",
        "AutoTechnoDSP",
        "AutoTechnoTransport",
        .product(name: "Testing", package: "swift-testing"),
    ]
)

#if os(Windows)
let autoTechnoApplicationTargets: [Target] = [
    autoTechnoWindowsPlatformTarget,
    autoTechnoWindowsExecutableTarget,
]
let autoTechnoTestTargets: [Target] = [autoTechnoCoreTestTarget]
#else
// Keep the Windows target source-buildable on macOS through the C shim's
// non-Windows stubs, while selecting only the native macOS host as the product.
let autoTechnoApplicationTargets: [Target] = [
    .executableTarget(
        name: "AutoTechnoApp",
        dependencies: [
            "AutoTechnoCore",
            "AutoTechnoDSP",
            "AutoTechnoTransport",
            "CAutoTechnoRealtime",
        ]
    ),
    autoTechnoWindowsPlatformTarget,
    autoTechnoWindowsExecutableTarget,
]
let autoTechnoTestTargets: [Target] = [
    autoTechnoCoreTestTarget,
    .testTarget(
        name: "AutoTechnoAppTests",
        dependencies: [
            "AutoTechnoApp",
            "AutoTechnoCore",
            "AutoTechnoDSP",
            "AutoTechnoTransport",
            "CAutoTechnoRealtime",
            .product(name: "Testing", package: "swift-testing"),
        ]
    ),
]
#endif

let package = Package(
    name: "AutoTechno",
    platforms: [.macOS(.v14)],
    products: [
        .executable(name: "AutoTechno", targets: [autoTechnoExecutableTarget]),
    ],
    dependencies: [
        .package(url: "https://github.com/swiftlang/swift-testing.git", exact: "0.12.0"),
    ],
    targets: [
        .target(name: "CAutoTechnoRealtime"),
        .target(name: "AutoTechnoCore"),
        .target(
            name: "AutoTechnoDSP",
            dependencies: ["AutoTechnoCore"],
            resources: [.process("Resources")]
        ),
        .target(
            name: "AutoTechnoTransport",
            dependencies: ["AutoTechnoCore", "AutoTechnoDSP"]
        ),
    ] + autoTechnoApplicationTargets + autoTechnoTestTargets
)
