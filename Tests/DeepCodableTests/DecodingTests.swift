import XCTest

import DeepCodable


/// Test decoding deeply nested serialized representations.
final class DecodingTests: XCTestCase {
	/// Helper function to decode from a string to a type instance
	func decode<Type: Decodable>(_ type: Type.Type, from json: String) throws -> Type {
		return try JSONDecoder().decode(type.self, from: json.data(using: .utf8)!)
	}

	/// Helper function to encode a type instance to a string
	func encode<Type: Encodable>(_ instance: Type) throws -> String {
		return String(data: try JSONEncoder().encode(instance), encoding: .utf8)!
	}


	/// Test that decoding a simple one-level JSON body decodes the correct value.
	func testTopLevelDecoding() throws {
		struct TopLevelDecoding: DeepDecodable {
			static let codingTree = CodingTree {
				Key("top", containing: \._key)
			}

			@Value var key: String
		}

		let json = """
			{
				"top": "topValue"
			}
			"""
		let decoded = try decode(TopLevelDecoding.self, from: json)

		XCTAssertEqual("topValue", decoded.key)
	}

	/// Test that decoding a simple one-level JSON body with two keys decodes the correct values.
	func testBranchedTopLevelDecoding() throws {
		struct BranchedTopLevelDecoding: DeepDecodable {
			static let codingTree = CodingTree {
				Key("top1", containing: \._key1)
				Key("top2", containing: \._key2)
			}

			@Value var key1: String
			@Value var key2: String
		}

		let json = """
			{
				"top1": "top1Value",
				"top2": "top2Value"
			}
			"""
		let decoded = try decode(BranchedTopLevelDecoding.self, from: json)

		XCTAssertEqual("top1Value", decoded.key1)
		XCTAssertEqual("top2Value", decoded.key2)
	}


	/// Test that decoding a two-level JSON body decodes the correct value.
	func testSecondLevelDecoding() throws {
		struct SecondLevelDecoding: DeepDecodable {
			static let codingTree = CodingTree {
				Key("top") {
					Key("second", containing: \._key)
				}
			}

			@Value var key: String
		}

		let json = """
			{
				"top": {
					"second": "secondValue"
				}
			}
			"""
		let decoded = try decode(SecondLevelDecoding.self, from: json)

		XCTAssertEqual("secondValue", decoded.key)
	}

	/// Test that decoding a two-level JSON body with two keys in different branches decodes the correct values.
	func testBranchedSecondLevelDecoding() throws {
		struct BranchedSecondLevelDecoding: DeepDecodable {
			static let codingTree = CodingTree {
				Key("top1") {
					Key("second1", containing: \._key1)
				}

				Key("top2") {
					Key("second2", containing: \._key2)
				}
			}

			@Value var key1: String
			@Value var key2: String
		}

		let json = """
			{
				"top1": {
					"second1": "second1Value"
				},
				"top2": {
					"second2": "second2Value"
				}
			}
			"""
		let decoded = try decode(BranchedSecondLevelDecoding.self, from: json)

		XCTAssertEqual("second1Value", decoded.key1)
		XCTAssertEqual("second2Value", decoded.key2)
	}


	/// Test that decoding a deep ten-level JSON body decodes the correct value.
	func testExcessivelyDeepDecoding() throws {
		struct ExcessivelyDeepDecoding: DeepDecodable {
			static let codingTree = CodingTree {
				Key("top") {
					Key("second") {
						Key("third") {
							Key("fourth") {
								Key("fifth") {
									Key("sixth") {
										Key("seventh") {
											Key("eighth") {
												Key("ninth") {
													Key("tenth", containing: \._key)
												}
											}
										}
									}
								}
							}
						}
					}
				}
			}

			@Value var key: String
		}

		let json = """
			{
				"top": {
					"second": {
						"third": {
							"fourth": {
								"fifth": {
									"sixth": {
										"seventh": {
											"eighth": {
												"ninth": {
													"tenth": "tenthValue"
												}
											}
										}
									}
								}
							}
						}
					}
				}
			}
			"""

		let decoded = try decode(ExcessivelyDeepDecoding.self, from: json)

		XCTAssertEqual("tenthValue", decoded.key)
	}

