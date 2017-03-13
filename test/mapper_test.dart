import 'package:json_mapper/mapper_factory.dart';
import 'package:json_mapper/json_mapper.dart';
import 'package:json_mapper/metadata.dart';
import 'package:test/test.dart';
import 'src/aux.dart';

void main() {
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
      expect(
          encode(
              new DateTime.fromMillisecondsSinceEpoch(3200000000000).toUtc()),
          equals('2071-05-28T00:53:20.000Z'));
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
          decode/*<DateTime>*/(
                  '2071-05-28T00:53:20.000Z', new ConcreteType<DateTime>())
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
          }, new ConcreteType<Foo>())),
          equals({
            'foo': 'foo',
            'bar': 12,
            'buzz': ['buzz', 'buzzz']
          }));
    });
    test('can encode nested classes', () {
      final originalType = new NestedType()
        ..id = '12345'
        ..foos = {
          'foo1': new Foo()
            ..buzz = ['bar', 'bat']
            ..bar = 5
            ..foo = 'fooz'
        };
      expect(
          encode(originalType),
          equals({
            '_id': '12345',
            'Foos': {
              'foo1': {
                'foo': 'fooz',
                'bar': 5,
                'buzz': ['bar', 'bat']
              }
            }
          }));
    });
    test('can decode nested classes', () {
      expect(
          encode(decode({
            '_id': '12345',
            'Foos': {
              'foo1': {
                'foo': 'fooz',
                'bar': 5,
                'buzz': ['bar', 'bat']
              }
            }
          }, new ConcreteType<NestedType>())),
          equals({
            '_id': '12345',
            'Foos': {
              'foo1': {
                'foo': 'fooz',
                'bar': 5,
                'buzz': ['bar', 'bat']
              }
            }
          }));
    });
    test('can encode classes with generic arguments', () {
      final originalType = new GenericType<Foo>()
        ..any = (new Foo()
          ..buzz = ['bar', 'bat']
          ..bar = 5
          ..foo = 'fooz');
      expect(
          encode(originalType),
          equals({
            'any': {
              'foo': 'fooz',
              'bar': 5,
              'buzz': ['bar', 'bat']
            }
          }));
    });
    test('can decode classes with generic arguments', () {
      final originalType = new GenericType<Foo>()
        ..any = (new Foo()
          ..buzz = ['bar', 'bat']
          ..bar = 5
          ..foo = 'fooz');
      expect(
          encode(decode(
              encode(originalType), new ConcreteType<GenericType<Foo>>())),
          equals({
            'any': {
              'foo': 'fooz',
              'bar': 5,
              'buzz': ['bar', 'bat']
            }
          }));
    });
    test('can encode classes with generic argument T when T is dynamic', () {
      final originalType = new GenericType()
        ..any = (new Foo()
          ..buzz = ['bar', 'bat']
          ..bar = 5
          ..foo = 'fooz');
      expect(
          encode(originalType),
          equals({
            'any': {
              'foo': 'fooz',
              'bar': 5,
              'buzz': ['bar', 'bat']
            }
          }));
    });
    test(
        'fails when decoding classes with generic argument T when T is dynamic',
        () {
      final originalType = new GenericType()
        ..any = (new Foo()
          ..buzz = ['bar', 'bat']
          ..bar = 5
          ..foo = 'fooz');
      expect(
          () => encode(
              decode(encode(originalType), new ConcreteType<GenericType>())),
          throws);
    });
    test(
        'succeeds when decoding classes with generic argument T when T is dynamic but its value is null',
        () {
      final originalType = new GenericType()..any = null;
      expect(
          encode(decode(encode(originalType), new ConcreteType<GenericType>())),
          equals({}));
    });
    test('can encode classes that inherit from generics', () {
      final originalType = new GenericReified()
        ..any = (new Foo()
          ..buzz = ['bar', 'bat']
          ..bar = 5
          ..foo = 'fooz');
      expect(
          encode(originalType),
          equals({
            'any': {
              'foo': 'fooz',
              'bar': 5,
              'buzz': ['bar', 'bat']
            }
          }));
    });
    test('can decode classes that inherit from generics', () {
      final originalType = new GenericReified()
        ..any = (new Foo()
          ..buzz = ['bar', 'bat']
          ..bar = 5
          ..foo = 'fooz');
      expect(
          encode(
              decode(encode(originalType), new ConcreteType<GenericReified>())),
          equals({
            'any': {
              'foo': 'fooz',
              'bar': 5,
              'buzz': ['bar', 'bat']
            }
          }));
    });
    test('can encode using annotations on getters', () {
      final originalType = new GetterAndSetter()..foo = 'bar';
      expect(encode(originalType), equals({'foo': 'bar'}));
    });
    test('can encode using annotations on setters', () {
      final originalType = new GetterAndSetter()..foo = 'bar';
      final newType = decode/*<GetterAndSetter>*/(
          encode(originalType), new ConcreteType<GetterAndSetter>());
      expect(newType.foo, equals('bar'));
    });
    test('can encode final fields', () {
      final originalType = new FinalField('bar');
      expect(encode(originalType), equals({'foo': 'bar'}));
    });
    test(
        'can initialize objects using @Field annotations on constructor arguments.',
        () {
      final finalType = decode/*<FinalField>*/(
          {'foo': 'bar'}, new ConcreteType<FinalField>());
      expect(finalType.foo, equals('bar'));
    });
    test('@Field works when inherited', () {
      final originalType = new ExtendedField()..foo = 123;
      expect(encode(originalType), equals({'_id': 123}));
    });
    test('decoding works correctly in loaded libraries', () {
      expect(decodeRemote({'any': 'Foo'}).any, equals('Foo'));
    });
    test('inheriting ConcreteType works', () {
      final originalType = new GenericType<int>()..any = 4;
      expect(
          encode(decode(
              encode(originalType), new ConcreteType<GenericType<int>>())),
          equals({'any': 4}));
    });
    test('inheriting ConcreteType works even when using generic parameters',
        () {
      final originalType = <String>['foo', 'bar'];
      expect(
          encode(
              decode(encode(originalType), new ConcreteType<List<String>>())),
          equals(['foo', 'bar']));
    });
    test(
        'inheriting ConcreteType works even when using complex generic parameters',
        () {
      final originalType = <List<String>>[
        <String>['foo', 'bar'],
        <String>['bat']
      ];
      expect(
          encode(decode(
              encode(originalType), new ConcreteType<List<List<String>>>())),
          equals([
            ['foo', 'bar'],
            ['bat']
          ]));
    });
    test('delegates to ConcreteType work', () {
      final originalType = <List<String>>[
        <String>['foo', 'bar'],
        <String>['bat']
      ];
      expect(
          encode(decode(encode(originalType),
              new ConcreteTypeSubExpander<String>().delegate)),
          equals([
            ['foo', 'bar'],
            ['bat']
          ]));
    });
    test('can handle indirect types', () {
      final originalType = new GenericType<IndirectType>()
        ..any = (new IndirectType()..id = 1);
      expect(
          encode(decode(encode(originalType),
              new ConcreteType<GenericType<IndirectType>>())),
          equals({
            'any': {'id': 1}
          }));
    });
    test('Can encode opaque maps', () {
      final originalType = new OpaqueMap({
        'test': 1,
        'This': [1, 2, 3],
        'Something': {'a': 4.5}
      });
      expect(
          encode(originalType),
          equals({
            'test': 1,
            'This': [1, 2, 3],
            'Something': {'a': 4.5}
          }));
    });
    test('Can decode opaque maps', () {
      expect(
          decode({
            'test': 1,
            'This': [1, 2, 3],
            'Something': {'a': 4.5}
          }, new ConcreteType<OpaqueMap>())
              .delegate,
          equals({
            'test': 1,
            'This': [1, 2, 3],
            'Something': {'a': 4.5}
          }));
    });
    test('Can encode opaque lists', () {
      final originalType = new OpaqueList([
        'a',
        1.5,
        {'a': 'foo'}
      ]);
      expect(
          encode(originalType),
          equals([
            'a',
            1.5,
            {'a': 'foo'}
          ]));
    });
    test('Can decode opaque lists', () {
      expect(
          decode([
            'a',
            1.5,
            {'a': 'foo'}
          ], new ConcreteType<OpaqueList>())
              .delegate,
          equals([
            'a',
            1.5,
            {'a': 'foo'}
          ]));
    });
    test('Can decode objects with named constructors', () {
      var value =
          decode({'id': 'some_id'}, new ConcreteType<HasNamedConstructor>());
      expect(value.id, equals('some_id'));
    });
  });
}

