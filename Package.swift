// swift-tools-version: 5.4

import PackageDescription

let package = Package(
	name: "deep-codable",
	products: [
		.library(
			name: "DeepCodable",
			targets: ["DeepCodable"]
		),
	],
	dependencies: [],
	targets: [
		.target(
			name: "DeepCodable",
			dependencies: []
		),
		.testTarget(
			name: "DeepCodableTests",
			dependencies: ["DeepCodable"]
		),
	]
)
