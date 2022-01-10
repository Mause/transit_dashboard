import 'dart:convert' show jsonDecode, jsonEncode;

import 'package:logging/logging.dart' show Logger;

import 'generated_code/journey_planner.swagger.dart' show Stop, Trip;

var logger = Logger('background.dart');

class Job {
  Trip trip;
  Stop stop;

  Job(this.stop, this.trip);

  Map<String, dynamic> toJson() =>
      {"stop": jsonEncode(stop), "trip": jsonEncode(trip)};

  factory Job.fromJson(Map<String, dynamic> parts) => Job(
      Stop.fromJson(jsonDecode(parts['stop'])),
      Trip.fromJson(jsonDecode(parts['trip'])));
}

const SHOW_NOTIFICATION = 'showNotification';
