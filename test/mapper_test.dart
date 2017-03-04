import 'package:json_mapper/mapper_factory.dart';
import 'package:json_mapper/json_mapper.dart';
import 'package:json_mapper/metadata.dart';
import 'package:test/test.dart';
import 'src/aux.dart';


main() {
  group('Mapper', () {
    setUp(() {
      bootstrapMapper();
    });
    test('can encode Lists', () {
      expect(encode([1, 2, 3, 4, 5]), equals([1, 2, 3, 4, 5]));
    });
    test('can encode ints', () {
      expect(encode(1), equals(1));
    });
    test('can encode Strings', () {
      expect(encode('foo'), equals('foo'));
    });
    test('can encode Maps', () {
      expect(encode({'a': 1, 'b': 'foo', 'c': 12.345}),
          equals({'a': 1, 'b': 'foo', 'c': 12.345}));
    });
    test('can encode DateTimes', () {
      expect(encode(new DateTime.fromMillisecondsSinceEpoch(3200000000000)),
          equals('2071-05-27T17:53:20.000'));
    });

    test('can decode Lists', () {
      expect(decode([1, 2, 3, 4, 5], new ConcreteType<List<int>>()),
          equals([1, 2, 3, 4, 5]));
    });
    test('can decode ints', () {
      expect(decode(1, new ConcreteType<int>()), equals(1));
    });
    test('can decode Strings', () {
      expect(decode('foo', new ConcreteType<String>()), equals('foo'));
    });
    test('can decode Maps', () {
      expect(
          decode({'a': 1, 'b': 12, 'c': 12.345},
              new ConcreteType<Map<String, num>>()),
          equals({'a': 1, 'b': 12, 'c': 12.345}));
    });
    test('can decode DateTimes', () {
      expect(
          decode/*<DateTime>*/('2071-05-27T17:53:20.000', new ConcreteType<DateTime>())
              .millisecondsSinceEpoch,
          equals(3200000000000));
    });

    test('can encode classes with @Field annotations', () {
      expect(
          encode(new Foo()
            ..foo = "foo"
            ..bar = 12
            ..buzz = ['buzz', 'buzzz']),
          equals({
            'foo': 'foo',
            'bar': 12,
            'buzz': ['buzz', 'buzzz']
          }));
    });
    test('can decode classes with @Field annotations', () {
      expect(
          encode(decode/*<Foo>*/({
            'foo': 'foo',
            'bar': 12,
            'buzz': ['buzz', 'buzzz']
          }, new ConcreteType<Foo>())), equals({
        'foo': 'foo',
        'bar': 12,
        'buzz': ['buzz', 'buzzz']
      }));
    });
    test('can encode nested classes', () {
      var originalType = new NestedType()
        ..id = '12345'
        ..foos = {'foo1' : new Foo()
          ..buzz = ['bar', 'bat']
          ..bar = 5
          ..foo = 'fooz'
        };
      expect(encode(originalType), equals({
        '_id': '12345',
        'Foos': {'foo1': {'foo': 'fooz', 'bar': 5, 'buzz': ['bar', 'bat']}}
      }));
    });
    test('can decode nested classes', () {
      expect(encode(decode({
        '_id': '12345',
        'Foos': {'foo1': {'foo': 'fooz', 'bar': 5, 'buzz': ['bar', 'bat']}}
      }, new ConcreteType<NestedType>())), equals({
        '_id': '12345',
        'Foos': {'foo1': {'foo': 'fooz', 'bar': 5, 'buzz': ['bar', 'bat']}}
      }));
    });
    test('can encode classes with generic arguments', () {
      var originalType = new GenericType<Foo>()
        ..any = (new Foo()
          ..buzz = ['bar', 'bat']
          ..bar = 5
          ..foo = 'fooz')
      ;
      expect(encode(originalType), equals({
        'any': {'foo': 'fooz', 'bar': 5, 'buzz': ['bar', 'bat']}
      }));
    });
    test('can decode classes with generic arguments', () {
      var originalType = new GenericType<Foo>()
        ..any = (new Foo()
          ..buzz = ['bar', 'bat']
          ..bar = 5
          ..foo = 'fooz')
      ;
      expect(encode(decode(encode(originalType), new ConcreteType<GenericType<Foo>>())), equals({
        'any': {'foo': 'fooz', 'bar': 5, 'buzz': ['bar', 'bat']}
      }));
    });
    test('can encode classes with generic argument T when T is dynamic', () {
      var originalType = new GenericType()
        ..any = (new Foo()
          ..buzz = ['bar', 'bat']
          ..bar = 5
          ..foo = 'fooz')
      ;
      expect(encode(originalType), equals({
        'any': {'foo': 'fooz', 'bar': 5, 'buzz': ['bar', 'bat']}
      }));
    });
    test('fails when decoding classes with generic argument T when T is dynamic', () {
      var originalType = new GenericType()
        ..any = (new Foo()
          ..buzz = ['bar', 'bat']
          ..bar = 5
          ..foo = 'fooz')
      ;
      expect(() => encode(decode(encode(originalType), new ConcreteType<GenericType>())), throws);
    });
    test('succeeds when decoding classes with generic argument T when T is dynamic but its value is null', () {
      var originalType = new GenericType()
        ..any = null;
      expect(encode(decode(encode(originalType), new ConcreteType<GenericType>())), equals({}));
    });
    test('can encode classes that inherit from generics', () {
      var originalType = new GenericReified()
        ..any = (new Foo()
          ..buzz = ['bar', 'bat']
          ..bar = 5
          ..foo = 'fooz')
      ;
      expect(encode(originalType), equals({
        'any': {'foo': 'fooz', 'bar': 5, 'buzz': ['bar', 'bat']}
      }));
    });
    test('can decode classes that inherit from generics', () {
      var originalType = new GenericReified()
        ..any = (new Foo()
          ..buzz = ['bar', 'bat']
          ..bar = 5
          ..foo = 'fooz')
      ;
      expect(encode(decode(encode(originalType), new ConcreteType<GenericReified>())), equals({
        'any': {'foo': 'fooz', 'bar': 5, 'buzz': ['bar', 'bat']}
      }));
    });
    test('can encode using annotations on getters', () {
      var originalType = new GetterAndSetter()..foo = 'bar';
      expect(encode(originalType), equals({'foo':'bar'}));
    });
    test('can encode using annotations on setters', () {
      var originalType = new GetterAndSetter()..foo = 'bar';
      var newType = decode/*<GetterAndSetter>*/(encode(originalType), new ConcreteType<GetterAndSetter>());
      expect(newType.foo, equals('bar'));
    });
    test('can encode final fields', () {
      var originalType = new FinalField('bar');
      expect(encode(originalType), equals({'foo':'bar'}));
    });
    test('can initialize objects using @Field annotations on constructor arguments.', () {
      var finalType = decode/*<FinalField>*/({'foo':'bar'}, new ConcreteType<FinalField>());
      expect(finalType.foo, equals('bar'));
    });
    test('@Field works when inherited', () {
      var originalType = new ExtendedField()..foo=123;
      expect(encode(originalType), equals({'_id': 123}));
    });
    test('decoding works correctly in loaded libraries', () {
      expect(decodeRemote({'any':'Foo'}).any, equals('Foo'));
    });
    test('inheriting ConcreteType works', () {
      var originalType = new GenericType<int>()
        ..any = 4
      ;
      expect(encode(decode(encode(originalType), new ConcreteTypeGenericTypeInt())), equals({
        'any': 4
      }));
    });
    test('inheriting ConcreteType works even when using generic parameters', () {
      var originalType = <String>['foo', 'bar'];
      expect(encode(decode(encode(originalType), new ConcreteTypeSub<String>())), equals(['foo', 'bar']));
    });
    test('inheriting ConcreteType works even when using complex generic parameters', () {
      var originalType = <List<String>>[<String>['foo', 'bar'],<String>['bat']];
      expect(encode(decode(encode(originalType), new ConcreteTypeSubSub<String>())), equals([['foo', 'bar'],['bat']]));
    });
    test('delegates to ConcreteType work', () {
      var originalType = <List<String>>[<String>['foo', 'bar'],<String>['bat']];
      expect(encode(decode(encode(originalType), new ConcreteTypeSubExpander<String>().delegate)), equals([['foo', 'bar'],['bat']]));
    });
    test('can handle indirect types', () {
      var originalType = new GenericType<IndirectType>()..any = (new IndirectType()..id=1);
      expect(encode(decode(encode(originalType), new ConcreteType<GenericType<IndirectType>>())) , equals({'any':{'id':1}}));
    });
    test('Can encode opaque maps', () {
      var originalType = new OpaqueMap({'test': 1, 'This':[1,2,3], 'Something': {'a': 4.5}});
      expect(encode(originalType), equals({'test': 1, 'This':[1,2,3], 'Something': {'a': 4.5}}));
    });
    test('Can decode opaque maps', () {
      expect(decode({'test': 1, 'This':[1,2,3], 'Something': {'a': 4.5}}, new ConcreteType<OpaqueMap>()).delegate, equals({'test': 1, 'This':[1,2,3], 'Something': {'a': 4.5}}));
    });
    test('Can encode opaque lists', () {
      var originalType = new OpaqueList(['a',1.5, {'a':'foo'}]);
      expect(encode(originalType), equals(['a',1.5, {'a':'foo'}]));
    });
    test('Can decode opaque lists', () {
      expect(decode(['a',1.5, {'a':'foo'}], new ConcreteType<OpaqueList>()).delegate, equals(['a',1.5, {'a':'foo'}]));
    });

  });
}

