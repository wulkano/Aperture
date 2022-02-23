// swift-tools-version:5.5
import PackageDescription

let package = Package(
	name: "Example",
	platforms: [
		.macOS(.v10_13)
	],
	dependencies: [
		.package(path: "..")
	],
	targets: [
		.executableTarget(
			name: "Example",
			dependencies: [
				"Aperture"
			]
		)
	]
)
