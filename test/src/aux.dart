import 'package:json_mapper/json_mapper.dart';
import 'package:json_mapper/metadata.dart';

// ignore: public_member_api_docs
class OtherGenericType<T> {
  // ignore: public_member_api_docs
  @Field()
  T any;
}

// ignore: public_member_api_docs
OtherGenericType<String> decodeRemote(Map<String, dynamic> value) =>
    decode(value, new ConcreteType<OtherGenericType<String>>());
