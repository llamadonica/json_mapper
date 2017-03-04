// Copyright (c) 2017, astark. All rights reserved. Use of this source code
// is governed by a BSD-style license that can be found in the LICENSE file.

/// Support for doing something awesome.
///
/// More dartdocs go here.
library json_mapper;

import 'dart:convert';
import 'package:json_mapper/src/abstract_mapper_factory.dart';
import 'package:json_mapper/metadata.dart';

void configure(MapperFactory mapperFactory) {
  _mapperFactory = mapperFactory;
}

typedef Mapper MapperFactory(Type type, dynamic objectMarker);

Mapper/*<T,dynamic>*/ getMapper/*<T>*/(ConcreteType/*<T>*/ type, [dynamic/*=T*/ typeSentry]) =>
    _mapperFactory(type.type, typeSentry) as Mapper/*<T,dynamic>*/;

MapperFactory _mapperFactory = (Type type, dynamic typeSentry) =>
    throw new UnsupportedError(
        "redstone_mapper is not properly configured. Did you call bootstrapMapper()?");

class IgnoreValue {
  const IgnoreValue();
}

const ignoreValue = const IgnoreValue();

///A codec that can convert objects of any type.
class GenericTypeCodec {
  final _TypeDecoderMixin _decoder;
  final _TypeEncoderMixin _encoder;

  const GenericTypeCodec.constable(this._encoder, this._decoder,
      {Map<Type, Codec> typeCodecs: const {}});

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

  dynamic encode(dynamic input, [ConcreteType type]) {
    return _encoder.convert(input, type);
  }

  dynamic decode(dynamic data, ConcreteType type) {
    return _decoder.convert(data, type);
  }
}

/**
 * A JSON codec.
 *
 * This codec can be used to transfer objects between client and
 * server. It recursively encode objects to Maps and Lists, which
 * can be easily converted to json.
 *
 * When using on the client side, be sure to set the redstone_mapper's
 * transformer in your pubspec.yaml.
 */
final _defaultCodecs = <Type, Codec>{
  DateTime: const Iso8601Codec(),
  OpaqueMap: const OpaqueMapCodec(),
  OpaqueList: const OpaqueListCodec()
};

final GenericTypeCodec jsonCodec = new GenericTypeCodec.constable(
    new _DefaultTypeEncoder(typeCodecs: _defaultCodecs),
    new _DefaultTypeDecoder(typeCodecs: _defaultCodecs),
    typeCodecs: _defaultCodecs);

///A codec to convert between DateTime objects and strings.
class Iso8601Codec extends Codec<DateTime, String> {
  const Iso8601Codec();

  @override
  final Converter<String, DateTime> decoder = const Iso8601Decoder();

  @override
  final Converter<DateTime, String> encoder = const Iso8601Encoder();
}

class Iso8601Encoder extends Converter<DateTime, String> {
  const Iso8601Encoder();
  @override
  String convert(DateTime input) => input.toIso8601String();
}

class Iso8601Decoder extends Converter<String, DateTime> {
  const Iso8601Decoder();
  @override
  DateTime convert(String input) => DateTime.parse(input);
}

class OpaqueMapCodec extends Codec<OpaqueMap, Map<String, dynamic>> {
  const OpaqueMapCodec();

  @override
  final Converter<Map<String, dynamic>, OpaqueMap> decoder =
      const OpaqueMapDecoder();

  @override
  final Converter<OpaqueMap, Map<String, dynamic>> encoder =
      const OpaqueMapEncoder();
}

class OpaqueMapEncoder extends Converter<OpaqueMap, Map<String, dynamic>> {
  const OpaqueMapEncoder();

  @override
  Map<String, dynamic> convert(OpaqueMap input) => input.delegate;
}

class OpaqueMapDecoder extends Converter<Map<String, dynamic>, OpaqueMap> {
  const OpaqueMapDecoder();

  @override
  OpaqueMap convert(Map<String, dynamic> input) => new OpaqueMap(input);
}

class OpaqueListCodec extends Codec<OpaqueList, List<dynamic>> {
  const OpaqueListCodec();

  @override
  final Converter<List<dynamic>, OpaqueList> decoder =
      const OpaqueListDecoder();

  @override
  final Converter<OpaqueList, List<dynamic>> encoder =
      const OpaqueListEncoder();
}

class OpaqueListEncoder extends Converter<OpaqueList, List<dynamic>> {
  const OpaqueListEncoder();

  @override
  List<dynamic> convert(OpaqueList input) => input.delegate;
}

class OpaqueListDecoder extends Converter<List<dynamic>, OpaqueList> {
  const OpaqueListDecoder();

  @override
  OpaqueList convert(List<dynamic> input) => new OpaqueList(input);
}

class _DefaultTypeDecoder implements _TypeDecoderMixin {
  ConcreteType get type => null;
  final Map<Type, Codec> typeCodecs;

  const _DefaultTypeDecoder({this.typeCodecs: const {}});

