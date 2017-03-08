// Copyright (c) 2017, astark. All rights reserved. Use of this source code
// is governed by a BSD-style license that can be found in the LICENSE file.

/// Support for doing something awesome.
///
/// More dartdocs go here.
library json_mapper;

import 'dart:convert';
import 'package:json_mapper/src/abstract_mapper_factory.dart';
import 'package:json_mapper/metadata.dart';

/// Set up json_mapper to use a specific [MapperFactory] as its top-level
/// `Mapper` getter.
void configure(MapperFactory mapperFactory) {
  _mapperFactory = mapperFactory;
}

/// A function that retrieves a [Mapper] associated with a given [type].
/// `objectMarker` can be [null], but if provided it is to disambiguate. This
/// is the type used to register the systems `_mapperFactory`
typedef Mapper MapperFactory(Type type, dynamic objectMarker);

/// Apply the current `_mapperFactory` to a [type], getting the [Mapper] for
/// that type. Even though this function was not provided in `redstone_mapper`,
/// I thought it might be useful.
Mapper/*<T,dynamic>*/ getMapper/*<T>*/(ConcreteType/*<T>*/ type,
        [dynamic/*=T*/ typeSentry]) =>
    _mapperFactory(type.type, typeSentry) as Mapper/*<T,dynamic>*/;

MapperFactory _mapperFactory = (Type type, dynamic typeSentry) =>
    throw new UnsupportedError(
        "redstone_mapper is not properly configured. Did you call bootstrapMapper()?");

/// Within the value encoder and decoder system, an ignored value, which
/// can be caused by a [Field] with [model] set to the empty [String], will
/// cause the result of [IgnoreValue], which will not be encoded in the result
class IgnoreValue {
  /// The [IgnoreValue] constructor.
  const IgnoreValue();
}

/// A codec that can convert between objects of any type and the json or other
/// format.
class GenericTypeCodec {
  final _TypeDecoderMixin _decoder;
  final _TypeEncoderMixin _encoder;

  /// Construct a new [GenericTypeCodec] object.
  GenericTypeCodec(
      {FieldDecoder fieldDecoder,
      FieldEncoder fieldEncoder,
      Map<Type, Codec> typeCodecs: const {}})
      : _decoder = fieldDecoder != null
            ? new _TypeDecoder(fieldDecoder, typeCodecs: typeCodecs)
            : new _DefaultTypeDecoder(typeCodecs: typeCodecs),
        _encoder = fieldEncoder != null
            ? new _TypeEncoder(fieldEncoder, typeCodecs: typeCodecs)
            : new _DefaultTypeEncoder(typeCodecs: typeCodecs);

  /// A form of the above constructor that can be formed from `const` arguments.
  const GenericTypeCodec.constable(this._encoder, this._decoder,
      {Map<Type, Codec> typeCodecs: const {}});

  /// Encode an object `input` as json. If [type] is not specified, then the
  /// object's [runtimeType] will be used.
  dynamic encode(dynamic input, [ConcreteType type]) {
    return _encoder.convert(input, type);
  }

  /// Decode an object into the given [type].
  dynamic decode(dynamic data, ConcreteType type) {
    return _decoder.convert(data, type);
  }
}

final _defaultCodecs = <Type, Codec>{
  DateTime: const Iso8601Codec(),
  OpaqueMap: const OpaqueMapCodec(),
  OpaqueList: const OpaqueListCodec()
};

/// A JSON codec.
///
/// This codec can be used to transfer objects between client and
/// server. It recursively encode objects to Maps and Lists, which
/// can be easily converted to json.
final GenericTypeCodec jsonCodec = new GenericTypeCodec.constable(
    new _DefaultTypeEncoder(typeCodecs: _defaultCodecs),
    new _DefaultTypeDecoder(typeCodecs: _defaultCodecs),
    typeCodecs: _defaultCodecs);

/// A codec to convert between [DateTime] objects and [String]s.
class Iso8601Codec extends Codec<DateTime, String> {
  /// Create a new [Iso8601Codec] object.
  const Iso8601Codec();

  @override
  final Converter<String, DateTime> decoder = const Iso8601Decoder();

  @override
  final Converter<DateTime, String> encoder = const Iso8601Encoder();
}

/// The encoder associated with [Iso8601Codec].
class Iso8601Encoder extends Converter<DateTime, String> {
  /// Create a new [Iso8601Encoder] object.
  const Iso8601Encoder();
  @override
  String convert(DateTime input) => input.toIso8601String();
}

/// The decoder associated with [Iso8601Decoder].
class Iso8601Decoder extends Converter<String, DateTime> {
  /// Create a new [Iso8601Decoder] object.
  const Iso8601Decoder();
  @override
  DateTime convert(String input) => DateTime.parse(input);
}

