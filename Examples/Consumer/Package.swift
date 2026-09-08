// swift-tools-version: 6.0
import PackageDescription

let package = Package(
  name: "HypergateConsumer", platforms: [.macOS(.v14)],
  dependencies: [.package(path: "../../Packages/HypergateCore")],
  targets: [
    .executableTarget(
      name: "HypergateConsumer",
      dependencies: [
        .product(name: "HypergateCore", package: "HypergateCore"),
        .product(name: "HypergateAstronomyEngine", package: "HypergateCore"),
      ])
  ], swiftLanguageModes: [.v6])