  Object fieldDecoder(
      Object encodedData, String fieldName, Field fieldInfo, List metadata) {
    String name = fieldName;

    if (fieldInfo.model is String) {
      if (fieldInfo.model.isEmpty) {
        return ignoreValue;
      }

      name = fieldInfo.model;
    }

    return (encodedData as Map)[name];
  }

  @override
  dynamic convert(input, [ConcreteType type]) {
    type ??= this.type;

    Mapper mapper = _mapperFactory(type.type, input);
    final result =
        mapper.typeFactory(input, fieldDecoder, typeCodecs, type.type);
    mapper.decoder(result, input, fieldDecoder, typeCodecs, type.type);
    return result;
  }
}

class _DefaultTypeEncoder implements _TypeEncoderMixin {
  Type get type => null;
  final Map<Type, Codec> typeCodecs;

  const _DefaultTypeEncoder({this.typeCodecs: const {}});

  fieldEncoder(final Map encodedData, final String fieldName,
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

  dynamic _encode(input, Type type) {
    type = type ?? this.type ?? input.runtimeType;
    // If it's a list, we have to use the generic List type here. There
    // are a bunch of incoherent subtypes of list.
    Mapper mapper = input is List
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

    Mapper mapper = _mapperFactory(type?.type, null);
    final result =
        mapper.typeFactory(input, fieldDecoder, typeCodecs, type?.type);
    mapper.decoder(result, input, fieldDecoder, typeCodecs, type?.type);
    return result;
  }
}

class _TypeDecoder extends Converter with _TypeDecoderMixin {
  final ConcreteType type;
  final FieldDecoder _fieldDecoder;
  final Map<Type, Codec> typeCodecs;

  _TypeDecoder(this._fieldDecoder, {this.type, this.typeCodecs: const {}});

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
    Mapper mapper = input is List
        ? _mapperFactory(List, input)
        : _mapperFactory(type, input);
    return mapper.encoder(input, fieldEncoder, typeCodecs);
  }
}

class _TypeEncoder extends Converter with _TypeEncoderMixin {
  final Type type;
  final FieldEncoder _fieldEncoder;

  final Map<Type, Codec> typeCodecs;

  _TypeEncoder(this._fieldEncoder, {this.type, this.typeCodecs: const {}});
  @override
  fieldEncoder(Map encodedData, String fieldName, Field fieldInfo,
          List metadata, Object value) =>
      _fieldEncoder(encodedData, fieldName, fieldInfo, metadata, value);
}

class MapperException {
  final String message;
  MapperException(this.message);
}

GenericTypeCodec get defaultCodec => jsonCodec;

/**
 * Decode [data] to one or more objects of type [type],
 * using [defaultCodec].
 *
 * [data] is expected to be a Map or
 * a List, and [type] a class which contains members
 * annotated with the [Field] annotation.
 *
 * If [data] is a Map, then this function will return
 * an object of [type]. Otherwise, if [data] is a List, then a
 * List<[type]> will be returned.
 *
 * For more information on how serialization
 * and deserialization of objects works, see [Field].
 *
 * When using on the client side, be sure to set the redstone_mapper's
 * transformer in your pubspec.yaml.
 */
dynamic/*=T*/ decode/*<T>*/(dynamic data, ConcreteType/*<T>*/ type) {
  return defaultCodec.decode(data, type) as dynamic/*=T*/;
}

/**
 * Encode [input] using [defaultCodec].
 *
 * [input] can be an object or a List of objects.
 * If it's an object, then this function will return
 * a Map, otherwise a List<Map> will be returned.
 *
 * For more information on how serialization
 * and deserialization of objects works, see [Field].
 *
 * When using on the client side, be sure to set the redstone_mapper's
 * transformer in your pubspec.yaml.
 */
dynamic encode/*<T>*/(dynamic/*=T*/ input) {
  return defaultCodec.encode(input);
}

/**
 * Decode [json] to one or more objects of type [type].
 *
 * [json] is expected to be a JSON object, or a list of
 * JSON objects, and [type] a class which contains members
 * annotated with the [Field] annotation.
 *
 * If [json] is a JSON object, then this function will return
 * an object of [type]. Otherwise, if [json] is a list, then a
 * List<[type]> will be returned.
 *
 * For more information on how serialization
 * and deserialization of objects works, see [Field].
 *
 * When using on the client side, be sure to set the redstone_mapper's
 * transformer in your pubspec.yaml.
 */
dynamic/*=T*/ decodeJson/*<T>*/(String json, ConcreteType/*<T>*/ type) {
  return jsonCodec.decode(JSON.decode(json), type);
}

/**
 * Encode [input] to JSON.
 *
 * [input] can be an object or a List of objects.
 * If it's an object, then this function will return
 * a JSON object, otherwise a list of JSON objects
 * will be returned.
 *
 * For more information on how serialization
 * and deserialization of objects works, see [Field].
 *
 * When using on the client side, be sure to set the redstone_mapper's
 * transformer in your pubspec.yaml.
 */
String encodeJson/*<T>*/(dynamic/*=T*/ input) {
  return JSON.encode(jsonCodec.encode(input));
}
