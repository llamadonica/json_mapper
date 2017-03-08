library json_mapper.metadata;

import 'package:json_mapper/src/abstract_mapper_factory.dart';
import 'package:json_mapper/json_mapper.dart' as global;
import 'package:quiver/collection.dart';

/// Annotation to mark a field withing an object as encodable.
///
/// Only fields marked with @[Field] will be encoded by the encoder.
class Field {
  /// The key to use for encoding.
  final String model;

  /// Create a new [Field] object.
  const Field({this.model});
}

/// A type used throughout json_mapper to refer to the specific type of an
/// operation.
///
/// A [ConcreteType] is used to decode an object. When the json_mapper
/// transformer runs, calls to `new ConcreteType<T>()` are located to ensure
/// that all fully reified types of generics have mappers created when
/// necessary.
class ConcreteType<T> {
  /// The inner [Type] of a [ConcreteType].
  final Type type = T;

  /// Create a new [ConcreteType] object.
  ConcreteType();
}

/// A helper mixin used when writing [Codec]s for the `Opaque` types.
///
/// An opaque type generally, is a type that can be encoded and decoded
/// to and from json without any change4 to the underlying data. It's useful
/// when the type of json decode can't be determined, but you still need to
/// faithfully reproduce the information.
abstract class OpaqueDelegate<T extends OpaqueDelegate<T, D>, D> {
  /// The underlying delegate object.
  D get delegate;
}

/// An opaque [Map], which, when encoded will be the same map as it was encoded
/// from.
class OpaqueMap extends DelegatingMap<String, dynamic>
    implements OpaqueDelegate<OpaqueMap, Map<String, dynamic>> {
  @override
  final Map<String, dynamic> delegate;

  /// Create a new [OpaqueMap] object.
  OpaqueMap(this.delegate);
}

/// An opaque [List], which, when encoded will be the same list as it was
/// encoded from.
class OpaqueList extends DelegatingList<dynamic>
    implements OpaqueDelegate<OpaqueList, List<dynamic>> {
  @override
  final List<dynamic> delegate;

  /// Create a new [OpaqueList] object.
  OpaqueList(this.delegate);
}

/// A mixin applied to objects that can be encoded, intended as a convenience.
///
/// This won't fully replace the @[Field] annotation, but it ensures that
/// the [ConcreteType]<T> is created and that the object will therefore get
/// a [Mapper].
class Encodable<T extends Encodable<T>> {
  final ConcreteType<T> _concreteType = new ConcreteType<T>();

  /// Encode an [Encodable] into default form.
  dynamic encode() => global.encode(this);

  /// Encode an [Encodable] as json.
  String encodeJson() => global.encodeJson(this);
}

/// An object which provides decoding to types already marked as [Encodable].
///
/// This will ensure that the [Mapper] can be created for an [Encodable] at
/// runtime.
class StaticMapper<T extends Encodable<T>> {
  final ConcreteType<T> _concreteType = new ConcreteType<T>();

  /// Decode an object from its default representation, which will usually be a
  /// [Map].
  T decode(dynamic value) => global.decode(value, _concreteType);

  /// Decode an object from its json representation.
  T decodeJson(String value) => global.decodeJson(value, _concreteType);

  /// Retrieve the [Mapper] containing the metadata of a type.
  Mapper<T, dynamic> get mapper => global.getMapper(_concreteType);
}
