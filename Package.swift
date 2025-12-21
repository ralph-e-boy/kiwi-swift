// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "KiwiSolver",
    platforms: [
        .iOS(.v13),
        .macOS(.v10_15),
        .tvOS(.v13),
        .watchOS(.v6),
        .visionOS(.v1),
    ],
    products: [
        .library(name: "KiwiSolver", targets: ["KiwiSolver"]),
    ],
    dependencies: [
        .package(url: "https://github.com/apple/swift-docc-plugin", from: "1.0.0"),
    ],
    targets: [
        .target(
            name: "CxxKiwi",
            path: "Sources/CxxKiwi",
            publicHeadersPath: "include",
            cxxSettings: [
                .headerSearchPath("../../kiwi"),  // submodule root so kiwi/x.h resolves
            ]
        ),
        .target(
            name: "KiwiSolver",
            dependencies: ["CxxKiwi"],
            swiftSettings: [.interoperabilityMode(.Cxx)]
        ),
        .executableTarget(
            name: "KiwiTest",
            dependencies: ["KiwiSolver"],
            swiftSettings: [.interoperabilityMode(.Cxx)]
        ),
    ],
    cxxLanguageStandard: .cxx17
)
