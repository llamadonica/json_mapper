library json_mapper_transformer;

import 'dart:collection';
import 'dart:io';

import 'package:analyzer/analyzer.dart';
import 'package:analyzer/dart/element/element.dart';
import 'package:analyzer/dart/element/type.dart';
import 'package:analyzer/src/dart/element/type.dart';

import 'package:code_transformers/resolver.dart';
import 'package:barback/barback.dart';
import 'package:source_maps/refactor.dart' show TextEditTransaction;
import 'package:path/path.dart' as path;

/**
 * The redstone_mapper transformer, which replaces the default
 * mapper implementation, that relies on the mirrors API, by a
 * static implementation, that uses data extracted at compile
 * time.
 *
 */
class _Ref<T> {
  T value;
  _Ref(this.value);
}

class StaticMapperGenerator extends Transformer with ResolverTransformer {
  ClassElement objectType;
  ClassElement mapClass;
  ClassElement listClass;
  DynamicTypeImpl dynamicType;

  _CollectionType collectionType;
  ClassElement fieldAnnotationClass;
  ClassElement concreteTypeBaseClass;

  final _UsedLibs usedLibs = new _UsedLibs();
  final Map<String, _ConfigGenerator> types = {};
  final Queue<_Specialization> specializations = new Queue<_Specialization>();
  final HashSet<String> specializationKeys = new HashSet<String>();
  final HashSet<String> implementedSpecializations = new HashSet<String>();

  String _mapperLibPrefix;

  StaticMapperGenerator.asPlugin(BarbackSettings settings) {
    var sdkDir = settings.configuration["dart_sdk"];
    if (sdkDir == null) {
      // Assume the Pub executable is always coming from the SDK.
      sdkDir = path.dirname(path.dirname(Platform.executable));
    }
    resolvers = new Resolvers(sdkDir);
  }

  @override
  applyResolver(Transform transform, Resolver resolver) {
    fieldAnnotationClass = resolver.getType("json_mapper_metadata.Field");

    if (fieldAnnotationClass == null) {
      //mapper is not being used
      transform.addOutput(transform.primaryInput);
      return;
    }

    var dynamicApp =
        resolver.getLibraryFunction('dynamic_mapper_factory.bootstrapMapper');

    concreteTypeBaseClass =
        resolver.getType("json_mapper_metadata.ConcreteType");
    if (dynamicApp == null) {
      // No dynamic mapper imports, exit.
      transform.addOutput(transform.primaryInput);
      return;
    }

    objectType = resolver.getType("dart.core.Object");
    dynamicType = DynamicTypeImpl.instance;
    mapClass = resolver.getType('dart.core.Map');
    listClass = resolver.getType('dart.core.List');

    collectionType = new _CollectionType(resolver);
    _mapperLibPrefix = usedLibs
        .resolveLib(resolver.getLibraryByName("dynamic_mapper_factory"));

    var typesThatNeedToBeRevisited =
        new HashSet<_GenericClassCreatingConcreteType>();

    final concreteToSpecialization = new _ConcreteTypeToSpecialization(
        usedLibs,
        specializations,
        objectType.type,
        specializationKeys,
        typesThatNeedToBeRevisited,
        concreteTypeBaseClass);

    resolver.libraries
        .expand((lib) => lib.units)
        .forEach((unit) => unit.computeNode().accept(concreteToSpecialization));

    while (typesThatNeedToBeRevisited.isNotEmpty) {
      var revisitingTypesMap =
          new HashMap<ClassElement, List<_GenericClassCreatingConcreteType>>();
      typesThatNeedToBeRevisited.forEach((element) =>
          (revisitingTypesMap[element.classElement] ??=
                  <_GenericClassCreatingConcreteType>[])
              .add(element));
      typesThatNeedToBeRevisited =
          new HashSet<_GenericClassCreatingConcreteType>();
      final secondOrderConcreteTypeToSpecialization =
          new _SecondOrderTypeSpecialization(
              usedLibs,
              specializations,
              objectType.type,
              specializationKeys,
              typesThatNeedToBeRevisited,
              revisitingTypesMap);

      resolver.libraries.expand((lib) => lib.units).forEach((unit) =>
          unit.computeNode().accept(secondOrderConcreteTypeToSpecialization));
    }

    HashSet<ClassElement> classesToScan = new HashSet<ClassElement>.from(
        specializations
            .where((spec) =>
                !implementedSpecializations.contains(spec.fullySpecializedForm))
            .map((spec) => spec.genericClass));
    while (classesToScan.isNotEmpty) {
      resolver.libraries
          .expand((lib) => lib.units)
          .expand((unit) => unit.types)
          .forEach(
              (ClassElement clazz) => _preScannClass(clazz, classesToScan));
      classesToScan = new HashSet<ClassElement>.from(specializations
          .where((spec) =>
              !implementedSpecializations.contains(spec.fullySpecializedForm))
          .map((spec) => spec.genericClass));
    }

    resolver.libraries
        .expand((lib) => lib.units)
        .expand((unit) => unit.types)
        .forEach((ClassElement clazz) => _scannClassTop(clazz));

    final id = transform.primaryInput.id;
    final lib = resolver.getLibrary(id);
    final transaction = resolver.createTextEditTransaction(lib);

    final unit = lib.definingCompilationUnit.computeNode();

    final outputFilename = "${path.url.basenameWithoutExtension(id.path)}"
        "_static_mapper.dart";
    final outputPath = path.url.join(path.url.dirname(id.path), outputFilename);
    final generatedAssetId = new AssetId(id.package, outputPath);

    String typesSource = types.toString();

    StringBuffer source = new StringBuffer();
    _writeHeader(transform.primaryInput.id, source);
    usedLibs.libs.forEach((lib) {
      if (lib.isDartCore) return;
      var uri = resolver.getImportUri(lib, from: generatedAssetId);
      source.write("import '$uri' as ${usedLibs.prefixes[lib]};\n");
    });
    _writePreamble(source);
    source.write(typesSource);
    _writeFooter(source);

    transform
        .addOutput(new Asset.fromString(generatedAssetId, source.toString()));

    for (var directive in unit.directives) {
      if (directive is ImportDirective &&
          directive.uri.stringValue ==
              'package:json_mapper/mapper_factory.dart') {
        var uri = directive.uri;
        transaction.edit(uri.beginToken.offset, uri.end,
            '\'package:json_mapper/src/static_mapper.dart\'');
      }
    }

    var dynamicToStatic =
        new _MapperDynamicToStaticVisitor(dynamicApp, transaction);
    unit.accept(dynamicToStatic);

    _addImport(transaction, unit, outputFilename, 'generated_static_mapper');

    var printer = transaction.commit();
    var url = id.path.startsWith('lib/')
        ? 'package:${id.package}/${id.path.substring(4)}'
        : id.path;
    printer.build(url);
    transform.addOutput(new Asset.fromString(id, printer.text));
  }

