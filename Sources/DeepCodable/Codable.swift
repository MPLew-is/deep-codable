/**
A type that can convert itself into and out of an arbitrarily deep tree structure of an external representation

This is simply an alias for `DeepDecodable` and `DeepEncodable`, like `Codable`.
*/
public typealias DeepCodable = DeepDecodable & DeepEncodable


// Add override implementations for encoding and decoding when the root type opts into it, and this node contains children.
public extension DeepCodingNode where Root: DeepCodable {
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

		// When no intermediate keys are provided, this simply falls back to adding the children from the builder directly to this node.
		// Note that the builder children need to be added to the furthest node down, so we reverse the ordering and build nested children from bottom up.
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
		let optionalToDecode = children.allSatisfy(\.optionalToDecode)

		self.children = children

		self.decodeImplementation = Self.getRecursingDecodeImplementation(key: key, children: children, optionalToDecode: optionalToDecode)
		self.optionalToDecode = optionalToDecode

		self.encodeImplementation = Self.getRecursingEncodeImplementation(key: key, children: children)
		self.shouldEncodeImplementation = Self.getRecursingShouldEncodeImplementation(children: children)
	}
}

// Add override implementations for encoding and decoding when the root type opts into it, and this node represents a value.
public extension DeepCodingNode where Root: DeepCodable {
	/**
	Initialize an instance representing a non-optional value, providing multiple intermediate keys at once in a "flattened" initializer format before the actual value.

	This method type-erases the input key path's value type using a stored closure (which does not expose the value's type), so parents of this node can simply use arrays of this node without any other hassles from generics.

	Note that the `init<Value: Decodable>` and `init<Value: Encodable>` methods defined previously still exist, but will only be invoked when the root type conforms to `DeepCodable` but one of the node capture types only conforms to either `Decodable` or `Encodable`.
	This should pretty much never happen (why would a user want both encoding and decoding, and then have one of the properties only provide one side of that?), but if it does the `encode`/`decode` implementation will fall back to `nil` and the node will be silently ignored during tree traversal for whichever coding type is missing.

	This means that someone could purposely have a value they want to read from deep in a tree, but not be present when re-encoded (if that's what they really want).

	Alternatives to this design that were considered were:

	- Providing `init?<Value: Decodable>` and `init?<Value: Encodable>` methods on this extension that just return `nil`, which will be preferred over the others
		- Users would then be alerted with a compile-time error that they need to handle the optional, but no clearer error message could be given which might lead to some painful debugging and/or runtime crashes

	- Providing `init<Value: Decodable>` and `init<Value: Encodable>` methods on this extension that are marked as unavailable/deprecated
		- This would be the best since a custom message could be returned telling the user how to fix it, but it just flat-out didn't work and silently fell back to the other declarations

	- Parameters:
		- key: root coding key used to index this node
		- intermediateKeys: any intermediate keys that should also be added as recursive descendants to this node, before adding the children (can be empty)
		- targetPath: key path into the root type where the values should be read from/written to during decoding/encoding
	*/
	init<Value: Codable>(_ key: String, _ intermediateKeys: String..., containing targetPath: WritableKeyPath<Root, DeepCodingValue<Value>>) {
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
	Initialize an instance representing a non-optional value directly, without any intermediate keys.

	This method type-erases the input key path's value type using a stored closure (which does not expose the value's type), so parents of this node can simply use arrays of this node without any other hassles from generics.

	This initializer is exposed primarily to allow other libraries to be built on top of this one and provide child nodes directly - primary direct usage should be using other initializers with unlabeled parameters.

	- Parameters:
		- key: coding key used to index this node
		- targetPath: key path into the root type where the values should be read from/written to during decoding/encoding
	*/
	init<Value: Codable>(key: String, containing targetPath: WritableKeyPath<Root, DeepCodingValue<Value>>) {
		self.children = nil

		self.decodeImplementation = Self.getDirectDecodeImplementation(key: key, targetPath: targetPath)
		self.optionalToDecode = false

		self.encodeImplementation = Self.getDirectEncodeImplementation(key: key, targetPath: targetPath)
		self.shouldEncodeImplementation = Self.getDirectShouldEncodeImplementation(targetPath: targetPath)
	}


	/**
	Initialize an instance representing an optional value, providing multiple intermediate keys at once in a "flattened" initializer format before the actual value.

	This method type-erases the input key path's value type using a stored closure (which does not expose the value's type), so parents of this node can simply use arrays of this node without any other hassles from generics.

	Note that the `init<Value: Decodable>` and `init<Value: Encodable>` methods defined previously still exist, but will only be invoked when the root type conforms to `DeepCodable` but one of the node capture types only conforms to either `Decodable` or `Encodable`.
	This should pretty much never happen (why would a user want both encoding and decoding, and then have one of the properties only provide one side of that?), but if it does the `encode`/`decode` implementation will fall back to `nil` and the node will be silently ignored during tree traversal for whichever coding type is missing.

	This means that someone could purposely have a value they want to read from deep in a tree, but not be present when re-encoded (if that's what they really want).

	Alternatives to this design that were considered were:

	- Providing `init?<Value: Decodable>` and `init?<Value: Encodable>` methods on this extension that just return `nil`, which will be preferred over the others
		- Users would then be alerted with a compile-time error that they need to handle the optional, but no clearer error message could be given which might lead to some painful debugging and/or runtime crashes

	- Providing `init<Value: Decodable>` and `init<Value: Encodable>` methods on this extension that are marked as unavailable/deprecated
		- This would be the best since a custom message could be returned telling the user how to fix it, but it just flat-out didn't work and silently fell back to the other declarations

	- Parameters:
		- key: root coding key used to index this node
		- intermediateKeys: any intermediate keys that should also be added as recursive descendants to this node, before adding the children (can be empty)
		- targetPath: key path into the root type where the values should be read from/written to during decoding/encoding
	*/
	init<Value: Codable>(_ key: String, _ intermediateKeys: String..., containing targetPath: WritableKeyPath<Root, DeepCodingValue<Value?>>) {
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
	Initialize an instance representing an optional value directly, without any intermediate keys.

	This method type-erases the input key path's value type using a stored closure (which does not expose the value's type), so parents of this node can simply use arrays of this node without any other hassles from generics.

	This initializer is exposed primarily to allow other libraries to be built on top of this one and provide child nodes directly - primary direct usage should be using other initializers with unlabeled parameters.

	- Parameters:
		- key: coding key used to index this node
		- targetPath: key path into the root type where the values should be read from/written to during decoding/encoding
	*/
	init<Value: Codable>(key: String, containing targetPath: WritableKeyPath<Root, DeepCodingValue<Value?>>) {
		self.children = nil

		self.decodeImplementation = Self.getDirectDecodeImplementation(key: key, targetPath: targetPath)
		self.optionalToDecode = true

		self.encodeImplementation = Self.getDirectEncodeImplementation(key: key, targetPath: targetPath)
		self.shouldEncodeImplementation = Self.getDirectShouldEncodeImplementation(targetPath: targetPath)
	}
}
