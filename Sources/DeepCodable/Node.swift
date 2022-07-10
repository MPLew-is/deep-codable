/// Object representing a node on the coding tree
public struct DeepCodingNode<Root> {
	/// Shortcut alias for the type of the result builder
	public typealias TreeBuilder = DeepCodingTree<Root>.Builder

	/// Immediate children of this node
	internal let children: [Self]?


	/**
	Whether it's acceptable for an error to be thrown trying to create a decoding container for this node's key

	This should be `false` when this node or any of its children have a non-optional decoding value declared, `true` otherwise
	*/
	internal let optionalToDecode: Bool


	/// Shortcut alias for the `shouldEncode` closure's signature
	internal typealias ShouldEncodeSignature = (Root) -> Bool

	/**
	Stored implementation for the `shouldEncode` function defined in an extension, to allow for proper type erasure

	This closure captures any information it needs to write the correct value type into the root object, without having the node object be generic on the type (which will cause issues with storing collections of nodes with different value types).

	While it's not semantically ideal that the bare (non-`Decodable`/`Encodable` struct) has this property, we can't add a stored property in an extension so we have to declare the storage here.
	*/
	internal let shouldEncodeImplementation: ShouldEncodeSignature?


	/**
	Shortcut alias for the container used to decode

	This has to be `internal` since it's used in a method used by other types in this module.
	*/
	internal typealias DecodingContainer = KeyedDecodingContainer<DynamicStringCodingKey>
	/// Shortcut alias for the decode closure's signature
	internal  typealias DecodeSignature   = (DecodingContainer, inout Root) throws -> ()

	/**
	Stored implementation for the `decode` function defined in an extension, to allow for proper type erasure

	This closure captures any information it needs to write the correct value type into the root object, without having the node object be generic on the type (which will cause issues with storing collections of nodes with different value types).

	While it's not semantically ideal that the bare (non-`Decodable`/`Encodable` struct) has this property, we can't add a stored property in an extension so we have to declare the storage here.
	*/
	internal let decodeImplementation: DecodeSignature?


	/**
	Shortcut alias for the container used to encode

	This has to be `public` since it's used in a public-facing method.
	*/
	internal typealias EncodingContainer = KeyedEncodingContainer<DynamicStringCodingKey>
	/// Shortcut alias for the encode closure's signature
	internal  typealias EncodeSignature   = (inout EncodingContainer, Root) throws -> ()

	/**
	Stored implementation for the `encode` function defined in an extension, to allow for proper type erasure

	This closure captures any information it needs to write the correct value type into the encoder, without having the node object be generic on the type (which will cause issues with storing collections of nodes with different value types).

	While it's not semantically ideal that the bare (non-`Decodable`/`Encodable` struct) has this property, we can't add a stored property in an extension so we have to declare the storage here.
	*/
	internal let encodeImplementation: EncodeSignature?
}


public extension _DeepCodingTreeDefiner {
	/**
	Shortcut type alias to allow `Key` to be used in the result builder instead of the full type name

	This also has the advantage of scoping this short type name to within the conforming type, rather than polluting the global namespace.
	*/
	typealias Key = DeepCodingNode<Self>
}