class Foo {
  @Field()
  String foo;
  @Field()
  int bar;
  @Field()
  List<String> buzz;
}

class NestedType {
  @Field(model: '_id') String id;
  @Field(model: 'Foos') Map<String, Foo> foos;
}

class GenericType<T> {
  @Field() T any;
}

class GenericReified extends GenericType<Foo> {
}

class GetterAndSetter {
  String _foo;
  @Field() String get foo => _foo;
  @Field() void set foo(String value) {
    _foo = value;
  }
}

class FinalField {
  @Field()
  final String foo;

  FinalField(@Field() this.foo);
}

class ExtendedField {
  @FieldInheritance('noValue') int foo;
}

class FieldInheritance extends Field {
  final String notUsed;
  const FieldInheritance(this.notUsed) : super(model: '_id');
}

class ConcreteTypeGenericTypeInt extends ConcreteType<GenericType<int>> {}

class ConcreteTypeExpander<T1> {
  final ConcreteType<List<T1>> delegate = new ConcreteType<List<T1>>();
}

class ConcreteTypeSub<T2> extends ConcreteType<List<T2>> {}

class ConcreteTypeSubExpander<T3> {
  final ConcreteTypeSub<List<T3>> delegate = new ConcreteTypeSub<List<T3>>();
}

class ConcreteTypeSubSub<T4> extends ConcreteTypeSub<List<T4>> {}

class ConcreteTypeSubSubExpander<T5> {
  final ConcreteTypeSubSub<List<T5>> delegate = new ConcreteTypeSubSub<List<T5>>();
}

class IndirectType {
  @Field() int id;
}