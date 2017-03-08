part of json_mapper.dynamic_mapper_factory;

class _FieldData {
  final Symbol symbol;
  final List metadata;

  _FieldData(this.symbol, this.metadata);
}

class _MapDynamicMapper<K, V> implements Mapper<Map<K, V>, Map<K, dynamic>> {
  const _MapDynamicMapper();

  @override
  Map<K, V> typeFactory(Map<K, dynamic> data, FieldDecoder fieldDecoder,
      Map<Type, Codec> typeCodecs,
      [Type type]) {
    final TypeMirror clazz = reflectType(type);
    if (clazz.isOriginalDeclaration) {
      return data as Map<K, V>;
    }
    return <K, V>{};
  }

  @override
  Map<K, dynamic> encoder(
      Map<K, V> obj, FieldEncoder fieldEncoder, Map<Type, Codec> typeCodecs) {
    // This gives the wrong results on javascript, where maps always result in
    // being their own original declaration.
    // TypeMirror clazz = reflectType(obj.runtimeType);
    // if (clazz.isOriginalDeclaration) {
    //  throw new Exception('Expected a real type');
    //  return obj;
    //}
    final result = <K, dynamic>{};
    obj.forEach((key, value) {
      final mapper = _dynamicMapper(value.runtimeType, value);
      result[key] = mapper.encoder(value, fieldEncoder, typeCodecs);
    });
    return result;
  }

  @override
  void decoder(Map<K, V> obj, Object data, FieldDecoder fieldDecoder,
      Map<Type, Codec> typeCodecs,
      [Type type]) {
    final TypeMirror clazz = reflectType(type);
    if (clazz.isOriginalDeclaration) {
      return;
    }
    final valueType = clazz.typeArguments[1].reflectedType;
    final mapper = _dynamicMapper(valueType, null);
    (data as Map).forEach((key, value) {
      obj[key] = mapper.typeFactory(value, fieldDecoder, typeCodecs, valueType);
      mapper.decoder(obj[key], value, fieldDecoder, typeCodecs, valueType);
    });
  }
}

class _NotEncodableMapper<T> implements Mapper<T, dynamic> {
  const _NotEncodableMapper();

  @override
  void decoder(T obj, dynamic data, FieldDecoder fieldDecoder,
          Map<Type, Codec> typeCodecs,
          [Type type]) =>
      _defaultDecoder/*<T>*/(obj, data, fieldDecoder, typeCodecs, type);

  @override
  T encoder(T obj, FieldEncoder fieldEncoder, Map<Type, Codec> typeCodecs) =>
      typeCodecs[obj.runtimeType] == null
          ? obj
          : typeCodecs[obj.runtimeType].encode(obj);
  @override
  T typeFactory(
          dynamic data, FieldDecoder fieldDecoder, Map<Type, Codec> typeCodecs,
          [Type type]) =>
      _defaultGenerator(data, fieldDecoder, typeCodecs, type);
}

void _defaultDecoder/*<T>*/(dynamic/*=T*/ obj, dynamic data,
    FieldDecoder fieldDecoder, Map<Type, Codec> typeCodecs,
    [Type type]) {}

dynamic/*=T*/ _defaultGenerator/*<T>*/(
        dynamic data, FieldDecoder fieldDecoder, Map<Type, Codec> typeCodecs,
        [Type type]) =>
    typeCodecs[type] == null ? data : typeCodecs[type].decode(data);

final Map<Type, Mapper> _cache = {
  String: new _NotEncodableMapper(),
  int: new _NotEncodableMapper(),
  double: new _NotEncodableMapper(),
  num: new _NotEncodableMapper(),
  bool: new _NotEncodableMapper(),
  Object: new _NotEncodableMapper(),
  Null: new _NotEncodableMapper()
};

class _ListDynamicMapper<T> implements Mapper<List<T>, List<dynamic>> {
  const _ListDynamicMapper();

