library display_metadata.test.mapper_test.generated_static_mapper;
import 'package:json_mapper/metadata.dart' as import_0;

import 'package:json_mapper/src/static_mapper.dart';

import 'package:json_mapper/mapper_factory.dart' as import_0;
import '../mapper_static_test.dart' as import_2;
import 'package:json_mapper/metadata.dart' as import_3;
import '../src/aux.dart' as import_4;


final Map<Type, StaticMapper> types = <Type, StaticMapper>{import_2.Foo: new StaticFieldMapper<import_2.Foo>(
    positionalArgs: [],
    namedArgs: [],
    getters: {
      'foo' : (import_2.Foo o) => o.foo,
      'bar' : (import_2.Foo o) => o.bar,
      'buzz' : (import_2.Foo o) => o.buzz
    },
    setters: {
      'foo' : (import_2.Foo o, String v) {o.foo = v;},
      'bar' : (import_2.Foo o, int v) {o.bar = v;},
      'buzz' : (import_2.Foo o, List<String> v) {o.buzz = v;}
    },
    types: {
      'foo': String,
      'bar': int,
      'buzz': new import_0.ConcreteType<List<String>>().type
    },
    constructorTypes: {
    },
    getterFields: {
      'foo' : const import_3.Field(),
      'bar' : const import_3.Field(),
      'buzz' : const import_3.Field()
    },
    setterFields: {
      'foo' : const import_3.Field(),
      'bar' : const import_3.Field(),
      'buzz' : const import_3.Field()
    },
    constructorFields: {
    },
    getterMetadata: {
      'foo' : [const import_3.Field()],
      'bar' : [const import_3.Field()],
      'buzz' : [const import_3.Field()]
    },
    setterMetadata: {
      'foo' : [const import_3.Field()],
      'bar' : [const import_3.Field()],
      'buzz' : [const import_3.Field()]
    },
    constructorMetadata: {
    },
    createModel: (List args, Map<String, dynamic> namedArgs) => new import_2.Foo()), import_2.NestedType: new StaticFieldMapper<import_2.NestedType>(
    positionalArgs: [],
    namedArgs: [],
    getters: {
      'id' : (import_2.NestedType o) => o.id,
      'foos' : (import_2.NestedType o) => o.foos
    },
    setters: {
      'id' : (import_2.NestedType o, String v) {o.id = v;},
      'foos' : (import_2.NestedType o, Map<String,import_2.Foo> v) {o.foos = v;}
    },
    types: {
      'id': String,
      'foos': new import_0.ConcreteType<Map<String,import_2.Foo>>().type
    },
    constructorTypes: {
    },
    getterFields: {
      'id' : const import_3.Field(model: '_id'),
      'foos' : const import_3.Field(model: 'Foos')
    },
    setterFields: {
      'id' : const import_3.Field(model: '_id'),
      'foos' : const import_3.Field(model: 'Foos')
    },
    constructorFields: {
    },
    getterMetadata: {
      'id' : [const import_3.Field(model: '_id')],
      'foos' : [const import_3.Field(model: 'Foos')]
    },
    setterMetadata: {
      'id' : [const import_3.Field(model: '_id')],
      'foos' : [const import_3.Field(model: 'Foos')]
    },
    constructorMetadata: {
    },
    createModel: (List args, Map<String, dynamic> namedArgs) => new import_2.NestedType()), new import_0.ConcreteType<import_2.GenericType<import_2.Foo>>().type: new StaticFieldMapper<import_2.GenericType<import_2.Foo>>(
    positionalArgs: [],
    namedArgs: [],
    getters: {
      'any' : (import_2.GenericType<import_2.Foo> o) => o.any
    },
    setters: {
      'any' : (import_2.GenericType<import_2.Foo> o, import_2.Foo v) {o.any = v;}
    },
    types: {
      'any': import_2.Foo
    },
    constructorTypes: {
    },
    getterFields: {
      'any' : const import_3.Field()
    },
    setterFields: {
      'any' : const import_3.Field()
    },
    constructorFields: {
    },
    getterMetadata: {
      'any' : [const import_3.Field()]
    },
    setterMetadata: {
      'any' : [const import_3.Field()]
    },
    constructorMetadata: {
    },
    createModel: (List args, Map<String, dynamic> namedArgs) => new import_2.GenericType<import_2.Foo>()), new import_0.ConcreteType<import_2.GenericType<dynamic>>().type: new StaticFieldMapper<import_2.GenericType<dynamic>>(
    positionalArgs: [],
    namedArgs: [],
    getters: {
      'any' : (import_2.GenericType<dynamic> o) => o.any
    },
    setters: {
      'any' : (import_2.GenericType<dynamic> o, dynamic v) {o.any = v;}
    },
    types: {
      'any': dynamic
    },
    constructorTypes: {
    },
    getterFields: {
      'any' : const import_3.Field()
    },
    setterFields: {
      'any' : const import_3.Field()
    },
    constructorFields: {
    },
    getterMetadata: {
      'any' : [const import_3.Field()]
    },
    setterMetadata: {
      'any' : [const import_3.Field()]
    },
    constructorMetadata: {
    },
    createModel: (List args, Map<String, dynamic> namedArgs) => new import_2.GenericType<dynamic>()), new import_0.ConcreteType<import_2.GenericType<int>>().type: new StaticFieldMapper<import_2.GenericType<int>>(
    positionalArgs: [],
    namedArgs: [],
    getters: {
      'any' : (import_2.GenericType<int> o) => o.any
    },
    setters: {
      'any' : (import_2.GenericType<int> o, int v) {o.any = v;}
    },
    types: {
      'any': int
    },
    constructorTypes: {
    },
    getterFields: {
      'any' : const import_3.Field()
    },
    setterFields: {
      'any' : const import_3.Field()
    },
    constructorFields: {
    },
    getterMetadata: {
      'any' : [const import_3.Field()]
    },
    setterMetadata: {
      'any' : [const import_3.Field()]
    },
    constructorMetadata: {
    },
    createModel: (List args, Map<String, dynamic> namedArgs) => new import_2.GenericType<int>()), new import_0.ConcreteType<import_2.GenericType<import_2.IndirectType>>().type: new StaticFieldMapper<import_2.GenericType<import_2.IndirectType>>(
    positionalArgs: [],
    namedArgs: [],
    getters: {
      'any' : (import_2.GenericType<import_2.IndirectType> o) => o.any
    },
    setters: {
      'any' : (import_2.GenericType<import_2.IndirectType> o, import_2.IndirectType v) {o.any = v;}
    },
    types: {
      'any': import_2.IndirectType
    },
    constructorTypes: {
    },
    getterFields: {
      'any' : const import_3.Field()
    },
    setterFields: {
      'any' : const import_3.Field()
    },
    constructorFields: {
    },
    getterMetadata: {
      'any' : [const import_3.Field()]
    },
    setterMetadata: {
      'any' : [const import_3.Field()]
    },
    constructorMetadata: {
    },
    createModel: (List args, Map<String, dynamic> namedArgs) => new import_2.GenericType<import_2.IndirectType>()), import_2.GenericReified: new StaticFieldMapper<import_2.GenericReified>(
    positionalArgs: [],
    namedArgs: [],
    getters: {
      'any' : (import_2.GenericReified o) => o.any
    },
    setters: {
      'any' : (import_2.GenericReified o, import_2.Foo v) {o.any = v;}
    },
    types: {
      'any': import_2.Foo
    },
    constructorTypes: {
    },
    getterFields: {
      'any' : const import_3.Field()
    },
    setterFields: {
      'any' : const import_3.Field()
    },
    constructorFields: {
    },
    getterMetadata: {
      'any' : [const import_3.Field()]
    },
    setterMetadata: {
      'any' : [const import_3.Field()]
    },
    constructorMetadata: {
    },
    createModel: (List args, Map<String, dynamic> namedArgs) => new import_2.GenericReified()), import_2.GetterAndSetter: new StaticFieldMapper<import_2.GetterAndSetter>(
    positionalArgs: [],
    namedArgs: [],
    getters: {
      'foo' : (import_2.GetterAndSetter o) => o.foo
    },
    setters: {
      'foo' : (import_2.GetterAndSetter o, String v) {o.foo = v;}
    },
    types: {
      'foo': String
    },
    constructorTypes: {
    },
    getterFields: {
      'foo' : const import_3.Field()
    },
    setterFields: {
      'foo' : const import_3.Field()
    },
    constructorFields: {
    },
    getterMetadata: {
      'foo' : [const import_3.Field()]
    },
    setterMetadata: {
      'foo' : [const import_3.Field()]
    },
    constructorMetadata: {
    },
    createModel: (List args, Map<String, dynamic> namedArgs) => new import_2.GetterAndSetter()), import_2.FinalField: new StaticFieldMapper<import_2.FinalField>(
    positionalArgs: ['foo'],
    namedArgs: [],
    getters: {
      'foo' : (import_2.FinalField o) => o.foo
    },
    setters: {
    },
    types: {
      'foo': String
    },
    constructorTypes: {
      'foo': String
    },
    getterFields: {
      'foo' : const import_3.Field()
    },
    setterFields: {
    },
    constructorFields: {
      'foo' : const import_3.Field()
    },
    getterMetadata: {
      'foo' : [const import_3.Field()]
    },
    setterMetadata: {
    },
    constructorMetadata: {
      'foo' : [const import_3.Field()]
    },
    createModel: (List args, Map<String, dynamic> namedArgs) => new import_2.FinalField(args[0])), import_2.ExtendedField: new StaticFieldMapper<import_2.ExtendedField>(
    positionalArgs: [],
    namedArgs: [],
    getters: {
      'foo' : (import_2.ExtendedField o) => o.foo
    },
    setters: {
      'foo' : (import_2.ExtendedField o, int v) {o.foo = v;}
    },
    types: {
      'foo': int
    },
    constructorTypes: {
    },
    getterFields: {
      'foo' : const import_2.FieldInheritance('noValue')
    },
    setterFields: {
      'foo' : const import_2.FieldInheritance('noValue')
    },
    constructorFields: {
    },
    getterMetadata: {
      'foo' : [const import_2.FieldInheritance('noValue')]
    },
    setterMetadata: {
      'foo' : [const import_2.FieldInheritance('noValue')]
    },
    constructorMetadata: {
    },
    createModel: (List args, Map<String, dynamic> namedArgs) => new import_2.ExtendedField()), import_2.IndirectType: new StaticFieldMapper<import_2.IndirectType>(
    positionalArgs: [],
    namedArgs: [],
    getters: {
      'id' : (import_2.IndirectType o) => o.id
    },
    setters: {
      'id' : (import_2.IndirectType o, int v) {o.id = v;}
    },
    types: {
      'id': int
    },
    constructorTypes: {
    },
    getterFields: {
      'id' : const import_3.Field()
    },
    setterFields: {
      'id' : const import_3.Field()
    },
    constructorFields: {
    },
    getterMetadata: {
      'id' : [const import_3.Field()]
    },
    setterMetadata: {
      'id' : [const import_3.Field()]
    },
    constructorMetadata: {
    },
    createModel: (List args, Map<String, dynamic> namedArgs) => new import_2.IndirectType()), import_3.OpaqueMap: new StaticNotEncodableMapper<import_3.OpaqueMap>(), import_3.OpaqueList: new StaticNotEncodableMapper<import_3.OpaqueList>(), DateTime: new StaticNotEncodableMapper<DateTime>(), int: new StaticNotEncodableMapper<int>(), new import_0.ConcreteType<List<int>>().type: new StaticListMapper<int>(), new import_0.ConcreteType<List<String>>().type: new StaticListMapper<String>(), new import_0.ConcreteType<List<List<String>>>().type: new StaticListMapper<List<String>>(), new import_0.ConcreteType<List<dynamic>>().type: new StaticListMapper<dynamic>(), new import_0.ConcreteType<Map<String,num>>().type: new StaticMapMapper<num>(), new import_0.ConcreteType<Map<String,import_2.Foo>>().type: new StaticMapMapper<import_2.Foo>(), new import_0.ConcreteType<Map<dynamic,dynamic>>().type: new StaticMapMapper<dynamic>(), num: new StaticNotEncodableMapper<num>(), String: new StaticNotEncodableMapper<String>(), new import_0.ConcreteType<import_4.OtherGenericType<String>>().type: new StaticFieldMapper<import_4.OtherGenericType<String>>(
    positionalArgs: [],
    namedArgs: [],
    getters: {
      'any' : (import_4.OtherGenericType<String> o) => o.any
    },
    setters: {
      'any' : (import_4.OtherGenericType<String> o, String v) {o.any = v;}
    },
    types: {
      'any': String
    },
    constructorTypes: {
    },
    getterFields: {
      'any' : const import_3.Field()
    },
    setterFields: {
      'any' : const import_3.Field()
    },
    constructorFields: {
    },
    getterMetadata: {
      'any' : [const import_3.Field()]
    },
    setterMetadata: {
      'any' : [const import_3.Field()]
    },
    constructorMetadata: {
    },
    createModel: (List args, Map<String, dynamic> namedArgs) => new import_4.OtherGenericType<String>()), new import_0.ConcreteType<import_4.OtherGenericType<dynamic>>().type: new StaticFieldMapper<import_4.OtherGenericType<dynamic>>(
    positionalArgs: [],
    namedArgs: [],
    getters: {
      'any' : (import_4.OtherGenericType<dynamic> o) => o.any
    },
    setters: {
      'any' : (import_4.OtherGenericType<dynamic> o, dynamic v) {o.any = v;}
    },
    types: {
      'any': dynamic
    },
    constructorTypes: {
    },
    getterFields: {
      'any' : const import_3.Field()
    },
    setterFields: {
      'any' : const import_3.Field()
    },
    constructorFields: {
    },
    getterMetadata: {
      'any' : [const import_3.Field()]
    },
    setterMetadata: {
      'any' : [const import_3.Field()]
    },
    constructorMetadata: {
    },
    createModel: (List args, Map<String, dynamic> namedArgs) => new import_4.OtherGenericType<dynamic>())};