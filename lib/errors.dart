import 'dart:async' show Future;
import 'dart:convert' show jsonDecode;

import 'package:http/http.dart' show Response;

import 'package:json_annotation/json_annotation.dart'
    show JsonSerializable, $checkedNew, $checkedConvert;

part 'errors.g.dart';

T errorOrResult<T>(Response res, T Function(dynamic json) fromJson) {
  var body = jsonDecode(res.body);
  print(body);
  if (res.statusCode != 200) {
    var status = Status.fromJson(body['Status']);
    throw Exception(status.details[0].message);;
  }

  return fromJson(body);
}

@JsonSerializable()
class Status {
  int severity;
  List<Detail> details;

  Status(this.severity, this.details);

  factory Status.fromJson(Map<String, dynamic> json) => _$StatusFromJson(json);

  Map<String, dynamic> toJson() => _$StatusToJson(this);
}

@JsonSerializable()
class Detail {
  int code;
  String message;

  Detail(this.code, this.message);

  factory Detail.fromJson(Map<String, dynamic> json) => _$DetailFromJson(json);

  Map<String, dynamic> toJson() => _$DetailToJson(this);
}