  @override
  List encoder(
      List<T> obj, FieldEncoder fieldEncoder, Map<Type, Codec> typeCodecs) {
    return new List.from(obj.map((value) {
      final mapper = _dynamicMapper/*<T,dynamic>*/(value.runtimeType, value);
      return mapper.encoder(value, fieldEncoder, typeCodecs);
    }));
  }

  @override
  List<T> typeFactory(
      List data, FieldDecoder fieldDecoder, Map<Type, Codec> typeCodecs,
      [Type type]) {
    final TypeMirror clazz = reflectType(type);

    if (clazz.isOriginalDeclaration) {
      return _defaultGenerator/*<List<T>>*/(
          data as List/*<T>*/, fieldDecoder, typeCodecs);
    }
    return <T>[];
  }

  @override
  void decoder(List<T> obj, List data, FieldDecoder fieldDecoder,
      Map<Type, Codec> typeCodecs,
      [Type type]) {
    final TypeMirror clazz = reflectType(type);
    Type valueType;
    if (!clazz.isOriginalDeclaration) {
      valueType = clazz.typeArguments[0].reflectedType;
    } else if (clazz.isSubtypeOf(_listMirror)) {
      _defaultDecoder/*<List<T>>*/(obj, data, fieldDecoder, typeCodecs);
      return;
    } else {
      valueType = type;
    }

    final mapper = _dynamicMapper/*<T,dynamic>*/(valueType, null);
    obj.addAll(data.map((value) {
      final result =
          mapper.typeFactory(value, fieldDecoder, typeCodecs, valueType);
      mapper.decoder(result, value, fieldDecoder, typeCodecs, valueType);
      return result;
    }));
  }
}

final _mapMirror = reflectClass(Map);
final _listMirror = reflectClass(List);

class _DynamicFieldMapper<T> extends BuilderFieldMapper<T> {
  _DynamicFieldMapper(
      List<String> positionalArgs,
      List<String> namedArgs,
      Map<String, FieldGetter<T, dynamic>> getters,
      Map<String, FieldSetter<T, dynamic>> setters,
      Map<String, Type> types,
      Map<String, Type> constructorTypes,
      Map<String, Field> getterFields,
      Map<String, Field> setterFields,
      Map<String, Field> constructorFields,
      Map<String, List> getterMetadata,
      Map<String, List> setterMetadata,
      Map<String, List> constructorMetadata,
      ModelFactory<T> createModel)
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

  @override
  Mapper/*<S,E>*/ createMapper/*<S,E>*/(Type type, dynamic/*=S*/ typeSentry) =>
      _dynamicMapper/*<S,E>*/(type, typeSentry);
}

