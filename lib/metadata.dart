library json_mapper_metadata;

import 'package:json_mapper/src/abstract_mapper_factory.dart';
import 'package:json_mapper/json_mapper.dart' as global;
import 'package:quiver/collection.dart';

class Field {
  final String model;
  const Field({this.model});
}

class ConcreteType<T> {
  final Type type = T;
  ConcreteType();
}

class OpaqueMap extends DelegatingMap<String, dynamic> {
  @override
  final Map<String,dynamic> delegate;

  OpaqueMap(this.delegate);
}
class OpaqueList extends DelegatingList<dynamic> {
  @override
  final List<dynamic> delegate;

  OpaqueList(this.delegate);
}

class Encodable<T extends Encodable<T>> {
  final ConcreteType<T> _concreteType = new ConcreteType<T>();
  encode() => global.encode(this);
  encodeJson() => global.encodeJson(this);
}

class StaticMapper<T extends Encodable<T>> {
  final ConcreteType<T> _concreteType = new ConcreteType<T>();
  decode(dynamic value) => global.decode(value, _concreteType);
  decodeJson(String value) => global.decodeJson(value, _concreteType);
  Mapper<T,dynamic> get mapper => global.getMapper(_concreteType);
}
