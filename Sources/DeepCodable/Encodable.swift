/**
A type that can encode itself to an arbitrarily deep tree structure

Unlike `DeepDecodable`, no limitations are placed on `let` vs `var` for properties of conforming types since we're encoding an already constructed instance.
*/
public protocol DeepEncodable: _DeepCodingTreeDefiner, Encodable {}


// Provide a default encoding implementation that just delegates to the defined coding tree.
public extension DeepEncodable {
	func encode(to encoder: Encoder) throws {
		try Self.codingTree.encode(to: encoder, from: self)
	}
}
public extension DeepCodingTree where Root: DeepEncodable {
	/**
	Encode values into the input encoder, reading the corresponding properties on the input instance to be encoded.

	Does not actually do any encoding itself, just starts the recursive tree walking and lets the nodes handle actual encoding.

	- Parameters:
		- encoder: `Codable` encoder instance encoding to the serialized representation
		- target: instance of the type being encoded, from which values to encode should be read

	- Throws: Only rethrows errors produced in normal `Codable` encoding
	*/
	func encode(to encoder: Encoder, from target: Root) throws {
		var container = encoder.container(keyedBy: DynamicStringCodingKey.self)

		for node in self.nodes {
			try node.encode(to: &container, from: target)
		}
	}
}
internal extension DeepCodingNode where Root: DeepEncodable {
	/**
	Encode values from the input instance into the input encoder for serialization.

	Invokes the stored implementation closure to allow for type-erasure of any `KeyPath` value types.

	- Parameters:
		- container: `Codable` encoding container instance representing the serialized representation
		- target: instance of the type being encoded, from which values to be encoded should be read

	- Throws: Only rethrows errors produced in normal `Codable` encoding
	*/
	func encode(to container: inout EncodingContainer, from target: Root) throws {
		if let encodeImplementation = self.encodeImplementation {
			try encodeImplementation(&container, target)
		}
	}
}


internal extension DeepCodingNode where Root: DeepEncodable {
	/**
	Check if the node should be encoded given a specific target instance, to prevent encoding a deeply nested tree that just ends in `null`.

	Invokes the stored implementation closure to allow for type-erasure of any `KeyPath` value types.

	- Parameter target: instance of the type being encoded, from which values to be encoded should be read
	- Returns: whether the node should have a key created for it in the serialized representation
	*/
	func shouldEncode(target: Root) -> Bool {
		guard let shouldEncodeImplementation = self.shouldEncodeImplementation else {
			return false
		}

		return shouldEncodeImplementation(target)
	}
}


// Add implementations for encoding when the node contains other nodes.
public extension DeepCodingNode where Root: DeepEncodable {
	/**
	Get the implementation for the `encode` method when this node has children.

	This is just a helper method to centralize the definition of the closure, so it can be referenced from multiple places.
	This can't be a stored/computed property since we need to capture the input parameters into the closure.

	- Parameters:
		- key: coding key used to index this node
		- children: immediate child nodes of this one

	- Returns: A closure conforming to the type needed for calling in `encode`
	*/
	internal static func getRecursingEncodeImplementation(key: String, children: [Self]) -> EncodeSignature {
		return { (container: inout EncodingContainer, target) in
			/*
			Skip creating an encoding container and exit early if no child should be encoded.

			This implementation is tragic, as it will repeatedly call all leaf nodes (and then any intermediate nodes between here and them) at every single level of the tree, even though the value on the target hasn't changed.

			Unfortunately we don't have any great options to solve this by memoizing the tree as we walk it - these nodes are defined statically on the root types, so any storage we build into the nodes will need to be cleared after every encoding so that we don't end up accidentally encoding a value that should be omitted or ignoring a real value.

			We can't just use the target itself as a cache key since it isn't guaranteed to be `Equatable` or a class (for identity comparison/`===`).
			We also can't really derive anything that could be used as a key from the target (like a pointer value), since it's perfectly valid for the same target to be mutated and re-encoded.

			We could have the tree itself provide an ephemeral storage container when it calls into the top-level nodes, but then we have to effectively construct a shadow tree inside that container so the nodes can look up their cached value later.
			This would probably be the least gross solution, but it's not worth the complexity at this point - we'll just take the performance hit on encoding (which is probably rarely used) for now and circle back later.
			*/
			guard children.contains(where: { $0.shouldEncode(target: target) }) else {
				return
			}

			var nestedContainer = container.nestedContainer(keyedBy: DynamicStringCodingKey.self, forKey: .init(stringValue: key))

			for child in children {
				try child.encode(to: &nestedContainer, from: target)
			}
		}
	}

