// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "HypergateCore",
    platforms: [.macOS(.v14)],
    products: [
        .library(name: "HypergateCore", targets: ["HypergateCore"]),
        .library(name: "HypergateAstronomyEngine", targets: ["HypergateAstronomyEngine"]),
        .executable(name: "hypergate", targets: ["HypergateCLI"]),
        .executable(name: "hypergate-benchmark", targets: ["HypergateBenchmark"]),
    ],
    targets: [
        .target(name: "CAstronomyEngine", exclude: ["LICENSE"], publicHeadersPath: "include"),
        .target(name: "HypergateCore"),
        .target(name: "HypergateAstronomyEngine", dependencies: ["HypergateCore", "CAstronomyEngine"]),
        .executableTarget(name: "HypergateCLI", dependencies: ["HypergateCore", "HypergateAstronomyEngine"]),
        .executableTarget(name: "HypergateBenchmark", dependencies: ["HypergateCore", "HypergateAstronomyEngine"]),
        .testTarget(name: "HypergateCoreTests", dependencies: ["HypergateCore", "HypergateAstronomyEngine"], resources: [.copy("Fixtures")]),
    ],
    swiftLanguageModes: [.v6]
)