  void _writeHeader(AssetId id, StringBuffer source) {
    var libName = path.withoutExtension(id.path).replaceAll('/', '.');
    libName = libName.replaceAll('-', '_');
    source.write("library ${id.package}.$libName.generated_static_mapper;\n");
    source.write(
        "import 'package:json_mapper/metadata.dart' as $_mapperLibPrefix;\n\n");
    source
        .write("import 'package:json_mapper/src/static_mapper.dart';\n\n");
  }

  void _writePreamble(StringBuffer source) {
    var defaultField = "const $_mapperLibPrefix.Field()";

    source.write(
        "_encodeField(data, fieldName, mapper, value, fieldEncoder, typeCodecs, type, \n");
    source.write(
        "             [fieldInfo = $defaultField, metadata = const [$defaultField]]) {\n");
    source.write("  if (value != null) {\n");
    source.write(
        "    value = mapper.encoder(value, fieldEncoder, typeCodecs);\n");
    source.write("    var typeCodec = typeCodecs[type];\n");
    source.write(
        "    value = typeCodec != null ? typeCodec.encode(value) : value;\n");
    source.write("  }\n");
    source.write("  fieldEncoder(data, fieldName, fieldInfo, metadata,\n");
    source.write("               value);\n");
    source.write("}\n\n");

    source.write(
        "_decodeField(data, fieldName, mapper, fieldDecoder, typeCodecs, type, \n");
    source.write(
        "             [fieldInfo = $defaultField, metadata = const [$defaultField]]) {\n");
    source.write(
        "  var value = fieldDecoder(data, fieldName, fieldInfo, metadata);\n");
    source.write("  if (value != null) {\n");
    source.write("    var typeCodec = typeCodecs[type];\n");
    source.write(
        "    value = typeCodec != null ? typeCodec.decode(value) : value;\n");
    source.write("    return mapper.decoder(value, fieldDecoder, typeCodecs);");
    source.write("  }\n");
    source.write("  return null;\n");
    source.write("}\n\n");

    source.write("final Map<Type, StaticMapper> types = <Type, StaticMapper>");
  }

  void _writeFooter(StringBuffer source) {
    source.write(";");
  }

  /// Injects an import into the list of imports in the file.
  void _addImport(TextEditTransaction transaction, CompilationUnit unit,
      String uri, String prefix) {
    var last = unit.directives.where((d) => d is ImportDirective).last;
    transaction.edit(last.end, last.end, '\nimport \'$uri\' as $prefix;');
  }

