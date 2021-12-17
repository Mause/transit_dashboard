import 'package:chopper/chopper.dart' show Response;
import 'package:logging/logging.dart' show Logger;
import 'package:transit_dashboard/generated_code/journey_planner.swagger.dart'
    show Error;

var logger = Logger("errors.dart");

T errorOrResult<T extends Error>(Response<T> res) {
  var status = res.body!.status!;
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
