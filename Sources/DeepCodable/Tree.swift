/**
Object containing the tree structure representing the encoded representation to be decoded into the containing type

Designed to be instantiated using result builder syntax; for example:
```swift
static let codingTree = CodingTree {
	Key("someRootKey") {
		Key("someIntermediateKey") {
			Key("someLeafKey", containing: \._someProperty)
		}
	}

	Key("otherRootKey", containing: \._otherProperty)
}
```
*/
public struct DeepCodingTree<Root> {
	/// Helper object to enable result builder syntax for defining a coding tree
	@resultBuilder
	public struct TreeBuilder<Root> {
		/// Shortcut alias for the type of a node in the tree
		public typealias Node = DeepCodingNode<Root>

		/**
		Aggregate result builder-defined nodes into a list for initializing a parent node (or tree root).

		- Parameter nodes: nodes representing the keys at a given level of hierarchy on the coding tree
		- Returns: A list of nodes to be stored as children on the parent node
		*/
		public static func buildBlock(_ nodes: Node...) -> [Node] {
			return nodes
		}
	}

	/// Shortcut alias for the type of the result builder helper struct
	public typealias Builder = TreeBuilder<Root>
	/// Shortcut alias for the type of the node in the coding tree
	public typealias Node    = Builder.Node


	/// Top-level nodes in the tree
	internal let nodes: [Node]

	/**
	Initialize an instance from the output of a result builder defining the top-level nodes of the tree.

	- Parameter builder: closure representing the output of a result builder block
	*/
	public init(@Builder _ builder: () -> [Node]) {
		self.init(nodes: builder())
	}

	/**
	Initialize an instance from an array of child nodes.

	- Parameter nodes: array of direct child nodes
	*/
	public init(nodes: [Node]) {
		self.nodes = nodes
	}
}


/**
Simple stub protocol defining the `codingTree` requirement used in `DeepDecodable` and `DeepEncodable`, for centralization purposes

Not intended for public use (hence the underscore prefix), but must be `public` since other public protocols inherit from it.
*/
public protocol _DeepCodingTreeDefiner {
	/**
	Shortcut type alias to allow `CodingTree` to be used in the users' type declarations instead of the full type name

	This also has the advantage of scoping this short type name to within the conforming type, rather than polluting the global namespace.
	*/
	typealias CodingTree = DeepCodingTree<Self>

	/**
	Tree representing the mapping from encoded keys to this type's properties

	Designed to be instantiated using result builder syntax; for example:
	```swift
	static let codingTree = CodingTree {
		Key("someRootKey") {
			Key("someIntermediateKey") {
				Key("someLeafKey", containing: \._someProperty)
			}
		}

		Key("otherRootKey", containing: \._otherProperty)
	}
	```
	*/
	static var codingTree: CodingTree { get }
}


/**
A fully dynamic coding key implementation that simply stores the string value it's initialized with

This allows us to map strings provided by the result builder input into keys accepted by the actual `Codable` implementation.

This has to be `internal` since it's used in methods used throughout this module.

Derived from: https://swiftsenpai.com/swift/decode-dynamic-keys-json
*/
internal struct DynamicStringCodingKey: CodingKey {
	let stringValue: String
	init(stringValue: String) {
		self.stringValue = stringValue
	}

	// This is a protocol requirement, but this is only intended to hold strings so just return `nil` for everything `Int`-related.
	let intValue: Int? = nil
	init?(intValue: Int) {
		return nil
	}
}
