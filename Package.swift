// swift-tools-version:5.7
import PackageDescription

let package = Package(
	name: "Aperture",
	platforms: [
		.macOS(.v13)
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