  _preScannClass(ClassElement clazz, HashSet<ClassElement> classesToScan,
      [_Ref<int> fields,
      Set<ClassElement> cache,
      List<List<DartType>> specificsToImplement]) {
    bool rootType = fields == null;
    if (rootType && !classesToScan.contains(clazz)) return;
    fields ??= new _Ref<int>(0);
    cache ??= new Set<ClassElement>();

    cache.add(clazz);
    if (specificsToImplement == null) {
      final specializationsToImplement = specializations
          .where((spec) =>
              !implementedSpecializations.contains(spec.fullySpecializedForm) &&
              spec.genericClass == clazz)
          .toList();

      implementedSpecializations.addAll(
          specializationsToImplement.map((spec) => spec.fullySpecializedForm));
      specificsToImplement ??=
          specializationsToImplement.map((spec) => spec.typeArguments).toList();
    }

    if (clazz == listClass) {
      for (var specialization in specificsToImplement) {
        _addTypeSpecialization(specialization[0]);
      }
      return;
    }
    if (clazz == mapClass) {
      for (var specialization in specificsToImplement) {
        _addTypeSpecialization(specialization[1]);
      }
      return;
    }

    if (clazz.supertype != null &&
        clazz.supertype.element != objectType &&
        !cache.contains(clazz.supertype.element)) {

      final innerSpecializations = specificsToImplement
          .map((typeArgs) => _replaceType(
                  clazz.supertype,
                  new Map.fromIterables(
                      clazz.typeParameters.map((tp) => tp.type), typeArgs))
              .typeParameters
              .map((tpe) => tpe.type)
              .toList())
          .toList();
      _preScannClass(clazz.supertype.element, classesToScan, fields, cache,
          innerSpecializations);
    }
    clazz.interfaces.where((i) => !cache.contains(i.element)).forEach((i) {
      final innerSpecializations = specificsToImplement
          .map((typeArgs) => _replaceType(
                  i,
                  new Map.fromIterables(
                      clazz.typeParameters.map((tp) => tp.type), typeArgs))
              .typeParameters
              .map((tpe) => tpe.type)
              .toList())
          .toList();
      _preScannClass(
          i.element, classesToScan, fields, cache, innerSpecializations);
    });
    clazz.fields
        .where((f) => !f.isStatic && !f.isPrivate)
        .forEach((f) => _prescannField(fields, clazz, f, specificsToImplement));

    clazz.accessors.where((f) => !f.isStatic && !f.isPrivate).forEach(
        (f) => _prescannAccessor(fields, clazz, f, specificsToImplement));
    if (rootType && fields.value > 0) {
      clazz.constructors
          .where((constructor) => constructor.displayName == '')
          .forEach((ctor) {
        ctor.parameters.forEach(
            (p) => _prescannField(fields, clazz, p, specificsToImplement));
      });
    }
  }

  void _scannClassTop(ClassElement clazz) {
    var genericsToInstantiate = specializations
        .where((spec) => spec.genericClass == clazz)
        .map((spec) => spec.typeArguments)
        .toList();
    final bool forceImplement = genericsToInstantiate.length != 0;
    if (!genericsToInstantiate
        .any((spec) => !spec.any((t) => t != dynamicType))) {
      genericsToInstantiate
          .add(clazz.typeParameters.map((_) => dynamicType).toList());
    }
    genericsToInstantiate.forEach((genericToInstantiate) =>
        _scannClass(clazz, genericToInstantiate, forceImplement));
  }

  void _scannClass(
      ClassElement clazz, List<DartType> specialization, bool forceImplement,
      [List<_FieldInfo> fields,
      List<_FieldInfo> constructorParameters,
      Set<ClassElement> cache,
      Map<String, int> fieldIdxs,
      Map<String, int> accessorIdxs,
      Map<String, int> constructorParameterIdxs]) {
    bool rootType = fields == null;
    print('>>> Scanning ${clazz.displayName} over <${specialization.join(',')}>');

    fields ??= <_FieldInfo>[];
    constructorParameters ??= <_FieldInfo>[];
    cache ??= new Set<ClassElement>();
    fieldIdxs ??= <String, int>{};
    accessorIdxs ??= <String, int>{};
    constructorParameterIdxs ??= <String, int>{};

    cache.add(clazz);

    DartType type;
    String resolvedTypeName;
    String key;
    final resolveKey = () {
      type = _replaceTypeOuter(
          clazz.type,
          new Map.fromIterables(
              clazz.typeParameters.map((tp) => tp.type), specialization));
      resolvedTypeName = getTypeName(type, dynamicType, usedLibs);
      key = resolvedTypeName.contains('<')
          ? 'new $_mapperLibPrefix.ConcreteType<$resolvedTypeName>().type'
          : resolvedTypeName;
    };

    if (clazz == listClass && rootType) {
      resolveKey();
      types[key] = new _ListMapperConfigGenerator(
          specialization[0], objectType.type, usedLibs);
      return;
    }
    if (clazz == mapClass && rootType) {
      resolveKey();
      types[key] = new _MapMapperConfigGenerator(
          specialization[1], objectType.type, usedLibs);
      return;
    }
    if (clazz.supertype != null &&
        clazz.supertype.element != objectType &&
        !cache.contains(clazz.supertype.element)) {
      print('>>>> ${clazz.displayName} isa ${clazz.supertype}');
      final innerSpecializations = _replaceType(
              clazz.supertype,
              new Map.fromIterables(
                  clazz.typeParameters.map((tp) => tp.type), specialization))
          .typeArguments
          .toList();

      _scannClass(clazz.supertype.element, innerSpecializations, forceImplement,
          fields, [], cache, fieldIdxs, accessorIdxs, {});
    }

    clazz.interfaces.where((i) => !cache.contains(i.element)).forEach((i) {
      final innerSpecializations = _replaceType(
              i,
              new Map.fromIterables(
                  clazz.typeParameters.map((tp) => tp.type), specialization))
          .typeParameters
          .map((tpe) => tpe.type)
          .toList();
      _scannClass(i.element, innerSpecializations, forceImplement, fields, [],
          cache, fieldIdxs, accessorIdxs, {});
    });

    clazz.fields.where((f) => !f.isStatic && !f.isPrivate).forEach(
        (f) => _scannField(fields, f, fieldIdxs, specialization, clazz));

    clazz.accessors.where((p) => !p.isStatic && !p.isPrivate).forEach(
        (p) => _scannAccessor(fields, p, accessorIdxs, specialization, clazz));

    if (rootType && fields.isNotEmpty) {
      resolveKey();
      clazz.constructors
          .where((constructor) => constructor.displayName == '')
          .forEach((ctor) {
        ctor.parameters.forEach((p) => _scannParameter(constructorParameters, p,
            constructorParameterIdxs, specialization, clazz));
      });

      types[key] = new _FieldMapperConfigGenerator(
          collectionType,
          usedLibs,
          resolvedTypeName,
          fields,
          constructorParameters,
          resolvedTypeName,
          objectType.type,
          _mapperLibPrefix);
    } else if (rootType && forceImplement) {
      resolveKey();
      types[key] =
          new _NotEncodableConfigGenerator(type, objectType.type, usedLibs);
    }
  }