	/// Test that decoding a deep ten-level JSON body with two keys in different branches decodes the correct values.
	func testBranchedExcessivelyDeepDecoding() throws {
		struct BranchedExcessivelyDeepDecoding: DeepDecodable {
			static let codingTree = CodingTree {
				Key("top") {
					Key("second") {
						Key("third") {
							Key("fourth") {
								Key("fifth") {
									Key("sixth1") {
										Key("seventh1") {
											Key("eighth1") {
												Key("ninth1") {
													Key("tenth1", containing: \._key1)
												}
											}
										}
									}

									Key("sixth2") {
										Key("seventh2") {
											Key("eighth2") {
												Key("ninth2", containing: \._key2)
											}
										}
									}
								}
							}
						}
					}
				}
			}

			@Value var key1: String
			@Value var key2: String
		}

		let json = """
			{
				"top": {
					"second": {
						"third": {
							"fourth": {
								"fifth": {
									"sixth1": {
										"seventh1": {
											"eighth1": {
												"ninth1": {
													"tenth1": "tenth1Value"
												}
											}
										}
									},
									"sixth2": {
										"seventh2": {
											"eighth2": {
												"ninth2": "ninth2Value"
											}
										}
									}
								}
							}
						}
					}
				}
			}
			"""

		let decoded = try decode(BranchedExcessivelyDeepDecoding.self, from: json)

		XCTAssertEqual("tenth1Value", decoded.key1)
		XCTAssertEqual("ninth2Value", decoded.key2)
	}


	struct OptionalDecoding: DeepDecodable {
		static let codingTree = CodingTree {
			Key("top") {
				Key("second", containing: \._key)
			}
		}

		@Value var key: String?
	}

	/// Test that optionals decode correctly when provided an actual value.
	func testOptionalDecodingToValue() throws {
		let json = """
			{
				"top": {
					"second": "secondValue"
				}
			}
			"""
		let decoded = try decode(OptionalDecoding.self, from: json)

		XCTAssertEqual("secondValue", decoded.key)
	}

	/// Test that optionals decode correctly when not provided an actual value.
	func testOptionalDecodingToNil() throws {
		let json = """
			{}
			"""
		let decoded = try decode(OptionalDecoding.self, from: json)

		XCTAssertEqual(nil, decoded.key)
	}


	/// Test that integers decode correctly.
	func testIntDecoding() throws {
		struct IntDecoding: DeepDecodable {
			static let codingTree = CodingTree {
				Key("top") {
					Key("second", containing: \._key)
				}
			}

			@Value var key: Int
		}

		let json = """
			{
				"top": {
					"second": 17
				}
			}
			"""
		let decoded = try decode(IntDecoding.self, from: json)

		XCTAssertEqual(17, decoded.key)
	}

	/// Test that arrays decode correctly.
	func testArrayDecoding() throws {
		struct ArrayDecoding: DeepDecodable {
			static let codingTree = CodingTree {
				Key("top") {
					Key("second", containing: \._key)
				}
			}

			@Value var key: [String]
		}

		let json = """
			{
				"top": {
					"second": [
						"secondValue1",
						"secondValue2"
					]
				}
			}
			"""
		let decoded = try decode(ArrayDecoding.self, from: json)

		XCTAssertEqual(["secondValue1", "secondValue2"], decoded.key)
	}

	/// Test that an arbitrary `Decodable` struct decodes correctly.
	func testStructDecoding() throws {
		struct StructDecoding: DeepDecodable {
			static let codingTree = CodingTree {
				Key("top") {
					Key("second", containing: \._key)
				}
			}


			struct InternalStruct: Decodable {
				let key: String
			}

			@Value var key: InternalStruct
		}

		let json = """
			{
				"top": {
					"second": {
						"key": "nestedValue"
					}
				}
			}
			"""
		let decoded = try decode(StructDecoding.self, from: json)

		XCTAssertEqual("nestedValue", decoded.key.key)
	}


	/// Test that normal `Encodable` behavior is unchanged while deep decoding behaves as expected.
	func testEncodableNonInterference() throws {
		struct DeepDecodableEncoding: DeepDecodable, Encodable {
			static let codingTree = CodingTree {
				Key("top") {
					Key("second") {
						Key("third", containing: \._key)
					}
				}
			}

			@Value var key: String
		}

		let json = """
			{
				"top": {
					"second": {
						"third": "thirdValue"
					}
				}
			}
			"""
		let decoded = try decode(DeepDecodableEncoding.self, from: json)

		XCTAssertEqual("thirdValue", decoded.key)


		let expected = """
			{"key":"thirdValue"}
			"""
		let actual = try encode(decoded)
		XCTAssertEqual(expected, actual)
	}


	/// Test that omitting a node in the serialized representation (that should have decoded into a non-optional value) throws.
	func testMissingNodeThrows() throws {
		struct MissingNodeThrows: DeepDecodable {
			static let codingTree = CodingTree {
				Key("top") {
					Key("second") {
						Key("third", containing: \._key)
					}
				}
			}

			@Value var key: String
		}

		let json = """
			{
				"top": {
					"second": "secondValue"
				}
			}
			"""
		XCTAssertThrowsError(dump(try decode(MissingNodeThrows.self, from: json)))
	}
}
