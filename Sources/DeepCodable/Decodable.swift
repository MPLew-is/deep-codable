/**
A type that can decode itself from an arbitrarily deep tree structure

All properties on this type that are to be decoded from a serialized representation must be `var` properties and have a default value, so the decoder can fill them in as it walks the serialized tree.
In general, the `CodingValue` property wrapper should be used to allow for clear type definitions (otherwise, values would likely have to be optional), which will handle this conformance and associated corner-cases.
*/
public protocol DeepDecodable: _DeepCodingTreeDefiner, Decodable {
	/**
	Initialize an instance with only default values.

	This empty initializer is required for decoding, as the implementation uses `KeyPath`s to fill in the instance's properties as it decodes the encoded tree.
	This also precludes the use of `let` properties as the values must be modifiable by the decoding implementation during tree traversal.
	*/
	init()
}

// Provide a default decoding implementation that just delegates to the defined coding tree.
public extension DeepDecodable {
	init(from decoder: Decoder) throws {
		self.init()

		try Self.codingTree.decode(from: decoder, into: &self)
	}
}
public extension DeepCodingTree where Root: DeepDecodable {
	/**
	Decode values from the input decoder, setting the corresponding properties on the input instance to be decoded.

	Does not actually do any decoding itself, just starts the recursive tree walking and lets the nodes handle actual decoding.

	- Parameters:
		- decoder: `Codable` decoder instance representing the serialized representation
		- target: instance of the type being decoded, into which decoded values should be written

	- Throws: Only rethrows errors produced in normal `Codable` decoding
	*/
	func decode(from decoder: Decoder, into target: inout Root) throws {
		let container = try decoder.container(keyedBy: DynamicStringCodingKey.self)
		try self.decode(from: container, into: &target)
	}

	/**
	Decode values from the input container, setting the corresponding properties on the input instance to be decoded.

	Does not actually do any decoding itself, just starts the recursive tree walking and lets the nodes handle actual decoding.

	- Parameters:
		- container: `Codable` container instance representing the serialized representation
		- target: instance of the type being decoded, into which decoded values should be written

	- Throws: Only rethrows errors produced in normal `Codable` decoding
	*/
	func decode(from container: DecodingContainer, into target: inout Root) throws {
		for node in self.nodes {
			try node.decode(from: container, into: &target)
		}
	}
}
internal extension DeepCodingNode where Root: DeepDecodable {
	/**
	Decode values from the input decoder, setting the corresponding properties on the input instance to be decoded.

	Invokes the stored implementation closure to allow for type-erasure of any `KeyPath` value types.

	- Parameters:
		- container: `Codable` decoding container instance representing the serialized representation
		- target: instance of the type being decoded, into which decoded values should be written

	- Throws: Only rethrows errors produced in normal `Codable` decoding
	*/
	func decode(from container: DecodingContainer, into target: inout Root) throws {
		if let decodeImplementation = self.decodeImplementation {
			try decodeImplementation(container, &target)
		}
	}
}


// Add implementations for decoding when the node contains other nodes.
public extension DeepCodingNode where Root: DeepDecodable {
	/**
	Get the implementation for the `decode` method when this node has children.

	This is just a helper method to centralize the definition of the closure, so it can be referenced from multiple places.
	This can't be a stored/computed property since we need to capture the input parameters into the closure.

	- Parameters:
		- key: coding key used to index this node
		- children: immediate child nodes of this one

	- Returns: A closure conforming to the type needed for calling in `decode` (or `nil` if no children can decode anything)
	*/
	internal static func getRecursingDecodeImplementation(key: String, children: [Self], optionalToDecode: Bool) -> DecodeSignature {
		return { (container, target: inout Root) in
			let nestedContainer: DecodingContainer

			// If this node is optional, silently ignore if its corresponding key is missing.
			if optionalToDecode {
				guard let nestedContainer_optional = try? container.nestedContainer(keyedBy: DynamicStringCodingKey.self, forKey: .init(stringValue: key)) else {
					return
				}

				nestedContainer = nestedContainer_optional
			}
			// Otherwise, propagate decoding errors back to the caller.
			else {
				nestedContainer = try container.nestedContainer(keyedBy: DynamicStringCodingKey.self, forKey: .init(stringValue: key))
			}


			for child in children {
				try child.decode(from: nestedContainer, into: &target)
			}
		}
	}