  List<String> _extractArgs(String source, String name, bool isInitializer) {
    final stringToScanFor =
        isInitializer ? "(\\s|this\\.|\\{||\\[)$name" : "\\s$name";

    source =
        source.substring(0, source.lastIndexOf(new RegExp(stringToScanFor)));

    var idx = source.lastIndexOf(new RegExp("[@\)]"));
    if (idx == -1) {
      return [];
    }

    var char = source[idx];
    if (char == ")") {
      source = source.substring(0, idx + 1);
    } else {
      idx = source.indexOf("\s", idx);
      source = source.substring(0, idx);
    }

    return source.split(new RegExp(r"\s@")).map((m) {
      if (m[m.length - 1] == ")") {
        return m.substring(m.indexOf("("));
      }
      return m;
    }).toList(growable: false);
  }

  bool _isFieldConstructor(ElementAnnotation m) =>
      m.element is ConstructorElement &&
      (m.element.enclosingElement == fieldAnnotationClass ||
          (m.element.enclosingElement as ClassElement)
              .allSupertypes
              .map((i) => i.element)
              .contains(fieldAnnotationClass));

  _FieldMetadata _buildMetadata(Element element, [bool isInitializer = false]) {
    String source;
    if (element is FieldElement) {
      source = element.computeNode().parent.parent.toSource();
    } else {
      source = element.computeNode().toSource();
    }

    List<String> args =
        _extractArgs(source, element.displayName, isInitializer);

    String fieldExp;
    List<String> exps = [];

    int idx = 0;
    for (ElementAnnotation m in element.metadata) {
      var prefix = usedLibs.resolveLib(m.element.library);
      if (prefix.isNotEmpty) {
        prefix += ".";
      }

      if (m.element is ConstructorElement) {
        var className = m.element.enclosingElement.displayName;
        var constructor = m.element.displayName;
        if (constructor.isNotEmpty) {
          constructor = ".$constructor";
        }
        var exp = "const $prefix$className$constructor${args[idx]}";
        exps.add(exp);
        if (fieldExp == null && _isFieldConstructor(m)) {
          fieldExp = exp;
        }
      } else {
        exps.add("$prefix${args[idx]}");
      }

      idx++;
    }

    return new _FieldMetadata(fieldExp, exps);
  }

  _scannParameter(
      List<_FieldInfo> constructorParameters,
      ParameterElement element,
      Map<String, int> constructorParameterIdxs,
      List<DartType> specialization,
      ClassElement clazz) {
    var metadata = _buildMetadata(element, true);
    final type = _replaceTypeOuter(
        element.type,
        new Map.fromIterables(
            clazz.typeParameters.map((tp) => tp.type), specialization));
    constructorParameters.add(new _FieldInfo(
        element.displayName, type, metadata,
        canDecode: true, isNamed: element.parameterKind.ordinal == null));
    if (element.parameterKind.ordinal != null) {
      constructorParameterIdxs[element.displayName];
    }
  }

  _prescannField(_Ref<int> fields, ClassElement clazz, VariableElement element,
      List<List<DartType>> specificsToImplement) {
    var field = element.metadata
        .firstWhere((f) => _isFieldConstructor(f), orElse: () => null);
    if (field != null) {
      fields.value++;
      if (_getUnresolvedTypeParameters(element.type).isNotEmpty) {
        for (var specializationToImplement in specificsToImplement) {
          final specializedType = _replaceTypeOuter(
              element.type,
              new Map.fromIterables(clazz.typeParameters.map((tp) => tp.type),
                  specializationToImplement));
          _addTypeSpecialization(specializedType);
        }
      } else {
        _addTypeSpecialization(element.type);
      }
    }
  }

  _addTypeSpecialization(DartType typeToSpecialize) {
    if (typeToSpecialize is ParameterizedType) {
      final underlyingType = getShortTypeName(typeToSpecialize, usedLibs);
      final qualifiedType =
          getTypeName(typeToSpecialize, objectType.type, usedLibs);
      if (!specializationKeys.contains(qualifiedType)) {
        specializationKeys.add(qualifiedType);
        specializations.add(new _Specialization(typeToSpecialize.element,
            underlyingType, qualifiedType, typeToSpecialize.typeArguments));
      }
    }
  }