Mapper/*<T,E>*/ _dynamicMapper/*<T,E>*/(Type type, dynamic objectMarker) {
  var mapper = _cache[type];
  if (mapper == null) {
    var clazz = reflectType(type);
    if (clazz.typeVariables.length > 0 &&
        !clazz.typeArguments.any((tm) => tm != reflectType(dynamic))) {
      //All the type arguments were dynamic. Fall back to reflectClass
      clazz = reflectClass(type);
    }
    if (clazz is! ClassMirror) throw new Exception('Type is not a class.');
    bool isMap =
        clazz == _mapMirror || (clazz as ClassMirror).isSubclassOf(_mapMirror);
    bool isList = clazz == _listMirror ||
        (clazz as ClassMirror).isSubclassOf(_listMirror);
    if (!isMap && !isList) {
      (clazz as ClassMirror).superinterfaces.forEach((i) {
        final d = i.originalDeclaration;
        if (d == _mapMirror) {
          isMap = true;
        } else if (d == _listMirror) {
          isList = true;
        }
      });
    }

    if (isMap) {
      mapper = const _MapDynamicMapper();
      _cache[type] = mapper;
      return mapper as Mapper/*<T,E>*/;
    } else if (isList) {
      mapper = const _ListDynamicMapper();
      _cache[type] = mapper;
      return mapper as Mapper/*<T,E>*/;
    }

    final List<String> factoryPositionalArgs = <String>[];
    final List<String> factoryNamedArgs = <String>[];
    final Map<String, FieldGetter<dynamic/*=T*/, dynamic>> getters =
        <String, FieldGetter<dynamic/*=T*/, dynamic>>{};
    final Map<String, FieldSetter<dynamic/*=T*/, dynamic>> setters =
        <String, FieldSetter<dynamic/*=T*/, dynamic>>{};
    final Map<String, Type> types = <String, Type>{};
    final Map<String, Type> constructorParameterTypes = <String, Type>{};
    final Map<String, Field> getterFields = <String, Field>{};
    final Map<String, Field> setterFields = <String, Field>{};
    final Map<String, Field> constructorFields = <String, Field>{};
    final Map<String, List> getterMetadata = <String, List>{};
    final Map<String, List> setterMetadata = <String, List>{};
    final Map<String, List> constructorMetadata = <String, List>{};
    final ModelFactory<dynamic/*=T*/ > createModel = (posArgs, namedArgs) =>
        (clazz as ClassMirror)
            .newInstance(
                new Symbol(""),
                posArgs,
                new Map.fromIterable(namedArgs.keys,
                    key: (k) => new Symbol(k), value: (k) => namedArgs[k]))
            .reflectee as dynamic/*=T*/;
    final Map<String, _FieldData> fields = <String, _FieldData>{};

    _buildChain(
        factoryPositionalArgs,
        factoryNamedArgs,
        getters,
        setters,
        types,
        constructorParameterTypes,
        getterFields,
        setterFields,
        constructorFields,
        getterMetadata,
        setterMetadata,
        constructorMetadata,
        clazz as ClassMirror,
        fields);

    if (fields.isEmpty) {
      mapper = new _NotEncodableMapper();
    } else {
      mapper = new _DynamicFieldMapper(
          factoryPositionalArgs,
          factoryNamedArgs,
          getters,
          setters,
          types,
          constructorParameterTypes,
          getterFields,
          setterFields,
          constructorFields,
          getterMetadata,
          setterMetadata,
          constructorMetadata,
          createModel);
    }
    _cache[type] = mapper;
  }
  return mapper as Mapper/*<T,E>*/;
}

void _buildChain/*<T,E>*/(
    List<String> factoryPositionalArgs,
    List<String> factoryNamedArgs,
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
    ClassMirror clazz,
    Map<String, _FieldData> fields,
    [bool isTopLevel = true]) {
  var superclass;
  try {
    superclass = clazz.superclass;
  } catch (err) {
    superclass = null;
  }
  if (superclass != null &&
      superclass.hasReflectedType &&
      clazz.superclass.reflectedType != Object) {
    _buildChain/*<T,E>*/(
        null,
        null,
        getters,
        setters,
        types,
        null,
        getterFields,
        setterFields,
        null,
        getterMetadata,
        setterMetadata,
        null,
        clazz.superclass,
        fields,
        false);
  }

  clazz.superinterfaces.forEach((interface) {
    _buildChain/*<T,E>*/(
        null,
        null,
        getters,
        setters,
        types,
        null,
        getterFields,
        setterFields,
        null,
        getterMetadata,
        setterMetadata,
        null,
        interface,
        fields,
        false);
  });

  clazz.declarations.forEach((name, mirror) {
    if (mirror is VariableMirror && !mirror.isStatic && !mirror.isPrivate) {
      final metadata =
          mirror.metadata.map((m) => m.reflectee).toList(growable: false);
      final fieldInfo =
          metadata.firstWhere((o) => o is Field, orElse: () => null) as Field;

      if (fieldInfo != null) {
        final fieldName = MirrorSystem.getName(mirror.simpleName);
        fields[fieldName] = new _FieldData(mirror.simpleName, metadata);

        _encodeField(fieldName, fieldInfo, metadata, mirror, mirror.type,
            getters, getterMetadata, getterFields, types);

        if (!mirror.isFinal) {
          _decodeSetter(fieldName, fieldInfo, metadata, mirror, mirror.type,
              setters, setterMetadata, setterFields, types);
        }
      }
    } else if (mirror is MethodMirror &&
        !mirror.isStatic &&
        !mirror.isPrivate) {
      if (mirror.isConstructor &&
          isTopLevel &&
          mirror.simpleName == clazz.simpleName) {
        mirror.parameters.forEach((parameterMirror) {
          final metadata = parameterMirror.metadata
              .map((m) => m.reflectee)
              .toList(growable: false);
          final fieldInfo = metadata.firstWhere((o) => o is Field,
              orElse: () => new Field()) as Field;
          final fieldName = MirrorSystem.getName(parameterMirror.simpleName);
          final TypeMirror fieldType = parameterMirror.type;
          _decodeConstructor(
              fieldName,
              fieldInfo,
              metadata,
              parameterMirror,
              factoryPositionalArgs,
              factoryNamedArgs,
              constructorFields,
              constructorMetadata,
              constructorTypes,
              fieldType);
        });
      }
      final metadata =
          mirror.metadata.map((m) => m.reflectee).toList(growable: false);
      final fieldInfo =
          metadata.firstWhere((o) => o is Field, orElse: () => null) as Field;

      if (fieldInfo != null) {
        var fieldName = MirrorSystem.getName(mirror.simpleName);
        if (mirror.isGetter) {
          fields[fieldName] = new _FieldData(mirror.simpleName, metadata);

          final TypeMirror fieldType = mirror.returnType;
          _encodeField(fieldName, fieldInfo, metadata, mirror, fieldType,
              getters, getterMetadata, getterFields, types);
        } else if (mirror.isSetter) {
          fieldName = fieldName.substring(0, fieldName.length - 1);

          final TypeMirror fieldType = mirror.parameters[0].type;
          _decodeSetter(fieldName, fieldInfo, metadata, mirror, fieldType,
              setters, setterMetadata, setterFields, types);
        }
      }
    }
  });
}

