library json_mapper.abstract_mapper_factory;

import 'dart:convert';

import 'package:json_mapper/metadata.dart';

/// A [FieldDecoder] is a function which can extract field values from an
/// encoded data.
typedef Object FieldDecoder(
    Object encodedData, String fieldName, Field fieldInfo, List metadata);

/// A [FieldEncoder] is a function which can add fields to an encoded data.
typedef void FieldEncoder(Map encodedData, String fieldName, Field fieldInfo,
    List metadata, Object value);

/// A function that uses `fieldDecoder` and `typeCodecs` to decode a field from
/// `data` and assign the value in `obj` to its value.
typedef void MapperDecoder<T, E>(
    T obj, E data, FieldDecoder fieldDecoder, Map<Type, Codec> typeCodecs,
    [Type type]);

/// A function that uses `fieldEncoder` and `typeCodecs` to encode a field value.
typedef E MapperEncoder<T, E>(
    T obj, FieldEncoder fieldEncoder, Map<Type, Codec> typeCodecs);

/// A getter function.
typedef E FieldGetter<T, E>(T obj);

/// A setter function.
typedef void FieldSetter<T, E>(T obj, E value);

/// A function that takes a set of positional arguments and a map of named
/// arguments and creates a specific object.
typedef T ModelFactory<T>(
    List posAarguments, Map<String, dynamic> namedArguments);

/// A [Mapper] is an [Codec]-like object that converts a specific type to and
/// from a jsonic form.
abstract class Mapper<T, E> {
  /// The const constructor for [Mapper].
  const Mapper();

  /// When overriden, create a new object of type [T] given the input values.
  T typeFactory(E data, FieldDecoder fieldDecoder, Map<Type, Codec> typeCodecs,
      [Type type]);

  /// When overriden, encode the object `obj` as a new [E] (usually a [Map].)
  E encoder(T obj, FieldEncoder fieldEncoder, Map<Type, Codec> typeCodecs);

  /// When overriden, decode the values in `data` and assign the appropriate,
  /// non-final fields in `obj` to the derrived values.
  void decoder(
      T obj, E data, FieldDecoder fieldDecoder, Map<Type, Codec> typeCodecs,
      [Type type]);
}

/// A more specific form of [Mapper] that also has awareness of its own
/// getters and setters.
abstract class FieldMapper<T> implements Mapper<T, Map<String, dynamic>> {
  /// Get a getter of a specific name.
  FieldGetter<T, dynamic> getGetter(String fieldName);

  /// Get a setter of a specific name.
  FieldSetter<T, dynamic> getSetter(String fieldName);
}
