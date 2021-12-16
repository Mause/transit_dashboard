import 'dart:convert' show jsonDecode;

import 'package:http/http.dart' show Response;
import 'package:json_annotation/json_annotation.dart'
    show JsonSerializable, $checkedNew, $checkedConvert;
import 'package:logging/logging.dart' show Logger;

part 'errors.g.dart';

var logger = Logger("errors");

T errorOrResult<T>(
    Response res, T Function(Map<String, dynamic> json) fromJson) {
  var body = jsonDecode(res.body);
  logger.info({
    "statusCode": res.statusCode,
    "reasonPhrase": res.reasonPhrase,
    "body": body
  });
  if (res.statusCode != 200 || body['Status']['Severity'] == 2) {
    var status = Status.fromJson(body['Status']);
    throw Exception(status.details[0].message);
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
