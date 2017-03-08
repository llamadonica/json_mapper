library json_mapper.static_mapper_factory;

import 'dart:convert';
import 'package:json_mapper/src/abstract_mapper_factory.dart';
import 'package:json_mapper/json_mapper.dart';
import 'package:json_mapper/metadata.dart';
import 'package:json_mapper/src/builder_field_mapper.dart';

/// Get the raw value for a field
typedef E FieldGetter<T, E>(T obj);

/// Set the raw value for a field.
typedef void FieldSetter<T, E>(T obj, E value);

Mapper/*<S,E>*/ _createMapper/*<S, E>*/(Type type, dynamic typeSentry) {
  if (!_types.containsKey(type)) {
    throw new StateError(
        'Type $type was not found in the static mappers. To be decoded from a Map it must be annotated with a field, and if generic, some step must be taken to create its ConcreteType such as making it Encodable.');
  }
  return _types[type] as Mapper/*<S,E>*/;
}

/// A mixin for [Mapper] that uses the `_createMapper` found in this library.
abstract class StaticMapper<T, E> implements Mapper<T, E> {
  /// Create the static [Mapper] for a type that will be used within all
  /// static mappers.
  Mapper/*<S,E>*/ createMapper/*<S, E>*/(Type type, dynamic/*=S*/ typeSentry) =>
      _createMapper/*<S,E>*/(type, typeSentry);
}

/// A [BuilderFieldMapper] with [StaticMapper].
class StaticFieldMapper<T> extends BuilderFieldMapper<T>
    with StaticMapper<T, Map<String, dynamic>> {
  /// Created a new [StaticFieldMapper] object.
  StaticFieldMapper(
      {List<String> positionalArgs,
      List<String> namedArgs,
      Map<String, FieldGetter> getters,
      Map<String, FieldSetter> setters,
      Map<String, Type> types,
      Map<String, Type> constructorTypes,
      Map<String, Field> getterFields,
      Map<String, Field> setterFields,
      Map<String, Field> constructorFields,
      Map<String, List> getterMetadata,
      Map<String, List> setterMetadata,
      Map<String, List> constructorMetadata,
      ModelFactory<T> createModel})
      : super(
            positionalArgs,
            namedArgs,
            getters,
            setters,
            types,
            constructorTypes,
            getterFields,
            setterFields,
            constructorFields,
            getterMetadata,
            setterMetadata,
            constructorMetadata,
            createModel);
}

/// The [StaticMapper] used for [List] types.
class StaticListMapper<T> extends Mapper<List<T>, List<dynamic>>
    with StaticMapper<List<T>, List<dynamic>> {
  final Type _innerType = T;
  @override
  List encoder(
      List<T> obj, FieldEncoder fieldEncoder, Map<Type, Codec> typeCodecs) {
    return new List.from(obj.map((value) {
      final mapper = createMapper/*<T,dynamic>*/(value.runtimeType, value);
      return mapper.encoder(value, fieldEncoder, typeCodecs);
    }));
  }

  @override
  List<T> typeFactory(
          List data, FieldDecoder fieldDecoder, Map<Type, Codec> typeCodecs,
          [Type type]) =>
      <T>[];

  @override
  void decoder(List<T> obj, List data, FieldDecoder fieldDecoder,
      Map<Type, Codec> typeCodecs,
      [Type type]) {
    final mapper = createMapper/*<T,dynamic>*/(_innerType, null);
    obj.addAll(data.map((value) {
      final result =
          mapper.typeFactory(value, fieldDecoder, typeCodecs, _innerType);
      mapper.decoder(result, value, fieldDecoder, typeCodecs, _innerType);
      return result;
    }));
  }
}

/// The [StaticMapper] used for [Map] types.
class StaticMapMapper<V> extends Mapper<Map<String, V>, Map<String, dynamic>>
    with StaticMapper<Map<String, V>, Map<String, dynamic>> {
  final Type _innerType = V;

  @override
  Map<String, V> typeFactory(Map<String, dynamic> data,
      FieldDecoder fieldDecoder, Map<Type, Codec> typeCodecs,
      [Type type]) {
    return <String, V>{};
  }

  @override
  Map<String, dynamic> encoder(Map<String, V> obj, FieldEncoder fieldEncoder,
      Map<Type, Codec> typeCodecs) {
    final result = <String, dynamic>{};
    obj.forEach((key, value) {
      final mapper = createMapper/*<V,dynamic>*/(value.runtimeType, value);
      result[key] = mapper.encoder(value, fieldEncoder, typeCodecs);
    });
    return result;
  }

  @override
  void decoder(Map<String, V> obj, Object data, FieldDecoder fieldDecoder,
      Map<Type, Codec> typeCodecs,
      [Type type]) {
    final valueType = _innerType;
    final mapper = createMapper/*<V,dynamic>*/(valueType, null);
    (data as Map).forEach((key, value) {
      obj[key] = mapper.typeFactory(value, fieldDecoder, typeCodecs, valueType);
      mapper.decoder(obj[key], value, fieldDecoder, typeCodecs, valueType);
    });
  }
}

/// The [StaticMapper] used for types such as [int], [double], [String], etc.,
/// which have a representation in json.
class StaticNotEncodableMapper<T> extends Mapper<T, dynamic>
    with StaticMapper<T, dynamic> {
  final Type _thisType = T;
  @override
  void decoder(
      T obj, data, FieldDecoder fieldDecoder, Map<Type, Codec> typeCodecs,
      [Type type]) {}

  @override
  dynamic encoder(
          T obj, FieldEncoder fieldEncoder, Map<Type, Codec> typeCodecs) =>
      (typeCodecs[_thisType]?.encode ?? _id)(obj);

  @override
  T typeFactory(data, FieldDecoder fieldDecoder, Map<Type, Codec> typeCodecs,
          [Type type]) =>
      (typeCodecs[_thisType]?.decode ?? _id)(data);
  dynamic/*=F*/ _id/*<F>*/(dynamic/*=F*/ obj) => obj;
}

final Map<Type, StaticMapper<dynamic, dynamic>> _invariants = {
  String: new StaticNotEncodableMapper<String>(),
  int: new StaticNotEncodableMapper<int>(),
  double: new StaticNotEncodableMapper<double>(),
  num: new StaticNotEncodableMapper<num>(),
  bool: new StaticNotEncodableMapper<bool>(),
  Object: new StaticNotEncodableMapper<Object>(),
  Null: new StaticNotEncodableMapper<Null>(),
  DateTime: new StaticNotEncodableMapper<DateTime>()
};

Map<Type, StaticMapper> _types;

/// Bootstrap the static mapper function with eh list of static types that the
/// user will need.
void staticBootstrapMapper(Map<Type, StaticMapper> types) {
  _types = new Map<Type, StaticMapper>.from(types);
  _invariants.forEach((t, mapper) {
    if (!_types.containsKey(t)) {
      _types[t] = mapper;
    }
  });
  configure(_createMapper);
}