	/**
	Get the implementation for the `shouldEncode` method when this node has children.

	This is just a helper method to centralize the definition of the closure, so it can be referenced from multiple places.
	This can't be a stored/computed property since we need to capture the input parameters into the closure.

	- Parameter children: immediate child nodes of this one
	- Returns: A closure conforming to the type needed for calling in `shouldEncode`
	*/
	internal static func getRecursingShouldEncodeImplementation(children: [Self]) -> ShouldEncodeSignature {
		return { target in
			// If any of this node's children should be encoded, the node itself must also be.
			return children.contains {
				$0.shouldEncode(target: target)
			}
		}
	}

	/**
	Initialize an instance containing child nodes.

	- Parameters:
		- key: coding key used to index this node
		- builder: closure representing the output of a result builder block
	*/
	init(_ key: String, @TreeBuilder _ builder: () -> [Self]) {
		let children = builder()

		self.children = children

		// If the root type is also `DeepDecodable`, this initializer is overridden - this is only called when the type is actually only `DeepEncodable`.
		self.decodeImplementation = nil
		self.optionalToDecode = true

		self.encodeImplementation = Self.getRecursingEncodeImplementation(key: key, children: children)
		self.shouldEncodeImplementation = Self.getRecursingShouldEncodeImplementation(children: children)
	}
}


// Add implementations for encoding when the node represents a non-optional value directly.
public extension DeepCodingNode where Root: DeepEncodable {
	/**
	Get the implementation for the `encode` method when this node represents a non-optional value directly.

	This is just a helper method to centralize the definition of the closure, so it can be referenced from multiple places.
	This can't be a stored/computed property since we need to capture the input parameters into the closure.

	- Parameters:
		- key: coding key used to index this node
		- targetPath: key path into the root type where the value to be encoded should be read from

	- Returns: A closure conforming to the type needed for calling in `encode`
	*/
	internal static func getDirectEncodeImplementation<Value: Encodable>(key: String, targetPath: KeyPath<Root, Value>) -> EncodeSignature {
		return { (container: inout EncodingContainer, target) in
			try container.encode(target[keyPath: targetPath], forKey: .init(stringValue: key))
		}
	}

	/**
	Get the implementation for the `shouldEncode` method when this node represents a non-optional value directly.

	This is just a helper method to centralize the definition of the closure, so it can be referenced from multiple places.
	This can't be a stored/computed property since we need to capture the input parameters into the closure.

	- Parameter targetPath: key path into the root type where the value to be encoded should be read from (though this isn't actually used in this implementation)
	- Returns: A closure conforming to the type needed for calling in `shouldEncode`
	*/
	internal static func getDirectShouldEncodeImplementation<Value: Encodable>(targetPath _: KeyPath<Root, Value>) -> ShouldEncodeSignature {
		return { _ in true }
	}

	/**
	Initialize an instance directly representing a non-optional value.

	This method type-erases the input key path's value type using stored closures (which do not expose the value's type), so parents of this node can simply use arrays of this node without any other hassles from generics.

	Note that this will also match nodes containing a non-optional `@CodingValue`-wrapped value, which is fine since we want identical behaviors.

	- Parameters:
		- key: coding key used to index this node
		- targetPath: key path into the root type where the value to be encoded should be read from
	*/
	init<Value: Encodable>(_ key: String, containing targetPath: KeyPath<Root, Value>) {
		self.children = nil

		// If the root type is also `DeepDecodable`, this initializer is overridden - this is only called when the type is actually only `DeepEncodable`.
		self.decodeImplementation = nil
		self.optionalToDecode = true

		self.encodeImplementation = Self.getDirectEncodeImplementation(key: key, targetPath: targetPath)
		self.shouldEncodeImplementation = Self.getDirectShouldEncodeImplementation(targetPath: targetPath)
	}
}


// Add implementations for encoding when the node represents an optional value directly.
public extension DeepCodingNode where Root: DeepEncodable {
	/**
	Get the implementation for the `encode` method when this node represents an optional value directly.

	This is just a helper method to centralize the definition of the closure, so it can be referenced from multiple places.
	This can't be a stored/computed property since we need to capture the input parameters into the closure.

	- Parameters:
		- key: coding key used to index this node
		- targetPath: key path into the root type where the value to be encoded should be read from

	- Returns: A closure conforming to the type needed for calling in `encode`
	*/
	internal static func getDirectEncodeImplementation<Value: Encodable>(key: String, targetPath: KeyPath<Root, Value?>) -> EncodeSignature {
		return { (container: inout EncodingContainer, target) in
			try container.encodeIfPresent(target[keyPath: targetPath], forKey: .init(stringValue: key))
		}
	}