/// The `encoder` for [OpaqueDelegateCodec]
class OpaqueDelegateEncoder<T extends OpaqueDelegate<T, D>, D>
    extends Converter<T, D> {
  /// Construct a new [OpaqueDelegateEncoder].
  const OpaqueDelegateEncoder();

  @override
  D convert(T input) => input.delegate;
}

/// A [Codec] that converts [OpaqueMap] to and from the regular underlying [Map]
class OpaqueMapCodec extends Codec<OpaqueMap, Map<String, dynamic>> {
  /// Construct a new [OpaqueMapCodec].
  const OpaqueMapCodec();

  @override
  final Converter<Map<String, dynamic>, OpaqueMap> decoder =
      const OpaqueMapDecoder();
  @override
  final Converter<OpaqueMap, Map<String, dynamic>> encoder =
      const OpaqueDelegateEncoder<OpaqueMap, Map<String, dynamic>>();
}

/// The `decoder` for [OpaqueMapCodec].
class OpaqueMapDecoder extends Converter<Map<String, dynamic>, OpaqueMap> {
  /// Construct a new [OpaqueMapDecoder].
  const OpaqueMapDecoder();

  @override
  OpaqueMap convert(Map<String, dynamic> input) => new OpaqueMap(input);
}

/// A [Codec] that converts [OpaqueList] to and from the regular underlying [List]
class OpaqueListCodec extends Codec<OpaqueList, List<dynamic>> {
  /// Construct a new [OpaqueListCodec] object.
  const OpaqueListCodec();

  @override
  final Converter<List<dynamic>, OpaqueList> decoder =
      const OpaqueListDecoder();
  @override
  final Converter<OpaqueList, List<dynamic>> encoder =
      const OpaqueDelegateEncoder<OpaqueList, List<dynamic>>();
}

/// The `decoder` for [OpaqueListCodec].
class OpaqueListDecoder extends Converter<List<dynamic>, OpaqueList> {
  /// Construct a new [OpaqueListDecoder].
  const OpaqueListDecoder();

  @override
  OpaqueList convert(List<dynamic> input) => new OpaqueList(input);
}

class _DefaultTypeDecoder implements _TypeDecoderMixin {
  @override
  final Map<Type, Codec> typeCodecs;

  const _DefaultTypeDecoder({this.typeCodecs: const {}});

  @override
  ConcreteType get type => null;

  @override
  Object fieldDecoder(
      Object encodedData, String fieldName, Field fieldInfo, List metadata) {
    String name = fieldName;

    if (fieldInfo.model is String) {
      if (fieldInfo.model.isEmpty) {
        return const IgnoreValue();
      }

      name = fieldInfo.model;
    }

    return (encodedData as Map)[name];
  }

  @override
  dynamic convert(input, [ConcreteType type]) {
    type ??= this.type;

    final Mapper mapper = _mapperFactory(type.type, input);
    final result =
        mapper.typeFactory(input, fieldDecoder, typeCodecs, type.type);
    mapper.decoder(result, input, fieldDecoder, typeCodecs, type.type);
    return result;
  }
}

class _DefaultTypeEncoder implements _TypeEncoderMixin {
  @override
  final Map<Type, Codec> typeCodecs;

  const _DefaultTypeEncoder({this.typeCodecs: const {}});

  @override
  Type get type => null;

  @override
  void fieldEncoder(final Map encodedData, final String fieldName,
      final Field fieldInfo, final List metadata, final Object value) {
    if (value == null) {
      return;
    }

    String name = fieldName;

    if (fieldInfo.model is String) {
      if (fieldInfo.model.isEmpty) {
        return;
      }

      name = fieldInfo.model;
    }

    encodedData[name] = value;
  }

  @override
  dynamic convert(dynamic input, [ConcreteType type]) {
    if (input is List) {
      return input.map((data) => _encode(data, null)).toList();
    } else if (input is Map) {
      final encodedMap = {};
      input.forEach((key, value) {
        encodedMap[key] = _encode(value, type?.type);
      });
      return encodedMap;
    } else {
      return _encode(input, type?.type);
    }
  }

  @override
  dynamic _encode(input, Type type) {
    type = type ?? this.type ?? input.runtimeType;
    // If it's a list, we have to use the generic List type here. There
    // are a bunch of incoherent subtypes of list.
    final Mapper mapper = input is List
        ? _mapperFactory(List, input)
        : (input is Map
            ? _mapperFactory(Map, input)
            : _mapperFactory(type, input));
    return mapper.encoder(input, fieldEncoder, typeCodecs);
  }
}

abstract class _TypeDecoderMixin {
  ConcreteType get type;
  Object fieldDecoder(
      Object encodedData, String fieldName, Field fieldInfo, List metadata);
  Map<Type, Codec> get typeCodecs;