	/**
	Initialize an instance containing child nodes from a result builder, providing multiple intermediate keys at once in a "flattened" initializer format.

	- Parameters:
		- key: root coding key used to index this node
		- intermediateKeys: any intermediate keys that should also be added as recursive descendants to this node, before adding the children (can be empty)
		- builder: closure representing the output of a result builder block containing child nodes
	*/
	init(_ key: String, _ intermediateKeys: String..., @TreeBuilder builder: () -> [Self]) {
		self.init(key: key, intermediateKeys: intermediateKeys, children: builder())
	}

	/**
	Initialize an instance containing child nodes, attaching the children at an arbitrarily deep level of intermediate nodes.

	This initializer is exposed primarily to allow other libraries to be built on top of this one and provide child nodes directly - primary direct usage should be using other initializers with unlabeled parameters.

	- Parameters:
		- key: root coding key used to index this node
		- intermediateKeys: any intermediate keys that should also be added as recursive descendants to this node, before adding the children (can be empty)
		- children: array of direct child nodes
	*/
	init(key: String, intermediateKeys: [String], children: [Self]) {
		guard !intermediateKeys.isEmpty else {
			self.init(key: key, children: children)
			return
		}

		// When no intermediate keys are provided, this simply falls back to adding the input children directly to this node.
		// Note that the children need to be added to the furthest node down, so we reverse the ordering and build nested children from bottom up.
		var children_current = children
		for intermediateKey in intermediateKeys.reversed() {
			children_current = [.init(key: intermediateKey, children: children_current)]
		}

		self.init(key: key, children: children_current)
	}

	/**
	Initialize an instance containing child nodes directly, without any intermediate nodes.

	This initializer is exposed primarily to allow other libraries to be built on top of this one and provide child nodes directly - primary direct usage should be using other initializers with unlabeled parameters.

	- Parameters:
		- key: coding key used to index this node
		- children: array of direct child nodes
	*/
	init(key: String, children: [Self]) {
		// Nodes are considered optional if all of their children are also optional, or they directly decode an optional value.
		let optionalToDecode = children.allSatisfy(\.optionalToDecode)

		self.children = children

		self.decodeImplementation = Self.getRecursingDecodeImplementation(key: key, children: children, optionalToDecode: optionalToDecode)
		self.optionalToDecode = optionalToDecode

		// If the root type is also `DeepEncodable`, this initializer is overridden - this is only called when the type is actually only `DeepDecodable`.
		self.encodeImplementation = nil
		self.shouldEncodeImplementation = nil
	}
}


// Add implementations for decoding when the node represents a non-optional value.
public extension DeepCodingNode where Root: DeepDecodable {
	/**
	Get the implementation for the `decode` method when this node captures a non-optional value directly.

	This is just a helper method to centralize the definition of the closure, so it can be referenced from multiple places.
	This can't be a stored/computed property since we need to capture the input parameters into the closure.

	- Parameters:
		- key: coding key used to index this node
		- targetPath: key path into the root type where the decoded value should be written

	- Returns: A closure conforming to the type needed for calling in `decode`
	*/
	internal static func getDirectDecodeImplementation<Value: Decodable>(key: String, targetPath: KeyPath<Root, DeepCodingValue<Value>>) -> DecodeSignature {
		return { (container, target: inout Root) in
			target[keyPath: targetPath].wrappedValue = try container.decode(Value.self, forKey: .init(stringValue: key))
		}
	}


	/**
	Initialize an instance capturing a non-optional value to decode, providing multiple intermediate keys at once in a "flattened" initializer format before the actual value.

	This method type-erases the input key path's value type using a stored closure (which does not expose the value's type), so parents of this node can simply use arrays of this node without any other hassles from generics.

	- Parameters:
		- key: root coding key used to index this node
		- intermediateKeys: any intermediate keys that should also be added as recursive descendants to this node, before adding the value-containing node (can be empty)
		- targetPath: key path into the root type where the decoded value should be written
	*/
	init<Value: Decodable>(_ key: String, _ intermediateKeys: String..., containing targetPath: KeyPath<Root, DeepCodingValue<Value>>) {
		/*
		This implementation is simply copy-pasted in multiple places out of necessity.
		If we try to abstract this out into a single place, we lose some generic type context and end up calling the wrong underlying initializer for the actual value type.
		Luckily, this is a pretty small/simple implementation, so it's not too painful.
		*/

		guard let lastIntermediateKey = intermediateKeys.last else {
			self.init(key: key, containing: targetPath)
			return
		}

		let lastChild = Self(key: lastIntermediateKey, containing: targetPath)
		self.init(key: key, intermediateKeys: intermediateKeys.dropLast(), children: [lastChild])
	}

