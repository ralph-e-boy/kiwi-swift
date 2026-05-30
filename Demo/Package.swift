// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "KiwiDemo",
    platforms: [
        .macOS(.v13),
    ],
    dependencies: [
        .package(path: ".."),
    ],
    targets: [
        .executableTarget(
            name: "KiwiDemo",
            dependencies: [
                .product(name: "KiwiSolver", package: "kiwi"),
            ],
            swiftSettings: [.interoperabilityMode(.Cxx)]
        ),
    ],
    cxxLanguageStandard: .cxx17
)
