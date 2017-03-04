library json_mapper.abstract_mapper_factory;

import 'dart:convert';

import 'package:json_mapper/metadata.dart';

/// A [MapperTypeFactory] creates a new object from encoded data.
typedef T MapperTypeFactory<T, E>(
    E data, FieldDecoder fieldDecoder, Map<Type, Codec> typeCodecs,
    [Type type]);

/// A [FieldDecoder] is a function which can extract field values from an
/// encoded data.
typedef Object FieldDecoder(
    Object encodedData, String fieldName, Field fieldInfo, List metadata);

/// A [FieldEncoder] is a function which can add fields to an encoded data.
typedef void FieldEncoder(Map encodedData, String fieldName, Field fieldInfo,
    List metadata, Object value);

///decode [data] to one or more objects of type [type], using [fieldDecoder]
///and [typeCodecs] to extract field values.
typedef void MapperDecoder<T, E>(
    T obj, E data, FieldDecoder fieldDecoder, Map<Type, Codec> typeCodecs,
    [Type type]);

///encode [obj] using [fieldEncoder] and [typeCodecs] to encode field values.
typedef E MapperEncoder<T, E>(
    T obj, FieldEncoder fieldEncoder, Map<Type, Codec> typeCodecs);
///get the raw value for a field
typedef E FieldGetter<T, E>(T obj);
///set the raw value for a field.
typedef void FieldSetter<T, E>(T obj, E value);
///create a new object with a specific set of parameters.
typedef T ModelFactory<T>(List posAarguments, Map<String, dynamic> namedArguments);


abstract class Mapper<T, E>  {
  T typeFactory(E data, FieldDecoder fieldDecoder, Map<Type, Codec> typeCodecs,
      [Type type]);
  E encoder(T obj, FieldEncoder fieldEncoder, Map<Type, Codec> typeCodecs);
  void decoder(
      T obj, E data, FieldDecoder fieldDecoder, Map<Type, Codec> typeCodecs,
      [Type type]);
}

abstract class FieldMapper<T> implements Mapper<T, Map<String, dynamic>> {
  FieldGetter<T, dynamic> getGetter(String fieldName);
  FieldSetter<T, dynamic> getSetter(String fieldName);
}