  void _scannField(
      List<_FieldInfo> fields,
      FieldElement element,
      Map<String, int> fieldIdxs,
      List<DartType> specialization,
      ClassElement clazz) {
    var field = element.metadata
        .firstWhere((f) => _isFieldConstructor(f), orElse: () => null);
    if (field != null) {
      var idx = fieldIdxs[element.displayName];
      if (idx != null) {
        fields.removeAt(idx);
      }

      var metadata = _buildMetadata(element);
      final type = _replaceTypeOuter(
          element.type,
          new Map.fromIterables(
              clazz.typeParameters.map((tp) => tp.type), specialization));
      fields.add(new _FieldInfo(element.displayName, type, metadata,
          canDecode: !element.isFinal));

      fieldIdxs[element.displayName] = fields.length - 1;
    }
  }

  _prescannAccessor(
      _Ref<int> fields,
      ClassElement clazz,
      PropertyAccessorElement element,
      List<List<DartType>> specificsToImplement) {
    var field = element.metadata
        .firstWhere((f) => _isFieldConstructor(f), orElse: () => null);

    if (field != null) {
      fields.value++;
      DartType type = element.isSetter
          ? (element.type.normalParameterTypes[0])
          : element.returnType;
      if (_getUnresolvedTypeParameters(type).isNotEmpty) {
        for (var specializationToImplement in specificsToImplement) {
          final specializedType = _replaceTypeOuter(
              type,
              new Map.fromIterables(clazz.typeParameters.map((tp) => tp.type),
                  specializationToImplement));
          _addTypeSpecialization(specializedType);
        }
      } else {
        _addTypeSpecialization(type);
      }
    }
  }

  void _scannAccessor(
      List<_FieldInfo> fields,
      PropertyAccessorElement element,
      Map<String, int> accessorIdxs,
      List<DartType> specialization,
      ClassElement clazz) {
    var field = element.metadata
        .firstWhere((f) => _isFieldConstructor(f), orElse: () => null);
    if (field != null) {
      var metadata = _buildMetadata(element);
      var name = element.displayName;
      var type;
      var idx;
      if (element.isSetter) {
        name = name.substring(0, name.length - 1);

        idx = accessorIdxs[name];
        if (idx != null) {
          fields.removeAt(idx);
        }

        type = element.type.normalParameterTypes[0];
      } else {
        idx = accessorIdxs[name];
        if (idx != null) {
          fields.removeAt(idx);
        }

        type = element.returnType;
      }
      type = _replaceTypeOuter(
          type,
          new Map.fromIterables(
              clazz.typeParameters.map((tp) => tp.type), specialization));
      fields.add(new _FieldInfo(element.displayName, type, metadata,
          canDecode: element.isSetter, canEncode: element.isGetter));

      accessorIdxs[name] = fields.length - 1;
    }
  }
}

class _Specialization {
  final ClassElement genericClass;
  final String fullyGenericForm;
  final String fullySpecializedForm;
  final List<DartType> typeArguments;

  _Specialization(this.genericClass, this.fullyGenericForm,
      this.fullySpecializedForm, this.typeArguments);
}

abstract class _ConfigGenerator {
  final InterfaceType _objectType;
  final _UsedLibs usedLibs;

  _ConfigGenerator(this._objectType, this.usedLibs);

  String _getTypeName(DartType type) =>
      getTypeName(type, _objectType, usedLibs);
}

class _FieldMapperConfigGenerator extends _ConfigGenerator {
  final String key;
  final _CollectionType collectionType;

  final String className;
  final List<_FieldInfo> fields;
  final List<_FieldInfo> constructorParameters;

  final String _mapperLibPrefix;

  _FieldMapperConfigGenerator(
      this.collectionType,
      _UsedLibs usedLibs,
      this.className,
      this.fields,
      this.constructorParameters,
      this.key,
      InterfaceType _objectType,
      this._mapperLibPrefix)
      : super(_objectType, usedLibs);

  String toString() {
    var source = new StringBuffer("new StaticFieldMapper<$key>(\n");
    _buildPositionalArgs(source);
    source.write(',\n');
    _buildNamedArgs(source);
    source.write(',\n');
    _buildGetters(source);
    source.write(',\n');
    _buildSetters(source);
    source.write(',\n');
    _buildFieldTypes(source);
    source.write(',\n');
    _buildConstructorTypes(source);
    source.write(',\n');
    _buildEncoderFieldExp(source);
    source.write(',\n');
    _buildDecoderFieldExp(source);
    source.write(',\n');
    _buildConstructorFieldExp(source);
    source.write(',\n');
    _buildEncoderMetadataExp(source);
    source.write(',\n');
    _buildDecoderMetadataExp(source);
    source.write(',\n');
    _buildConstructorMetadataExp(source);
    source.write(',\n');
    _buildFactory(source);
    source.write(')');
    return source.toString();
  }

  void _buildNamedArgs(StringBuffer source) {
    source.write('  namedArgs: [');
    source.write(constructorParameters
        .where((f) => f.isNamed)
        .map((f) => "'${f.name}'")
        .join(','));
    source.write(']');
  }

  void _buildPositionalArgs(StringBuffer source) {
    source.write('  positionalArgs: [');
    source.write(constructorParameters
        .where((f) => !f.isNamed)
        .map((f) => "'${f.name}'")
        .join(','));
    source.write(']');
  }

