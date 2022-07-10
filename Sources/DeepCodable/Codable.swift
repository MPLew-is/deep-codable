/**
A type that can convert itself into and out of an arbitrarily deep tree structure of an external representation

This is simply an alias for `DeepDecodable` and `DeepEncodable`, like `Codable`.
*/
public typealias DeepCodable = DeepDecodable & DeepEncodable


// Add override implementations when the root type opts into both encoding and decoding.
public extension DeepCodingNode where Root: DeepCodable {
	/**
	Initialize an instance containing child nodes.

	- Parameters:
		- key: coding key used to index this node
		- builder: closure representing the output of a result builder block
	*/
	init(_ key: String, @TreeBuilder _ builder: () -> [Self]) {
		let children = builder()
		let optionalToDecode = children.allSatisfy(\.optionalToDecode)

		self.children = children

		self.decodeImplementation = Self.getRecursingDecodeImplementation(key: key, children: children, optionalToDecode: optionalToDecode)
		self.optionalToDecode = optionalToDecode

		self.encodeImplementation = Self.getRecursingEncodeImplementation(key: key, children: children)
		self.shouldEncodeImplementation = Self.getRecursingShouldEncodeImplementation(children: children)
	}

	/**
	Initialize an instance representing a non-optional value.

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
		- key: coding key used to index this node
		- targetPath: key path into the root type where the values should be read from/written to during decoding/encoding
	*/
	init<Value: Codable>(_ key: String, containing targetPath: WritableKeyPath<Root, DeepCodingValue<Value>>) {
		self.children = nil

		self.decodeImplementation = Self.getDirectDecodeImplementation(key: key, targetPath: targetPath)
		self.optionalToDecode = false

		self.encodeImplementation = Self.getDirectEncodeImplementation(key: key, targetPath: targetPath)
		self.shouldEncodeImplementation = Self.getDirectShouldEncodeImplementation(targetPath: targetPath)
	}


	/**
	Initialize an instance representing an optional value.

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
		- key: coding key used to index this node
		- targetPath: key path into the root type where the values should be read from/written to during decoding/encoding
	*/
	init<Value: Codable>(_ key: String, containing targetPath: WritableKeyPath<Root, DeepCodingValue<Value?>>) {
		self.children = nil

		self.decodeImplementation = Self.getDirectDecodeImplementation(key: key, targetPath: targetPath)
		self.optionalToDecode = true

		self.encodeImplementation = Self.getDirectEncodeImplementation(key: key, targetPath: targetPath)
		self.shouldEncodeImplementation = Self.getDirectShouldEncodeImplementation(targetPath: targetPath)
	}
}
