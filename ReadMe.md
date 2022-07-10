# `DeepCodable`: Encode and decode deeply-nested data into flat Swift objects #

Have you ever gotten a response from an API that looked like this and wanted to pull out and flatten the values you care about?
(This is a real response from the GitHub GraphQL API, with only the actual values changed)

```json
{
	"data": {
		"node": {
			"content": {
				"__typename": "Example type",
				"title": "Example title"
			},
			"fieldValues": {
				"nodes": [
					{},
					{},
					{
						"name": "Example node name",
						"field": {
							"name": "Example field name"
						}
					}
				]
			}
		}
	}
}
```

`DeepCodable` lets you easily do so in Swift while maintaining type-safety, with the magic of result builders, key paths, and property wrappers:

```swift
import DeepCodable

struct GithubGraphqlResponse: DeepDecodable {
	static let codingTree = CodingTree {
		Key("data") {
			Key("node") {
				Key("content") {
					Key("__typename", containing: \._type)
					Key("title", containing: \._title)
				}

				Key("fieldValues") {
					Key("nodes", containing: \._nodes)
				}
			}
		}
	}


	struct Node: DeepDecodable {
		static let codingTree = CodingTree {
			Key("name", containing: \._name)

			Key("field") {
				Key("name", containing: \._fieldName)
			}
		}


		@Value var name: String?
		@Value var fieldName: String?
	}

	enum TypeName: String, Decodable {
		case example = "Example type"
	}

	@Value var title: String
	@Value var nodes: [Node]
	@Value var type: TypeName
}

dump(try JSONDecoder().decode(GithubGraphqlResponse.self, from: jsonData))
```


## Quick start ##

Add to your `Package.Swift`:
```swift
...
	dependencies: [
		...
		.package(url: "https://github.com/MPLew-is/deep-codable", branch: "main"),
	],
	targets: [
		...
		.target(
			...
			dependencies: [
				...
				.product(name: "DeepCodable", package: "deep-codable"),
			]
		),
		...
	]
]
```

Conform a type you want to decode to `DeepDecodable` by defining a coding tree representing which nodes are bound to which values:
```swift
struct DeeplyNestedResponse: DeepDecodable {
	static let codingTree = CodingTree {
		Key("topLevel") {
			Key("secondLevel") {
				Key("thirdLevel", containing: \._property)
			}
		}
	}

	@Value var property: String
}
/*
Corresponding JSON would look like:
{
	"topLevel": {
		"secondLevel": {
			"thirdLevel: "{some value}"
		}
	}
}
*/
```

Nodes in your `codingTree` are made of `Key`s initialized one of the following ways:

- `Key("name") { /* More Keys */ }`: node that don't capture values directly, but contain other nodes
	- This maps to a serialized representation like `{ "name": { ... }}`

- `Key("name", containing: \._value)`: node that should be decoded into the `value` property

All values to decode must be wrapped with the `@Value` property wrapper, and the `\._{name}` syntax refers directly to the wrapping instance (`\.{name}` without the underscore refers to the actual underlying value).


Decode a value into an instance of your type:
```swift
let instance = try JSONDecoder().decode(Response.self, from: jsonData)
```

`DeepCodable` is built on top of normal `Codable`, so any decoder (like [the property list decoder in `Foundation`](https://developer.apple.com/documentation/foundation/propertylistdecoder) or [the excellent third-party YAML decoder, Yams](https://github.com/jpsim/Yams)) can be used to decode values.


## Encoding ##

While decoding is probably the most common use-case for this type of nested decoding, this package also supports encoding a flat Swift struct into a deeply nested one with the same pattern:
```swift
struct DeeplyNestedRequest: DeepEncodable {
	static let codingTree = CodingTree {
		Key("topLevel") {
			Key("secondLevel") {
				Key("thirdLevel", containing: \.bareProperty)
			}

			Key("otherSecondLevel", containing: \._wrappedProperty)
		}
	}

	let bareProperty: String
	@Value var wrappedProperty: String
}
/*
Corresponding JSON would look like:
{
	"topLevel": {
		"secondLevel": {
			"thirdLevel: "{bareProperty}"
		},
		"otherSecondLevel": "{wrappedProperty}"
	}
}
*/

let instance: DeeplyNestedRequest = ...
let jsonData = try JSONEncoder().encode(instance)
```

With encoding, you don't have to use the `@Value` wrappers, though you can if you'd like to support decoding and encoding on the same type (in which case you can conform to `DeepCodable` as an alias for the two).


## Key features ##

- Encoding and decoding a Swift object to/from an arbitrarily complex deeply nested serialized representation without manually writing `Codable` implementations

- Preservation of existing `Codable` behavior on the values being encoded/decoded, including custom types
	- Since `DeepCodable` is just a custom implementation of the `Codable` requirements, this also means you can nest `DeepCodable` objects like in the `GithubGraphqlResponse` example

- When conforming to `DeepEncodable` or `DeepDecodable`, don't interfere with the opposite normal `Codable` implementation (`Decodable`/`Encodable`, respectively)
	- You can declare something like `struct Response: DeepDecodable, Encodable { ... }` and decode from a deeply nested tree, and then re-encode back to a flat structure like normal `Encodable` objects

- No requirement for `@Value` property wrapper for types only conforming to `DeepEncodable`

- Omission of the corresponding tree sections when all values at the leaves are `nil`
	- This makes it so trying to encode an object with a `nil` value doesn't result in something like `{"top": {"second": {"third": null} } }`
