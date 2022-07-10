/**
Wrapper type for coding values, to allow users to use arbitrary underlying types for the actual values.

If not wrapped, decoding would require the values to be optional (even if the user wanted the value to be required and not have to juggle optionals.
*/
@propertyWrapper
public struct DeepCodingValue<Value> {
	/**
	Simple reference-semantics storage container for the property wrapper, to sidestep `KeyPath` limitations

	Without this indirection, the wrapped value would have to be stored directly on the property wrapper struct, and thus we'd need a `WritableKeyPath`.
	When users are constructing coding trees, key paths to the projected values only come across as (non-writable) `KeyPath`s, so we need to be able to mutate the wrapped value with a read-only key path.

	By storing a reference to a class (and declaring the `set` implementation on `wrappedValue` as `nonmutating`), we can successfully write values to the underlying storage without mutating the actual wrapper struct, thus giving our users a simpler interface for declaring values to decode.
	*/
	fileprivate class Storage<Value> {
		/// Simple enum indicating the storage's initialization state
		fileprivate enum Wrapped<Value> {
			case empty
			case value(Value)
		}

		/// Actual storage for the value being wrapped in the parent property wrapper, contained in an enum indicating if the value has been initialized yet
		fileprivate var _value: Wrapped<Value>

		/// Initialize to the default "empty" state.
		fileprivate init() {
			self._value = .empty
		}


		/// Value being stored by this container
		var value: Value {
			get {
				switch self._value {
					case .empty:
						// We should never get here in normal usage, but we need to have something here that terminates execution in order to compile.
						// The only alternative is to make this getter throwing, but that seems nasty since it will impact every access in user code to a wrapped property.
						fatalError("Unexpected empty storage")

					case .value(let value):
						return value
				}
			}

			set {
				self._value = .value(newValue)
			}
		}
	}

	/// Storage instance with reference semantics to allow mutating the wrapped value without mutating this struct itself
	private let storage: Storage<Value> = .init()


	/**
	Initialize this property wrapper with a default value.

	This initializer will be called when the wrapper is declared like:
	```swift
	@CodingValue var example: String = "example"
	```

	- Parameter wrappedValue: value being wrapped by this instance
	*/
	public init(wrappedValue: Value) {
		self.storage.value = wrappedValue
	}

	/**
	Initialize this property wrapper with no default value.

	This initializer will be called when the wrapper is declared like:
	```swift
	@CodingValue var example: String
	```

	After invoking this initializer, the property wrapped will be in an uninitialized state and any attempts to read the wrapped value until it's set elsewhere will result in a `fatalError`.
	*/
	public init() {}

	/**
	Underlying value contained by this wrapper

	Note that if the wrapped value is attempted to be read before initialized with an actual value, a `fatalError` will result.
	In normal usage, this should not occur, since one of the following scenarios should always occur:
	- The wrapped property has a default value, and we never have an uninitialized state
	- The wrapped property is optional and implicitly given a default of `nil`
	- The wrapped property is successfully decoded from the serialized representation
	- The wrapped property is not successfully decoded from the serialized representation, but an error is thrown by the decoding container at that point so this value can never have an access attempt anyway

	This architecture is inspired by [the equivalent handling in `ArgumentParser`](https://github.com/apple/swift-argument-parser/blob/df9ee6676cd5b3bf5b330ec7568a5644f547201b/Sources/ArgumentParser/Parsable%20Properties/Option.swift#L76-L87), which deals with the same set of problems.
	*/
	public var wrappedValue: Value {
		get { self.storage.value }

		// By declaring this `nonmutating`, we can use normal variable set syntax without needing a `WritableKeyPath`, since the compiler knows this doesn't mutate the actual struct.
		nonmutating set {
			self.storage.value = newValue
		}
	}
}


/**
Simple stub protocol to allow conditional extensions to check if a given value is `Optional`

This can be used, for instance, to replicate implicit-default-`nil` behavior for a property wrapper that wraps an optional, which would otherwise be lost.

Not intended for public use (hence the underscore prefix), but must be `public` since other public types use it in public extensions.
*/
public protocol _OptionalValue: ExpressibleByNilLiteral {}

/*
Add an empty protocol to `Optional`, to allow us to add conditional extensions when the wrapped value is optional.
We don't want to just check for `ExpressibleByNilLiteral` conformance, since true optionals are the only type that gets an implicit default of `nil` (which is the behavior we're actually trying to replicate).
*/
extension Optional: _OptionalValue {}

/*
If the value being wrapped is optional, set the value to `nil` upon initialization.
This replicates the normal behavior that optional values implicitly get `nil` as a default, and cuts off further cases where the `fatalError` in getting the wrapped value could be triggered.
*/
extension DeepCodingValue where Value: _OptionalValue {
	public init() {
		self.storage.value = nil
	}
}


// Pass through `Decodable` behavior and conformance from the wrapped type.
extension DeepCodingValue: Decodable where Value: Decodable {
	public init(from decoder: Decoder) throws {
		self.wrappedValue = try .init(from: decoder)
	}
}

// Pass through `Encodable` behavior and conformance from the wrapped type.
extension DeepCodingValue: Encodable where Value: Encodable {
	public func encode(to encoder: Encoder) throws {
		return try self.wrappedValue.encode(to: encoder)
	}
}


public extension _DeepCodingTreeDefiner {
	/**
	Shortcut type alias to allow `Value` to be used in the property wrapper instead of the full type name

	This also has the advantage of scoping this short type name to within the conforming type, rather than polluting the global namespace.
	*/
	typealias Value = DeepCodingValue
}
