import XCTest

import DeepCodable


/// Test some examples pulled from real-world usage, to better catch interesting corner-cases than contrived examples.
final class RealWorldDecodingTests: XCTestCase {
	/// Helper function to decode from a string to a type instance
	func decode<Type: Decodable>(_ type: Type.Type, from json: String) throws -> Type {
		return try JSONDecoder().decode(type.self, from: json.data(using: .utf8)!)
	}


	/// Test that decoding an example response from the GitHub GraphQL API produces the expected results.
	func testGithubGraphqlResponse() throws {
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


			enum TypeName: String, Decodable {
				case example = "Example type"
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

			@Value var title: String
			@Value var type: TypeName
			@Value var nodes: [Node]
		}

		let json = """
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
			"""

		let decoded = try decode(GithubGraphqlResponse.self, from: json)

		XCTAssertEqual("Example title", decoded.title)
		XCTAssertEqual(.example, decoded.type)

		XCTAssertTrue(decoded.nodes.indices.contains(0))
		let emptyNode1 = decoded.nodes[0]
		XCTAssertNil(emptyNode1.name)
		XCTAssertNil(emptyNode1.fieldName)

		XCTAssertTrue(decoded.nodes.indices.contains(1))
		let emptyNode2 = decoded.nodes[1]
		XCTAssertNil(emptyNode2.name)
		XCTAssertNil(emptyNode2.fieldName)

		XCTAssertTrue(decoded.nodes.indices.contains(2))
		let validNode = decoded.nodes[2]
		XCTAssertEqual("Example node name", validNode.name)
		XCTAssertEqual("Example field name", validNode.fieldName)
	}
}
