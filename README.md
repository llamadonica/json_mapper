# json_mapper

A slightly improved JSON mapper for Dart

## Explanation

This is a json mapper for Dart derived largely from `redstone_mapper`. It's designed to take care of
several issues with `redstone_mapper`. It contains both a dynamic (reflection-based), and static
mapper so it's suitable for any environment.

* `redstone_mapper` depends on `redstone` which pulls in a bunch of old versions of 
  packages and was generally poorly decoupled from the actual redstone-specific code.
* `redstone_mapper` can't handle generic classes very well.
* `redstone_mapper` makes it more difficult than necessary to get "raw" metadata.
  I've tried to make getting setters, constructors, and getters as easy as possible.
* I'm making an effort to create unit tests.
  
## Example

    import 'package:json_mapper/mapper_factory.dart';
    import 'package:json_mapper/metadata.dart';
    import 'package:json_mapper/json_mapper.dart';
    
    class ThisIsMappable extends Object with Encodable<ThisIsMappable> {
      @Field(model: '_id') String id;
      @Field() String firstName;
    }
    
    main() {
      bootstrapMapper();
      final valueToEncode = new ThisIsMappable()
          ..id = 'foo'
          ..firstName = 'bar';
      final encodedValue = valueToEncode.encode();
      final decoder = new StaticMapper<ThisIsMappable>();
      final decodedValue = decoder.decode(encodedValue);
    }
    
    
