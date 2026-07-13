// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "FunPasteUI",
    platforms: [.macOS(.v14)],
    products: [
        .library(name: "FunPasteUI", targets: ["FunPasteUI"]),
        .executable(name: "FunPastePreview", targets: ["FunPastePreview"]),
        .executable(name: "FunPasteUITestRunner", targets: ["FunPasteUITestRunner"])
    ],
    targets: [
        .target(name: "FunPasteUI"),
        .executableTarget(name: "FunPastePreview", dependencies: ["FunPasteUI"]),
        .executableTarget(name: "FunPasteUITestRunner", dependencies: ["FunPasteUI"])
    ]
)
