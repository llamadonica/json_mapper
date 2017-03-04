library dynamic_mapper_factory;

import 'dart:mirrors';

import 'dart:convert';

import 'package:json_mapper/src/abstract_mapper_factory.dart';
import 'package:json_mapper/json_mapper.dart';
import 'package:json_mapper/metadata.dart';
import 'package:json_mapper/src/builder_field_mapper.dart';

part 'src/dynamic_mapper.dart';

void bootstrapMapper() => configure(_dynamicMapper);
