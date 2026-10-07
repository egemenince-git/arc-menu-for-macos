// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "CtrlEsc",
    platforms: [.macOS(.v14)],
    products: [
        .executable(name: "CtrlEsc", targets: ["CtrlEsc"]),
    ],
    targets: [
        .executableTarget(
            name: "CtrlEsc",
            path: "Sources/CtrlEsc",
            linkerSettings: [
                .linkedFramework("AppKit"),
                .linkedFramework("Carbon"),
                .linkedFramework("OpenDirectory"),
                .linkedFramework("ServiceManagement"),
                .linkedFramework("SwiftUI"),
            ]
        ),
    ]
)