  void _buildGetters(StringBuffer source) {
    source.write('  getters: {');
    source.write(fields
        .where((f) => f.canEncode)
        .map((f) => "\n    '${f.name}' : ($key o) => o.${f.name}")
        .join(','));
    source.write('\n  }');
  }

  void _buildSetters(StringBuffer source) {
    source.write('  setters: {');
    source.write(fields
        .where((f) => f.canDecode)
        .map((f) =>
            "\n    '${f.name}' : ($key o, ${_getTypeName(f.type)} v) {o.${f.name} = v;}")
        .join(','));
    source.write('\n  }');
  }

  void _buildFieldTypes(StringBuffer source) {
    source.write('  types: {');

    source.write(
        new Map<String, _FieldInfo>.fromIterable(fields, key: (f) => f.name)
            .values
            .map((f) => "\n    '${f.name}': ${_getOuterTypeName(f.type)}")
            .join(','));
    source.write('\n  }');
  }

  void _buildConstructorTypes(StringBuffer source) {
    source.write('  constructorTypes: {');
    source.write(constructorParameters
        .map((f) => "\n    '${f.name}': ${_getOuterTypeName(f.type)}")
        .join(','));
    source.write('\n  }');
  }

  void _buildEncoderFieldExp(StringBuffer source) {
    source.write('  getterFields: {');
    source.write(fields
        .where((f) => f.canEncode)
        .map((f) =>
            "\n    '${f.name}' : " +
            (f.metadata?.fieldExp ?? 'const $_mapperLibPrefix.Field()'))
        .join(','));
    source.write('\n  }');
  }

  void _buildDecoderFieldExp(StringBuffer source) {
    source.write('  setterFields: {');
    source.write(fields
        .where((f) => f.canDecode)
        .map((f) =>
            "\n    '${f.name}' : " +
            (f.metadata?.fieldExp ?? 'const $_mapperLibPrefix.Field()'))
        .join(','));
    source.write('\n  }');
  }

  void _buildConstructorFieldExp(StringBuffer source) {
    source.write('  constructorFields: {');
    source.write(constructorParameters
        .where((f) => f.canDecode)
        .map((f) =>
            "\n    '${f.name}' : " +
            (f.metadata?.fieldExp ?? 'const $_mapperLibPrefix.Field()'))
        .join(','));
    source.write('\n  }');
  }

  void _buildEncoderMetadataExp(StringBuffer source) {
    source.write('  getterMetadata: {');
    source.write(fields
        .where((f) => f.canEncode)
        .map((f) =>
            "\n    '${f.name}' : " + (f.metadata?.exps?.toString() ?? '[]'))
        .join(','));
    source.write('\n  }');
  }

  void _buildDecoderMetadataExp(StringBuffer source) {
    source.write('  setterMetadata: {');
    source.write(fields
        .where((f) => f.canDecode)
        .map((f) =>
            "\n    '${f.name}' : " + (f.metadata?.exps?.toString() ?? '[]'))
        .join(','));
    source.write('\n  }');
  }

  void _buildConstructorMetadataExp(StringBuffer source) {
    source.write('  constructorMetadata: {');
    source.write(constructorParameters
        .where((f) => f.canDecode)
        .map((f) =>
            "\n    '${f.name}' : " + (f.metadata?.exps?.toString() ?? '[]'))
        .join(','));
    source.write('\n  }');
  }

  void _buildFactory(StringBuffer source) {
    source.write(
        '  createModel: (List args, Map<String, dynamic> namedArgs) => new $key(');
    var i = 0;
    source.write(constructorParameters
        .map((f) => f.isNamed ? 'namedArgs[${f.name}]' : 'args[${i++}]')
        .join(', '));
    source.write(')');
  }

  String _getOuterTypeName(DartType type) {
    var typeName = _getTypeName(type);
    if (!typeName.contains('<')) {
      return typeName;
    }
    return 'new $_mapperLibPrefix.ConcreteType<$typeName>().type';
  }
}

class _ListMapperConfigGenerator extends _ConfigGenerator {
  final DartType innerType;

  _ListMapperConfigGenerator(
      this.innerType, InterfaceType _objectType, _UsedLibs usedLibs)
      : super(_objectType, usedLibs);

  @override
  String toString() => 'new StaticListMapper<${_getTypeName(innerType)}>()';
}

class _MapMapperConfigGenerator extends _ConfigGenerator {
  final DartType innerType;

  _MapMapperConfigGenerator(
      this.innerType, InterfaceType _objectType, _UsedLibs usedLibs)
      : super(_objectType, usedLibs);

  @override
  String toString() => 'new StaticMapMapper<${_getTypeName(innerType)}>()';
}

class _NotEncodableConfigGenerator extends _ConfigGenerator {
  final DartType thisType;

  _NotEncodableConfigGenerator(
      this.thisType, InterfaceType _objectType, _UsedLibs usedLibs)
      : super(_objectType, usedLibs);

  @override
  String toString() =>
      'new StaticNotEncodableMapper<${_getTypeName(thisType)}>()';
}