	/**
	Initialize an instance capturing a non-optional value to decode directly, without any intermediate keys.

	This method type-erases the input key path's value type using a stored closure (which does not expose the value's type), so parents of this node can simply use arrays of this node without any other hassles from generics.

	This initializer is exposed primarily to allow other libraries to be built on top of this one and create nodes directly - primary direct usage should be using other initializers with unlabeled parameters.

	- Parameters:
		- key: coding key used to index this node
		- targetPath: key path into the root type where the decoded value should be written
	*/
	init<Value: Decodable>(key: String, containing targetPath: KeyPath<Root, DeepCodingValue<Value>>) {
		self.children = nil
		// This node captures a non-optional value, cannot be optional to decode.
		self.optionalToDecode = false

		self.decodeImplementation = Self.getDirectDecodeImplementation(key: key, targetPath: targetPath)

		// If the root type is also `DeepEncodable`, this initializer is overridden - this is only called when the type is actually only `DeepDecodable`.
		self.encodeImplementation = nil
		self.shouldEncodeImplementation = nil
	}
}


// Add implementations for decoding when the node represents an optional value.
public extension DeepCodingNode where Root: DeepDecodable {
	/**
	Get the implementation for the `decode` method when this node captures an optional value directly.

	This is just a helper method to centralize the definition of the closure, so it can be referenced from multiple places.
	This can't be a stored/computed property since we need to capture the input parameters into the closure.

	- Parameters:
		- key: coding key used to index this node
		- targetPath: key path into the root type where the decoded value should be written

	- Returns: A closure conforming to the type needed for calling in `decode`
	*/
	internal static func getDirectDecodeImplementation<Value: Decodable>(key: String, targetPath: KeyPath<Root, DeepCodingValue<Value?>>) -> DecodeSignature {
		return { (container, target: inout Root) in
			target[keyPath: targetPath].wrappedValue = try container.decodeIfPresent(Value.self, forKey: .init(stringValue: key))
		}
	}


	/**
	Initialize an instance capturing an optional value to decode, providing multiple intermediate keys at once in a "flattened" initializer format before the actual value.

	This method type-erases the input key path's value type using a stored closure (which does not expose the value's type), so parents of this node can simply use arrays of this node without any other hassles from generics.

	- Parameters:
		- key: root coding key used to index this node
		- intermediateKeys: any intermediate keys that should also be added as recursive descendants to this node, before adding the value-containing node (can be empty)
		- targetPath: key path into the root type where the decoded value should be written
	*/
	init<Value: Decodable>(_ key: String, _ intermediateKeys: String..., containing targetPath: KeyPath<Root, DeepCodingValue<Value?>>) {
		/*
		This implementation is simply copy-pasted in multiple places out of necessity.
		If we try to abstract this out into a single place, we lose some generic type context and end up calling the wrong underlying initializer for the actual value type.
		Luckily, this is a pretty small/simple implementation, so it's not too painful.
		*/

		guard let lastIntermediateKey = intermediateKeys.last else {
			self.init(key: key, containing: targetPath)
			return
		}

		let lastChild = Self(key: lastIntermediateKey, containing: targetPath)
		self.init(key: key, intermediateKeys: intermediateKeys.dropLast(), children: [lastChild])
	}

	/**
	Initialize an instance capturing an optional value to decode.

	This method type-erases the input key path's value type using a stored closure (which does not expose the value's type), so parents of this node can simply use arrays of this node without any other hassles from generics.

	This initializer is exposed primarily to allow other libraries to be built on top of this one and create nodes directly - primary direct usage should be using other initializers with unlabeled parameters.

	- Parameters:
		- key: coding key used to index this node
		- targetPath: key path into the root type where the decoded value should be written
	*/
	init<Value: Decodable>(key: String, containing targetPath: KeyPath<Root, DeepCodingValue<Value?>>) {
		self.children = nil
		// This node captures an optional value and is always optional to decode.
		self.optionalToDecode = true

		self.decodeImplementation = Self.getDirectDecodeImplementation(key: key, targetPath: targetPath)

		// If the root type is also `DeepEncodable`, this initializer is overridden - this is only called when the type is actually only `DeepDecodable`.
		self.encodeImplementation = nil
		self.shouldEncodeImplementation = nil
	}
}