void _decodeConstructor(
    String fieldName,
    Field fieldInfo,
    List metadata,
    ParameterMirror mirror,
    List<String> factoryPositionalArgs,
    List<String> factoryNamedArgs,
    Map<String, Field> constructorFields,
    Map<String, List> constructorMetadata,
    Map<String, Type> constructorTypes,
    TypeMirror fieldType) {
  if (mirror.isNamed) {
    factoryNamedArgs.add(fieldName);
  } else {
    factoryPositionalArgs.add(fieldName);
  }
  constructorFields[fieldName] = fieldInfo;
  constructorMetadata[fieldName] = metadata;
  final type =
      (fieldType is TypeVariableMirror) ? dynamic : fieldType.reflectedType;
  constructorTypes[fieldName] = type;
}

void _decodeSetter/*<T>*/(
    String fieldName,
    Field fieldInfo,
    List metadata,
    DeclarationMirror mirror,
    TypeMirror fieldType,
    Map<String, FieldSetter> setters,
    Map<String, List> setterMetadata,
    Map<String, Field> setterFields,
    Map<String, Type> types) {
  final type =
      (fieldType is TypeVariableMirror) ? dynamic : fieldType.reflectedType;
  setters[fieldName] = (dynamic/*=T*/ obj, value) {
    reflect(obj).setField(new Symbol(fieldName), value);
  };
  setterMetadata[fieldName] = metadata;
  setterFields[fieldName] = fieldInfo;
  types[fieldName] = type;
}

void _encodeField/*<T>*/(
    String fieldName,
    Field fieldInfo,
    List metadata,
    DeclarationMirror mirror,
    TypeMirror fieldType,
    Map<String, FieldGetter/*<T,dynamic>*/ > getters,
    Map<String, List> getterMetadata,
    Map<String, Field> getterFields,
    Map<String, Type> types) {
  final type =
      (fieldType is TypeVariableMirror) ? dynamic : fieldType.reflectedType;

  getters[fieldName] = (dynamic/*=T*/ obj) {
    return reflect(obj).getField(mirror.simpleName).reflectee;
  };
  getterMetadata[fieldName] = metadata;
  getterFields[fieldName] = fieldInfo;
  types[fieldName] = type;
}
