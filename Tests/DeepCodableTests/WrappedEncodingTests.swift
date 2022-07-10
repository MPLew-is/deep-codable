import XCTest

import DeepCodable


/// Test encoding types containing only values wrapped in `@Value` property wrappers.
final class WrappedEncodingTests: XCTestCase {
	/// Helper function to decode from a string to a type instance
	func decode<Type: Decodable>(_ type: Type.Type, from json: String) throws -> Type {
		return try JSONDecoder().decode(type.self, from: json.data(using: .utf8)!)
	}

	/// Helper function to encode a type instance to a string
	func encode<Type: Encodable>(_ instance: Type) throws -> String {
		return String(data: try JSONEncoder().encode(instance), encoding: .utf8)!
	}


	/// Test that encoding a simple one-level JSON body encodes the correct value.
	func testTopLevelEncoding() throws {
		struct TopLevelEncoding: DeepEncodable {
			static let codingTree = CodingTree {
				Key("top", containing: \._key)
			}


			@Value var key: String

			init(key: String) {
				self.key = key
			}
		}

		let encoded = try encode(TopLevelEncoding(key: "topValue"))

		// We can't compare JSON strings here since key ordering is non-deterministic, so decode to a `Dictionary` instead.
		let dict = try decode([String: String].self, from: encoded)
		XCTAssertEqual("topValue", dict["top"])
	}

	/// Test that encoding a simple one-level JSON body with two keys encodes the correct values.
	func testBranchedTopLevelEncoding() throws {
		struct BranchedTopLevelEncoding: DeepEncodable {
			static let codingTree = CodingTree {
				Key("top1", containing: \._key1)
				Key("top2", containing: \._key2)
			}


			@Value var key1: String
			@Value var key2: String

			init(key1: String, key2: String) {
				self.key1 = key1
				self.key2 = key2
			}
		}

		let encoded = try encode(BranchedTopLevelEncoding(key1: "top1Value", key2: "top2Value"))

		// We can't compare JSON strings here since key ordering is non-deterministic, so decode to a `Dictionary` instead.
		let dict = try decode([String: String].self, from: encoded)
		XCTAssertEqual("top1Value", dict["top1"])
		XCTAssertEqual("top2Value", dict["top2"])
	}


	/// Test that encoding a two-level JSON body encodes the correct value.
	func testSecondLevelEncoding() throws {
		struct SecondLevelEncoding: DeepEncodable {
			static let codingTree = CodingTree {
				Key("top") {
					Key("second", containing: \._key)
				}
			}


			@Value var key: String

			init(key: String) {
				self.key = key
			}
		}

		let encoded = try encode(SecondLevelEncoding(key: "secondValue"))

		// We can't compare JSON strings here since key ordering is non-deterministic, so decode to a `Dictionary` instead.
		let dict = try decode([String: [String: String]].self, from: encoded)
		XCTAssertEqual("secondValue", dict["top"]?["second"])
	}


	/// Test that encoding a two-level JSON body with two keys in different branches encodes the correct values.
	func testBranchedSecondLevelEncoding() throws {
		struct BranchedSecondLevelEncoding: DeepEncodable {
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

			init(key1: String, key2: String) {
				self.key1 = key1
				self.key2 = key2
			}
		}

		let encoded = try encode(BranchedSecondLevelEncoding(key1: "second1Value", key2: "second2Value"))

		// We can't compare JSON strings here since key ordering is non-deterministic, so decode to a `Dictionary` instead.
		let dict = try decode([String: [String: String]].self, from: encoded)
		XCTAssertEqual("second1Value", dict["top1"]?["second1"])
		XCTAssertEqual("second2Value", dict["top2"]?["second2"])
	}


