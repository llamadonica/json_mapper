library json_mapper.builder_field_mapper;

import 'dart:convert';
import 'package:json_mapper/src/abstract_mapper_factory.dart';
import 'package:json_mapper/json_mapper.dart';
import 'package:json_mapper/metadata.dart';

typedef void _ChainDecoder<T, E>(
    T value, E data, FieldDecoder fieldDecoder, Map<Type, Codec> typeCodecs);
typedef void _ChainEncoder<T, E>(
    T value, E data, FieldEncoder fieldEncoder, Map<Type, Codec> typeCodecs);
typedef F _ChainFactory<E, F>(
    E data, FieldDecoder fieldDecoder, Map<Type, Codec> typeCodecs);

/// A [FieldMapper] subtype that creates, and has getters and setters for a
/// specific type, which will be marked up with field, based on an extensive
/// collection of information, and one method which must be overriden.
abstract class BuilderFieldMapper<T> implements FieldMapper<T> {
  final List<String> _positionalArgs;
  final List<String> _namedArgs;
  final Map<String, FieldGetter<T, dynamic>> _getters;
  final Map<String, FieldSetter<T, dynamic>> _setters;
  final Map<String, Type> _types;
  final Map<String, Type> _constructorTypes;
  final Map<String, Field> _getterFields;
  final Map<String, Field> _setterFields;
  final Map<String, Field> _constructorFields;
  final Map<String, List> _getterMetadata;
  final Map<String, List> _setterMetadata;
  final Map<String, List> _constructorMetadata;
  final ModelFactory<T> _createModel;
  /// The metadata associated with the class itself.
  final List metadata;

  /// Create a new object of type [BuilderFieldMapper] when called from a
  /// subtype.
  BuilderFieldMapper(
      this._positionalArgs,
      this._namedArgs,
      this._getters,
      this._setters,
      this._types,
      this._constructorTypes,
      this._getterFields,
      this._setterFields,
      this._constructorFields,
      this._getterMetadata,
      this._setterMetadata,
      this._constructorMetadata,
      this._createModel,
      this.metadata);

  Iterable<_ChainFactory<Map<String, dynamic>, dynamic>>
      get _factoryPositionalArgs sync* {
    for (var fieldName in _positionalArgs) {
      yield (Map<String, dynamic> data, FieldDecoder fieldDecoder,
          Map<Type, Codec> typeCodecs) {
        return _decodeField(
            fieldName,
            _constructorFields[fieldName],
            data,
            _constructorMetadata[fieldName],
            typeCodecs,
            fieldDecoder,
            _constructorTypes[fieldName]);
      };
    }
  }

  Map<String, _ChainFactory<Map<String, dynamic>, dynamic>>
      get _factoryNamedArgs => new Map.fromIterable(_namedArgs,
          value: (fieldName) => (Map<String, dynamic> data,
                  FieldDecoder fieldDecoder, Map<Type, Codec> typeCodecs) {
                return _decodeField(
                    fieldName,
                    _constructorFields[fieldName],
                    data,
                    _constructorMetadata[fieldName],
                    typeCodecs,
                    fieldDecoder,
                    _constructorTypes[fieldName]);
              });

  Iterable<_ChainDecoder<T, Map<String, dynamic>>> get _decodeChain sync* {
    for (var fieldName in _setters.keys) {
      yield (T container, Map<String, dynamic> data, FieldDecoder fieldDecoder,
          Map<Type, Codec> typeCodecs) {
        final value = _decodeField(
            fieldName,
            _setterFields[fieldName],
            data,
            _setterMetadata[fieldName],
            typeCodecs,
            fieldDecoder,
            _types[fieldName]);
        _setters[fieldName](container, value);
      };
    }
  }

  Iterable<_ChainEncoder<T, Map<String, dynamic>>> get _encodeChain sync* {
    for (var fieldName in _getters.keys) {
      yield (T container, Map<String, dynamic> data, FieldEncoder fieldEncoder,
          Map<Type, Codec> typeCodecs) {
        final value = _getters[fieldName](container);
        _encodeField(
            value,
            fieldName,
            _getterFields[fieldName],
            data,
            _getterMetadata[fieldName],
            typeCodecs,
            fieldEncoder,
            _types[fieldName]);
      };
    }
  }

  @override
  void decoder(T obj, Map<String, dynamic> data, FieldDecoder fieldDecoder,
      Map<Type, Codec> typeCodecs,
      [Type type]) {
    if (data == null) {
      return;
    }
    _decodeChain.forEach((f) => f(obj, data, fieldDecoder, typeCodecs));
    return;
  }

  @override
  Map<String, dynamic> encoder(
      T obj, FieldEncoder fieldEncoder, Map<Type, Codec> typeCodecs) {
    if (obj == null) {
      return null;
    }
    final data = <String, dynamic>{};
    _encodeChain.forEach((f) => f(obj, data, fieldEncoder, typeCodecs));

    return data;
  }

  @override
  FieldGetter<T, dynamic> getGetter(String fieldName) {
    return _getters[fieldName];
  }

  @override
  FieldSetter<T, dynamic> getSetter(String fieldName) {
    return _setters[fieldName];
  }

  @override
  T typeFactory(Map<String, dynamic> data, FieldDecoder fieldDecoder,
      Map<Type, Codec> typeCodecs,
      [Type type]) {
    if (data == null) {
      return null;
    }
    final listArgs = _factoryPositionalArgs
        .map((f) => f(data, fieldDecoder, typeCodecs))
        .toList(growable: false);
    final namedArgs = <String, dynamic>{};
    _factoryNamedArgs.forEach(
        (name, f) => namedArgs[name] = f(data, fieldDecoder, typeCodecs));
    return _createModel(listArgs, namedArgs);
  }

  dynamic _decodeField(
      String fieldName,
      Field fieldInfo,
      Map<String, dynamic> data,
      List<dynamic> metadata,
      Map<Type, Codec> typeCodecs,
      FieldDecoder fieldDecoder,
      Type type) {
    final value = fieldDecoder(data, fieldName, fieldInfo, metadata);
    if (value != null && value is! IgnoreValue) {
      final Mapper mapper = createMapper(type, null);
      final typeCodec = typeCodecs[type];
      final decodedValue = typeCodec == null ? value : typeCodec.decode(value);
      final resultValue =
          mapper.typeFactory(decodedValue, fieldDecoder, typeCodecs, type);
      mapper.decoder(resultValue, decodedValue, fieldDecoder, typeCodecs, type);
      return resultValue;
    }
    return null;
  }

  void _encodeField(
      dynamic value,
      String fieldName,
      Field fieldInfo,
      Map<String, dynamic> data,
      List<dynamic> metadata,
      Map<Type, Codec> typeCodecs,
      FieldEncoder fieldEncoder,
      Type type,
      [bool encodeNulls = false]) {
    if ((value != null || encodeNulls) && value is! IgnoreValue) {
      if (value != null) {
        if (type == dynamic) type = value.runtimeType;
        final mapper = createMapper(type, value);
        final encodedValues = mapper.encoder(value, fieldEncoder, typeCodecs);

        final typeCodec = typeCodecs[type];
        try {
          value = typeCodec != null
              ? typeCodec.encode(encodedValues)
              : encodedValues;
        } catch (ex) {
          rethrow;
        }
      }

      fieldEncoder(data, fieldName, fieldInfo, metadata, value);
    }
  }

  /// When overriden, create the [Mapper] used by my subtypes.
  Mapper/*<S,E>*/ createMapper/*<S,E>*/(Type type, dynamic/*=S*/ typeSentry);
}