// ignore: public_member_api_docs
class Foo {
  @Field()
  // ignore: public_member_api_docs
  String foo;
  @Field()
  // ignore: public_member_api_docs
  int bar;
  @Field()
  // ignore: public_member_api_docs
  List<String> buzz;
}

// ignore: public_member_api_docs
class NestedType {
  // ignore: public_member_api_docs
  @Field(model: '_id')
  String id;
  // ignore: public_member_api_docs
  @Field(model: 'Foos')
  Map<String, Foo> foos;
}

// ignore: public_member_api_docs
class GenericType<T> {
  // ignore: public_member_api_docs
  @Field()
  T any;
}

// ignore: public_member_api_docs
class GenericReified extends GenericType<Foo> {}

// ignore: public_member_api_docs
@Field()
class GetterAndSetter {
  String _foo;
  // ignore: unnecessary_getters_setters, public_member_api_docs
  @Field()
  String get foo => _foo;
  // ignore: unnecessary_getters_setters, public_member_api_docs
  @Field()
  void set foo(String value) {
    _foo = value;
  }
}

class HasNamedConstructor {
  @Field()
  final String id;
  HasNamedConstructor({this.id});
}

// ignore: public_member_api_docs
class FinalField {
  @Field()
  // ignore: public_member_api_docs
  final String foo;

  // ignore: public_member_api_docs
  FinalField(@Field() this.foo);
}

// ignore: public_member_api_docs
class ExtendedField {
  // ignore: public_member_api_docs
  @FieldInheritance('noValue')
  int foo;
}

// ignore: public_member_api_docs
class FieldInheritance extends Field {
  // ignore: public_member_api_docs
  final String notUsed;
  // ignore: public_member_api_docs
  const FieldInheritance(this.notUsed) : super(model: '_id');
}

// ignore: public_member_api_docs
class ConcreteTypeExpander<T1> {
  // ignore: public_member_api_docs
  final ConcreteType<List<T1>> delegate = new ConcreteType<List<T1>>();
}

// ignore: public_member_api_docs
class ConcreteTypeSubExpander<T3> {
  // ignore: public_member_api_docs
  final ConcreteType<List<List<T3>>> delegate =
      new ConcreteType<List<List<T3>>>();
}

// ignore: public_member_api_docs
class ConcreteTypeSubSubExpander<T5> {
  // ignore: public_member_api_docs
  final ConcreteType<List<List<List<T5>>>> delegate =
      new ConcreteType<List<List<List<T5>>>>();
}

// ignore: public_member_api_docs
class IndirectType {
  // ignore: public_member_api_docs
  @Field()
  int id;
}
