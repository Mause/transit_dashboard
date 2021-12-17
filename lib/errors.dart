import 'dart:convert' show jsonDecode;

import 'package:http/http.dart' show Response;
import 'package:logging/logging.dart' show Logger;
import 'package:transit_dashboard/generated_code/journey_planner.swagger.dart';

var logger = Logger("errors");

T errorOrResult<T>(
    Response res, T Function(Map<String, dynamic> json) fromJson) {
  var body = jsonDecode(res.body);
  logger.info({
    "statusCode": res.statusCode,
    "reasonPhrase": res.reasonPhrase,
    "body": body['Status']
  });
  var error = Error.fromJson(body);
  if (error.status!.severity == 2) {
    throw Exception(error.status!.details![0].message);
  }

  return fromJson(body);
}