  dynamic convert(input, [ConcreteType type]) {
    type ??= this.type;

    final Mapper mapper = _mapperFactory(type?.type, null);
    final result =
        mapper.typeFactory(input, fieldDecoder, typeCodecs, type?.type);
    mapper.decoder(result, input, fieldDecoder, typeCodecs, type?.type);
    return result;
  }
}

class _TypeDecoder extends Converter with _TypeDecoderMixin {
  @override
  final ConcreteType type;
  final FieldDecoder _fieldDecoder;
  @override
  final Map<Type, Codec> typeCodecs;

  _TypeDecoder(this._fieldDecoder, {this.type, this.typeCodecs: const {}});

  @override
  Object fieldDecoder(Object encodedData, String fieldName, Field fieldInfo,
          List metadata) =>
      _fieldDecoder(encodedData, fieldName, fieldInfo, metadata);
}

abstract class _TypeEncoderMixin {
  Type get type;
  void fieldEncoder(Map encodedData, String fieldName, Field fieldInfo,
      List metadata, Object value);
  Map<Type, Codec> get typeCodecs;

  dynamic convert(dynamic input, [ConcreteType type]) {
    if (input is List) {
      return input.map((data) => _encode(data, type.type)).toList();
    } else if (input is Map) {
      final encodedMap = {};
      input.forEach((key, value) {
        encodedMap[key] = _encode(value, type.type);
      });
      return encodedMap;
    } else {
      return _encode(input, type.type);
    }
  }

  dynamic _encode(input, Type type) {
    type = type ?? this.type ?? input.runtimeType;
    final Mapper mapper = input is List
        ? _mapperFactory(List, input)
        : _mapperFactory(type, input);
    return mapper.encoder(input, fieldEncoder, typeCodecs);
  }
}

class _TypeEncoder extends Converter with _TypeEncoderMixin {
  @override
  final Type type;
  final FieldEncoder _fieldEncoder;
  @override
  final Map<Type, Codec> typeCodecs;

  _TypeEncoder(this._fieldEncoder, {this.type, this.typeCodecs: const {}});

  @override
  void fieldEncoder(Map encodedData, String fieldName, Field fieldInfo,
          List metadata, Object value) =>
      _fieldEncoder(encodedData, fieldName, fieldInfo, metadata, value);
}

/// An exception produced from json_mapper.
///
/// One difference between json_mapper and redstone_mapper is that we make less
/// effort to rethrow Exceptions as [MapperException]s.
class MapperException extends Error {
  /// The message associated with the [MapperException[
  final String message;

  /// Create a new [MapperException] object.
  MapperException(this.message);
}

/// The default codec which is a [Codec] type that can convert any [Object]
/// to its encoded form.
GenericTypeCodec get defaultCodec => jsonCodec;

/// Decode [data] to one or more objects of type [type],
/// using [defaultCodec].
///
/// [data] is expected to be a Map or
/// a List, and [type] a class which contains members
/// annotated with the [Field] annotation.
///
/// For more information on how serialization
/// and deserialization of objects works, see [Field].
dynamic/*=T*/ decode/*<T>*/(dynamic data, ConcreteType/*<T>*/ type) {
  return defaultCodec.decode(data, type) as dynamic/*=T*/;
}

/// Encode [input] using [defaultCodec].
///
/// [input] can be an object or a List of objects.
/// If it's an object, then this function will return
/// a Map, otherwise a List<Map> will be returned.
///
/// For more information on how serialization
/// and deserialization of objects works, see [Field].
dynamic encode/*<T>*/(dynamic/*=T*/ input) {
  return defaultCodec.encode(input);
}

/// Decode [json] to one or more objects of type [type].
///
/// [json] is expected to be a JSON object, or a list of
/// JSON objects, and [type] a class which contains members
/// annotated with the [Field] annotation.
///
/// If [json] is a JSON object, then this function will return
/// an object of [type]. Otherwise, if [json] is a list, then a
/// List<[type]> will be returned.
///
/// For more information on how serialization
/// and deserialization of objects works, see [Field].
dynamic/*=T*/ decodeJson/*<T>*/(String json, ConcreteType/*<T>*/ type) {
  return jsonCodec.decode(JSON.decode(json), type);
}

/// Encode [input] to JSON.
///
/// [input] can be an object or a List of objects.
/// If it's an object, then this function will return
/// a JSON object, otherwise a list of JSON objects
/// will be returned.
///
/// For more information on how serialization
/// and deserialization of objects works, see [Field].
String encodeJson/*<T>*/(dynamic/*=T*/ input) {
  return JSON.encode(jsonCodec.encode(input));
}
