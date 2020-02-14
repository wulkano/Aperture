// swift-tools-version:5.1
import PackageDescription

let package = Package(
    name: "ScreenRecordingSample",
    platforms: [
        .macOS(.v10_12)
    ],
    dependencies: [
        .package(path: "../")
    ],
    targets: [
        .target(
            name: "ScreenRecordingSample",
            dependencies: [
              "Aperture"
            ]
        ),
        .testTarget(
            name: "ScreenRecordingSampleTests",
            dependencies: [
              "ScreenRecordingSample"
            ]
        )
    ]
)
