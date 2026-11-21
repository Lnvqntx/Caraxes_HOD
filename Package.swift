// swift-tools-version: 5.7
import PackageDescription

let package = Package(
    name: "Caraxes",
    platforms: [.macOS(.v12)],
    targets: [
        .executableTarget(
            name: "Caraxes",
            path: "Caraxes",
            // The build script copies these directly into the main app bundle.
            exclude: ["Info.plist", "Resources"],
            linkerSettings: [
                .linkedFramework("AppKit"),
                .linkedFramework("CoreGraphics"),
                .linkedFramework("ImageIO"),
                .linkedFramework("QuartzCore"),
                .linkedFramework("UniformTypeIdentifiers")
            ]
        )
    ]
)
