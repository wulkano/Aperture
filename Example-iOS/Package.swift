// swift-tools-version:5.7
import PackageDescription

let package = Package(
	name: "Example",
	platforms: [
		.macOS(.v13)
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