	/// Test that encoding a deep ten-level JSON body encodes the correct value.
	func testExcessivelyDeepEncoding() throws {
		struct ExcessivelyDeepEncoding: DeepEncodable {
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

			init(key: String) {
				self.key = key
			}
		}

		let encoded = try encode(ExcessivelyDeepEncoding(key: "tenthValue"))

		// We can't compare JSON strings here since key ordering is non-deterministic, so decode to a `Dictionary` instead.
		let dict = try decode(
			[
				String: [
					String: [
						String: [
							String: [
								String: [
									String: [
										String: [
											String: [
												String: [
													String: String
												]
											]
										]
									]
								]
							]
						]
					]
				]
			].self,
			from: encoded
		)
		XCTAssertEqual("tenthValue", dict["top"]?["second"]?["third"]?["fourth"]?["fifth"]?["sixth"]?["seventh"]?["eighth"]?["ninth"]?["tenth"])
	}

	/// Test that encoding a deep ten-level JSON body with two keys in different branches encodes the correct values.
	func testBranchedExcessivelyDeepEncoding() throws {
		struct BranchedExcessivelyDeepEncoding: DeepEncodable {
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
												Key("ninth2") {
													Key("tenth2", containing: \._key2)
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


			@Value var key1: String
			@Value var key2: String

			init(key1: String, key2: String) {
				self.key1 = key1
				self.key2 = key2
			}
		}

		let encoded = try encode(BranchedExcessivelyDeepEncoding(key1: "tenth1Value", key2: "tenth2Value"))

		// We can't compare JSON strings here since key ordering is non-deterministic, so decode to a `Dictionary` instead.
		let dict = try decode(
			[
				String: [
					String: [
						String: [
							String: [
								String: [
									String: [
										String: [
											String: [
												String: [
													String: String
												]
											]
										]
									]
								]
							]
						]
					]
				]
			].self,
			from: encoded
		)
		XCTAssertEqual("tenth1Value", dict["top"]?["second"]?["third"]?["fourth"]?["fifth"]?["sixth1"]?["seventh1"]?["eighth1"]?["ninth1"]?["tenth1"])
		XCTAssertEqual("tenth2Value", dict["top"]?["second"]?["third"]?["fourth"]?["fifth"]?["sixth2"]?["seventh2"]?["eighth2"]?["ninth2"]?["tenth2"])
	}

	/// Test that optionals encode correctly when provided an actual value.
	func testOptionalEncodingToValue() throws {
		struct OptionalEncodingToValue: DeepEncodable {
			static let codingTree = CodingTree {
				Key("top") {
					Key("second", containing: \._key)
				}
			}


			@Value var key: String?

			init(key: String? = nil) {
				self.key = key
			}
		}


		let encoded = try encode(OptionalEncodingToValue(key: "secondValue"))

		// We can't compare JSON strings here since key ordering is non-deterministic, so decode to a `Dictionary` instead.
		let dict = try decode([String: [String: String]].self, from: encoded)
		XCTAssertEqual("secondValue", dict["top"]?["second"])
	}

	/// Test that optionals encode correctly when not provided an actual value.
	func testOptionalEncodingToNil() throws {
		struct OptionalEncodingToNil: DeepEncodable {
			static let codingTree = CodingTree {
				Key("top") {
					Key("second", containing: \._key)
				}
			}


			@Value var key: String?

			init(key: String? = nil) {
				self.key = key
			}
		}


		let expected = "{}"
		let actual = try encode(OptionalEncodingToNil(key: nil))
		XCTAssertEqual(expected, actual)
	}

	/// Test that integers encode correctly.
	func testIntEncoding() throws {
		struct IntEncoding: DeepEncodable {
			static let codingTree = CodingTree {
				Key("top") {
					Key("second", containing: \._key)
				}
			}


			@Value var key: Int

			init(key: Int) {
				self.key = key
			}
		}

		let encoded = try encode(IntEncoding(key: 17))

		// We can't compare JSON strings here since key ordering is non-deterministic, so decode to a `Dictionary` instead.
		let dict = try decode([String: [String: Int]].self, from: encoded)
		XCTAssertEqual(17, dict["top"]?["second"])
	}

	/// Test that arrays encode correctly.
	func testArrayEncoding() throws {
		struct ArrayEncoding: DeepEncodable {
			static let codingTree = CodingTree {
				Key("top") {
					Key("second", containing: \._key)
				}
			}


			@Value var key: [String]

			init(key: [String]) {
				self.key = key
			}
		}

		let encoded = try encode(ArrayEncoding(key: ["secondValue1", "secondValue2"]))

		// We can't compare JSON strings here since key ordering is non-deterministic, so decode to a `Dictionary` instead.
		let dict = try decode([String: [String: [String]]].self, from: encoded)
		XCTAssertEqual(["secondValue1", "secondValue2"], dict["top"]?["second"])
	}

	/// Test that an arbitrary `Codable` struct encodes correctly.
	func testStructEncoding() throws {
		struct StructEncoding: DeepEncodable {
			static let codingTree = CodingTree {
				Key("top") {
					Key("second", containing: \._key)
				}
			}


			struct InternalStruct: Codable {
				let key: String
			}

			@Value var key: InternalStruct

			init(key: InternalStruct) {
				self.key = key
			}
		}


		let encoded = try encode(StructEncoding(key: .init(key: "nestedValue")))

		// We can't compare JSON strings here since key ordering is non-deterministic, so decode to a `Dictionary` instead.
		let dict = try decode([String: [String: StructEncoding.InternalStruct]].self, from: encoded)
		XCTAssertEqual("nestedValue", dict["top"]?["second"]?.key)
	}


	/// Test that normal `Decodable` behavior is unchanged while deep encoding behaves as expected.
	func testDecodableNonInterference() throws {
		struct DeepEncodableDecoding: DeepEncodable, Decodable {
			static let codingTree = CodingTree {
				Key("top") {
					Key("second") {
						Key("third", containing: \._key)
					}
				}
			}

			@Value var key: String

			init(key: String) {
				self.key = key
			}
		}


		let encoded = try encode(DeepEncodableDecoding(key: "thirdValue"))

		// We can't compare JSON strings here since key ordering is non-deterministic, so decode to a `Dictionary` instead.
		let dict = try decode([String: [String: [String: String]]].self, from: encoded)
		XCTAssertEqual("thirdValue", dict["top"]?["second"]?["third"])


		let json = """
			{
				"key": "thirdValue"
			}
			"""
		let decoded = try decode(DeepEncodableDecoding.self, from: json)

		XCTAssertEqual("thirdValue", decoded.key)
	}


	/// Test that providing all `nil` values to a struct with only optional properties will result in an empty encoding.
	func testOptionalValuesEncodeEmpty() throws {
		struct OptionalValuesEncodeEmpty: DeepEncodable {
			static let codingTree = CodingTree {
				Key("top") {
					Key("second1") {
						Key("third1", containing: \._key1)
					}

					Key("second2") {
						Key("third2") {
							Key("fourth2", containing: \._key2)
						}
					}
				}
			}

			@Value var key1: String?
			@Value var key2: String?
		}


		let expected = "{}"
		let actual = try encode(OptionalValuesEncodeEmpty())
		XCTAssertEqual(expected, actual)
	}


	/**
	Test that optionals encode correctly when the same type is encoded as `nil`, then with some value.

	It's been removed now, but during development there was some caching added to recursing operations in encoding that was accidentally retained across encodings and resulted in values being omitted on the next encode, so this is here to make sure that doesn't happen again.
	*/
	func testOptionalEncodingSameTypeNilThenValue() throws {
		struct OptionalEncodingSameTypeNilThenValue: DeepEncodable {
			static let codingTree = CodingTree {
				Key("top") {
					Key("second", containing: \._key)
				}
			}


			@Value var key: String?

			init(key: String? = nil) {
				self.key = key
			}
		}


		let encoded1 = try encode(OptionalEncodingSameTypeNilThenValue(key: nil))
		XCTAssertEqual("{}", encoded1)


		let encoded2 = try encode(OptionalEncodingSameTypeNilThenValue(key: "secondValue"))

		// We can't compare JSON strings here since key ordering is non-deterministic, so decode to a `Dictionary` instead.
		let dict = try decode([String: [String: String]].self, from: encoded2)
		XCTAssertEqual("secondValue", dict["top"]?["second"])
	}

	/**
	Test that optionals encode correctly when the same type is encoded with some value, then as `nil`.

	It's been removed now, but during development there was some caching added to recursing operations in encoding that was accidentally retained across encodings and resulted in values being omitted on the next encode, so this is here to make sure that doesn't happen again.
	*/
	func testOptionalEncodingSameTypeValueThenNil() throws {
		struct OptionalEncodingSameTypeValueThenNil: DeepEncodable {
			static let codingTree = CodingTree {
				Key("top") {
					Key("second", containing: \._key)
				}
			}


			@Value var key: String?

			init(key: String? = nil) {
				self.key = key
			}
		}


		let encoded1 = try encode(OptionalEncodingSameTypeValueThenNil(key: "secondValue"))

		// We can't compare JSON strings here since key ordering is non-deterministic, so decode to a `Dictionary` instead.
		let dict = try decode([String: [String: String]].self, from: encoded1)
		XCTAssertEqual("secondValue", dict["top"]?["second"])


		let encoded2 = try encode(OptionalEncodingSameTypeValueThenNil(key: nil))
		XCTAssertEqual("{}", encoded2)
	}


	/**
	Test that optionals encode correctly when the same mutable instance is encoded as `nil`, then with some value.

	It's been removed now, but during development there was some caching added to recursing operations in encoding that was accidentally retained across encodings and resulted in values being omitted on the next encode, so this is here to make sure that doesn't happen again.
	*/
	func testOptionalEncodingSameInstanceNilThenValue() throws {
		struct OptionalEncodingSameInstanceNilThenValue: DeepEncodable {
			static let codingTree = CodingTree {
				Key("top") {
					Key("second", containing: \._key)
				}
			}


			@Value var key: String?

			init(key: String? = nil) {
				self.key = key
			}
		}


		let instance = OptionalEncodingSameInstanceNilThenValue(key: nil)

		let encoded1 = try encode(instance)
		XCTAssertEqual("{}", encoded1)


		instance.key = "secondValue"

		let encoded2 = try encode(instance)
		// We can't compare JSON strings here since key ordering is non-deterministic, so decode to a `Dictionary` instead.
		let dict = try decode([String: [String: String]].self, from: encoded2)
		XCTAssertEqual("secondValue", dict["top"]?["second"])
	}

	/**
	Test that optionals encode correctly when the same mutable instance is encoded with some value, then as `nil`.

	It's been removed now, but during development there was some caching added to recursing operations in encoding that was accidentally retained across encodings and resulted in values being omitted on the next encode, so this is here to make sure that doesn't happen again.
	*/
	func testOptionalEncodingSameInstanceValueThenNil() throws {
		struct OptionalEncodingSameInstanceValueThenNil: DeepEncodable {
			static let codingTree = CodingTree {
				Key("top") {
					Key("second", containing: \._key)
				}
			}


			@Value var key: String?

			init(key: String? = nil) {
				self.key = key
			}
		}


		let instance = OptionalEncodingSameInstanceValueThenNil(key: "secondValue")

		let encoded1 = try encode(instance)
		// We can't compare JSON strings here since key ordering is non-deterministic, so decode to a `Dictionary` instead.
		let dict = try decode([String: [String: String]].self, from: encoded1)
		XCTAssertEqual("secondValue", dict["top"]?["second"])

		instance.key = nil

		let encoded2 = try encode(instance)
		XCTAssertEqual("{}", encoded2)
	}
}