	/**
	Get the implementation for the `shouldEncode` method when this node represents an optional value directly.

	This is just a helper method to centralize the definition of the closure, so it can be referenced from multiple places.
	This can't be a stored/computed property since we need to capture the input parameters into the closure.

	- Parameter targetPath: key path into the root type where the value to be encoded should be read from
	- Returns: A closure conforming to the type needed for calling in `shouldEncode`
	*/
	internal static func getDirectShouldEncodeImplementation<Value: Encodable>(targetPath: KeyPath<Root, Value?>) -> ShouldEncodeSignature {
		return { target in
			return (target[keyPath: targetPath] != nil)
		}
	}

	/**
	Initialize an instance directly representing an optional value.

	This method type-erases the input key path's value type using stored closures (which do not expose the value's type), so parents of this node can simply use arrays of this node without any other hassles from generics.

	- Parameters:
		- key: coding key used to index this node
		- targetPath: key path into the root type where the value to be encoded should be read from
	*/
	init<Value: Encodable>(_ key: String, containing targetPath: KeyPath<Root, Value?>) {
		self.children = nil

		// If the root type is also `DeepDecodable`, this initializer is overridden - this is only called when the type is actually only `DeepEncodable`.
		self.decodeImplementation = nil
		self.optionalToDecode = true

		self.encodeImplementation = Self.getDirectEncodeImplementation(key: key, targetPath: targetPath)
		self.shouldEncodeImplementation = Self.getDirectShouldEncodeImplementation(targetPath: targetPath)
	}
}


// Add implementations for encoding when the node represents an optional value wrapped in a `@CodingValue` property wrapper.
public extension DeepCodingNode where Root: DeepEncodable {
	/**
	Get the implementation for the `encode` method when this node represents an optional value directly and the property is wrapped in a `DeepCodingValue` property wrapper.

	We need this specialized implementation for the wrapped-optional case to prevent empty keys from making it into the output serialization.
	If not defined, since the property wrapper is a non-optional type, we'd revert to the non-optional implementation and end up with an empty key.

	This is just a helper method to centralize the definition of the closure, so it can be referenced from multiple places.
	This can't be a stored/computed property since we need to capture the input parameters into the closure.

	- Parameters:
		- key: coding key used to index this node
		- targetPath: key path into the root type where the value to be encoded should be read from

	- Returns: A closure conforming to the type needed for calling in `encode`
	*/
	internal static func getDirectEncodeImplementation<Value: Encodable>(key: String, targetPath: KeyPath<Root, DeepCodingValue<Value?>>) -> EncodeSignature {
		return { (container: inout EncodingContainer, target) in
			try container.encodeIfPresent(target[keyPath: targetPath], forKey: .init(stringValue: key))
		}
	}

	/**
	Get the implementation for the `shouldEncode` method when this node represents an optional value wrapped in a `@CodingValue` property wrapper.

	We need this specialized implementation for the wrapped-optional case to prevent empty keys from making it into the output serialization.
	If not defined, since the property wrapper is a non-optional type, we'd revert to the non-optional implementation and end up with an empty key.

	This is just a helper method to centralize the definition of the closure, so it can be referenced from multiple places.
	This can't be a stored/computed property since we need to capture the input parameters into the closure.

	- Parameter targetPath: key path into the root type where the value to be encoded should be read from
	- Returns: A closure conforming to the type needed for calling in `shouldEncode`
	*/
	internal static func getDirectShouldEncodeImplementation<Value: Encodable>(targetPath: KeyPath<Root, DeepCodingValue<Value?>>) -> ShouldEncodeSignature {
		return { target in
			return (target[keyPath: targetPath].wrappedValue != nil)
		}
	}

	/**
	Initialize an instance representing an optional value wrapped in a `@CodingValue` property wrapper.

	We need this specialized implementation for the wrapped-optional case to prevent empty keys from making it into the output serialization.
	If not defined, since the property wrapper is a non-optional type, we'd revert to the non-optional implementation and end up with an empty key.

	This method type-erases the input key path's value type using stored closures (which do not expose the value's type), so parents of this node can simply use arrays of this node without any other hassles from generics.

	- Parameters:
		- key: coding key used to index this node
		- targetPath: key path into the root type where the value to be encoded should be read from
	*/
	init<Value: Encodable>(_ key: String, containing targetPath: KeyPath<Root, DeepCodingValue<Value?>>) {
		self.children = nil

		// If the root type is also `DeepDecodable`, this initializer is overridden - this is only called when the type is actually only `DeepEncodable`.
		self.decodeImplementation = nil
		self.optionalToDecode = true

		self.encodeImplementation = Self.getDirectEncodeImplementation(key: key, targetPath: targetPath)
		self.shouldEncodeImplementation = Self.getDirectShouldEncodeImplementation(targetPath: targetPath)
	}
}