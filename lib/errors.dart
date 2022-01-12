// ignore_for_file: avoid_dynamic_calls

import 'package:chopper/chopper.dart' show Response;
import 'package:logging/logging.dart' show Logger;

var logger = Logger("errors.dart");

T errorOrResult<T>(Response<T> res) {
  if (res.error != null) {
    throw Exception(res.error);
  }
  var status = (res.body! as dynamic).status!;
  var severity = status.severity;
  if (severity == 2) {
    throw Exception(status.details![0].message);
  } else if (severity == 1) {
    for (var warning in status.details!) {
      logger.warning(warning);
    }
  }

  return res.body!;
}