String getShortTypeName(DartType type, _UsedLibs usedLibs) {
  String typePrefix = "";
  String typeName;

  if (type.element != null && !type.isDynamic) {
    typePrefix = usedLibs.resolveLib(type.element.library);
  }
  if (typePrefix.isNotEmpty) {
    typeName = "$typePrefix.${type.name}";
  } else {
    typeName = "${type.name}";
  }
  return typeName;
}

String getTypeName(DartType type, DartType objectType, _UsedLibs usedLibs) {
  String typePrefix = "";
  String typeName;
  type = type.resolveToBound(objectType);

  if (type.element != null && !type.isDynamic) {
    typePrefix = usedLibs.resolveLib(type.element.library);
  }
  if (typePrefix.isNotEmpty) {
    typeName = "$typePrefix.${type.name}";
  } else {
    typeName = "${type.name}";
  }
  if (type is ParameterizedType && type.typeArguments.length > 0) {
    typeName =
        '$typeName<${type.typeArguments.map((it) => getTypeName(it, objectType, usedLibs)).join(",")}>';
  }

  return typeName;
}

class _UsedLibs {
  final Set<LibraryElement> libs = new Set();
  final Map<LibraryElement, String> prefixes = {};

  String resolveLib(LibraryElement lib) {
    libs.add(lib);
    var prefix = prefixes[lib];
    if (prefix == null) {
      prefix = lib.isDartCore ? "" : "import_${prefixes.length}";
      prefixes[lib] = prefix;
    }
    return prefix;
  }
}

class _CollectionType {
  ClassElement listType;
  ClassElement mapType;

  _CollectionType(Resolver resolver) {
    listType = resolver.getType("dart.core.List");
    mapType = resolver.getType("dart.core.Map");
  }

  bool isList(DartType type) =>
      type.element is ClassElement &&
      (type.element == listType ||
          (type.element as ClassElement)
              .allSupertypes
              .map((i) => i.element)
              .contains(listType));

  bool isMap(DartType type) =>
      type.element is ClassElement &&
      (type.element == mapType ||
          (type.element as ClassElement)
              .allSupertypes
              .map((i) => i.element)
              .contains(mapType));
}

class _FieldMetadata {
  final String fieldExp;
  final List<String> exps;

  _FieldMetadata(this.fieldExp, this.exps);
}

class _FieldInfo {
  final String name;
  final _FieldMetadata metadata;
  final DartType type;
  final bool canEncode;
  final bool canDecode;
  final bool isNamed;

  _FieldInfo(this.name, this.type, this.metadata,
      {this.canDecode: true, this.canEncode: true, this.isNamed: false});
}

/// Get the list of unbound type parameters used within a type.
Iterable<TypeParameterType> _getUnresolvedTypeParameters(
    DartType baseType) sync* {
  if (baseType is ParameterizedType) {
    yield* baseType.typeArguments
        .expand((ta) => _getUnresolvedTypeParameters(ta));
  } else if (baseType is TypeParameterType) {
    yield baseType;
  }
}

class _MapperDynamicToStaticVisitor extends GeneralizingAstVisitor {
  final Element mapperDynamicFn;
  final TextEditTransaction transaction;

  _MapperDynamicToStaticVisitor(this.mapperDynamicFn, this.transaction);

  visitMethodInvocation(MethodInvocation m) {
    if (m.methodName.bestElement == mapperDynamicFn) {
      transaction.edit(m.methodName.beginToken.offset,
          m.methodName.endToken.end, 'staticBootstrapMapper');

      var args = m.argumentList;
      transaction.edit(args.beginToken.offset + 1, args.end - 1,
          'generated_static_mapper.types');
    }
    super.visitMethodInvocation(m);
  }
}

/// POD type for a class with generic type arguments that can create
/// a [ConcreteType] when implemented with specific parameters.
class _GenericClassCreatingConcreteType {
  final ClassElement classElement;
  final List<TypeParameterType> parameters;
  final InterfaceType resultingTypeOnCreation;

  _GenericClassCreatingConcreteType(
      this.classElement, this.parameters, this.resultingTypeOnCreation);
}

/// The base classes for the specialization visitors.
abstract class _SpecializationVisitor extends GeneralizingAstVisitor<Null> {
  final HashSet<_GenericClassCreatingConcreteType> classesToCheck;
  final DartType objectType;
  final Queue<_Specialization> specializations;
  final HashSet<String> specializationKeys;
  final _UsedLibs usedLibs;

  _SpecializationVisitor(this.usedLibs, this.specializations, this.objectType,
      this.specializationKeys, this.classesToCheck);

  @override
  visitInstanceCreationExpression(InstanceCreationExpression c) {
    final staticType = c.staticType;
    if (staticType is! ParameterizedType) return;
    final normalizedTypes = _toConcreteTypes(c.staticElement, staticType);
    for (var normalizedType in normalizedTypes) {
      var _unresolvedTypeParameters =
          _getUnresolvedTypeParameters(normalizedType);
      if (_unresolvedTypeParameters.isNotEmpty) {
        classesToCheck.add(new _GenericClassCreatingConcreteType(
            _unresolvedTypeParameters.first.element.enclosingElement
                as ClassElement,
            _unresolvedTypeParameters.toList(),
            normalizedType));
        return;
      }

      var typeToSpecialize =
          (normalizedType as ParameterizedType).typeArguments[0];
      if (typeToSpecialize is ParameterizedType) {
        typeToSpecialize = typeToSpecialize.resolveToBound(objectType);
      }
      final underlyingType = getShortTypeName(typeToSpecialize, usedLibs);
      final qualifiedType = getTypeName(typeToSpecialize, objectType, usedLibs);
      if (typeToSpecialize is InterfaceType) {
        if (!specializationKeys.contains(qualifiedType)) {
          specializationKeys.add(qualifiedType);
          specializations.add(new _Specialization(typeToSpecialize.element,
              underlyingType, qualifiedType, typeToSpecialize.typeArguments));
        }
      }
    }
  }

