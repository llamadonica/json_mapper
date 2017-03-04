import 'package:json_mapper/json_mapper.dart';
import 'package:json_mapper/metadata.dart';

class OtherGenericType<T> {
  @Field() T any;
}

OtherGenericType<String> decodeRemote(Map<String, dynamic> value) => decode(value, new ConcreteType<OtherGenericType<String>>());