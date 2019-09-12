// swift-tools-version:5.1
import PackageDescription

let package = Package(
	name: "Aperture",
	platforms: [
		.macOS(.v10_12)
	],
	products: [
		.library(
			name: "Aperture",
			targets: [
				"Aperture"
			]
		)
	],
	targets: [
		.target(
			name: "Aperture"
		)
	]
)
