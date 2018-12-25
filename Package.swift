// swift-tools-version:4.2
import PackageDescription

let package = Package(
	name: "Aperture",
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