  Iterable<DartType> _toConcreteTypes(
      ConstructorElement staticElement, ParameterizedType staticType);
}

/// Looks for statements that create classes with generic parameters,
/// when those classes create [ConcreteType]s.
///
/// This can't resolve indeterminate types, however it won't filter them out,
/// and since it works bottom-up instead of top-down, some statements that
/// would not cause problems with the reflect-based parser will cause
/// the transformer to not terminate. For instance the function below will not
/// terminate.
///
///     class ConcreteTypeFail<T> {
///       final ConcreteType<T> c = new ConcreteType<T>();
///       ConcreteTypeFail<List<T>> getListType() => new ConcreteTypeFail<List<T>>();
///     }
///
/// The reason is that it will keep seeing that
class _SecondOrderTypeSpecialization extends _SpecializationVisitor {
  final HashMap<ClassElement, Iterable<_GenericClassCreatingConcreteType>>
      inputClasses;

  _SecondOrderTypeSpecialization(
      _UsedLibs usedLibs,
      Queue<_Specialization> specializations,
      DartType objectType,
      HashSet<String> specializationKeys,
      HashSet<_GenericClassCreatingConcreteType> classesToCheck,
      this.inputClasses)
      : super(usedLibs, specializations, objectType, specializationKeys,
            classesToCheck);

  Iterable<DartType> _toConcreteTypes(
      ConstructorElement staticElement, ParameterizedType staticType) sync* {
    if (inputClasses.containsKey(staticElement.enclosingElement)) {
      yield* _resolveTypes(
          inputClasses[staticElement.enclosingElement], staticType);
    }
    for (var superClass in staticElement.enclosingElement.allSupertypes
        .where((st) => inputClasses.containsKey(st.element))) {
      final settledType = _replaceType(
          superClass,
          new Map<TypeParameterType, DartType>.fromIterables(
              staticType.typeParameters.map((tpe) => tpe.type),
              staticType.typeArguments));
      yield* _resolveTypes(inputClasses[superClass.element], settledType);
    }
  }

  Iterable<DartType> _resolveTypes(
          Iterable<_GenericClassCreatingConcreteType> iterable,
          ParameterizedType settledType) =>
      iterable.map((classFactory) => _replaceType(
          classFactory.resultingTypeOnCreation,
          new Map.fromIterables(
              settledType.typeParameters.map((tpt) => tpt.type),
              settledType.typeArguments)));
}

/// Checks for statements that create a new [ConcreteType].
class _ConcreteTypeToSpecialization extends _SpecializationVisitor {
  final ClassElement concreteTypeBaseClass;

  _ConcreteTypeToSpecialization(
      _UsedLibs usedLibs,
      Queue<_Specialization> specializations,
      DartType objectType,
      HashSet<String> specializationKeys,
      HashSet<_GenericClassCreatingConcreteType> classesToCheck,
      this.concreteTypeBaseClass)
      : super(usedLibs, specializations, objectType, specializationKeys,
            classesToCheck);

  DartType _toConcreteType(ConstructorElement element, ParameterizedType type) {
    return element?.enclosingElement == concreteTypeBaseClass
        ? type
        : _replaceType(
            element?.enclosingElement?.allSupertypes?.firstWhere(
                (st) => st.element == concreteTypeBaseClass,
                orElse: () => null),
            new Map<TypeParameterType, DartType>.fromIterables(
                type.typeParameters.map((tpe) => tpe.type),
                type.typeArguments));
  }

  Iterable<DartType> _toConcreteTypes(
      ConstructorElement element, ParameterizedType type) sync* {
    final result = _toConcreteType(element, type);
    if (result != null) yield result;
  }
}

/// Similar to the [allSupertypes] getter on [ClassElement] however, this
/// only yields those supertypes where the subtypes inherit the methods
/// from its superclasses (i.e., mixins and direct inheritance)
Iterable<InterfaceType> _implementedSupertypes(ClassElement c) sync* {
  if (c.supertype != null) yield c.supertype;
  yield* c.mixins;
}

DartType _replaceTypeOuter(
    DartType arg, Map<TypeParameterType, DartType> types) {
  if (arg is TypeParameterType && types.containsKey(arg)) {
    return types[arg];
  } else if (arg is InterfaceType) {
    return _replaceType(arg, types);
  }
  return arg;
}

/// Replace all the parameters of a type, including all the parameters of its
/// parameters with a map of types.
ParameterizedType _replaceType(
    InterfaceType input, Map<TypeParameterType, DartType> types) {
  if (input == null) return null;
  var outerParameters =
      input.typeArguments.map((arg) => _replaceTypeOuter(arg, types)).toList();

  return input.element.type.instantiate(outerParameters);
}
