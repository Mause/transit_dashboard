import 'dart:convert' show JsonEncoder;

import 'package:chopper/chopper.dart' show ChopperClient, Request;
import 'package:timezone/standalone.dart' as tz;
import 'package:logging/logging.dart' show Logger, Level;
import 'package:logger/logger.dart' as logger;

import 'generated_code/journey_planner.swagger.dart'
    show Format, JourneyPlanner, Stop, StopTimetableResponse, Trip;
import 'journey_planner_service.dart' show Location, nearbyStops;
import 'pair.dart' show Pair;

var json = JsonEncoder.withIndent('  ');

Future<void> main() async {
  await tz.initializeTimeZone();
  var perth = tz.getLocation('Australia/Perth');

  Logger.root.level = Level.ALL; // defaults to Level.INFO
  var pretty = logger.Logger();
  Logger.root.onRecord
      .listen((record) => pretty.log(logger.Level.info, record));

  var location = Location(-31.951548099520902, 115.85798556027436);

  print('apiKey: ' + String.fromEnvironment("API_KEY"));
  var apiKey =
  bool.hasEnvironment("API_KEY") ? String.fromEnvironment("API_KEY") : null;
  var stops = await nearbyStops(apiKey!, location);

  Set<Pair<Stop, Trip>> nearbyBuses = (await Future.wait(
      stops.map((stop) => getStopTimetable(stop.transitStop.code))))
      .where((element) => element.trips != null)
      .expand((element) =>
      element.trips!.map((e) => Pair.of(element.requestedStop, e)))
      .toSet();

  print(json.convert({
    'closest': nearbyBuses.map((e) => e.left.description).toSet().toList()
  }));
  var nearbyBus = nearbyBuses.first;

  var realTimeInfo = nearbyBus.right.realTimeInfo!;
  var arrivalTime = realTimeInfo.estimatedArrivalTime == null
      ? realTimeInfo.actualArrivalTime
      : null;

  assert(arrivalTime != null, "Arrival time must exist");

  var now = tz.TZDateTime.now(perth);
  var arrivalDateTime = toDateTime(now, arrivalTime!);
  print({
    "now": now,
    "realTimeInfo": realTimeInfo.toJson(),
    "arrivalDateTime": arrivalDateTime
  });

  createNotification(
      nearbyBus.left.description,
      nearbyBus.right.summary.routeCode +
          ' ' +
          nearbyBus.right.summary.headsign,
      now.difference(arrivalDateTime));
}

DateTime toDateTime(tz.TZDateTime now, String s) {
  var parts = s.split(':').map((e) => int.parse(e)).toList();
  return tz.TZDateTime(
      now.location, now.year, now.month, now.day, parts[0], parts[1], parts[2]);
}

void createNotification(String description, String routeCode, Duration delta) {
  print({"description": description, "routeCode": routeCode, "delta": delta});
}

Future<StopTimetableResponse> getStopTimetable(String stopNumber) async {
  var perth = tz.getLocation('Australia/Perth');

  var client = ChopperClient(services: [
    JourneyPlanner.create()
  ], interceptors: [
        (Request request) => Request(
        request.method,
        request.url + "&apiKey=ad89905f-d5a7-487f-a876-db39092c6ee0",
        request.baseUrl)
  ], baseUrl: "http://au-journeyplanner.silverrailtech.com/journeyplannerservice/v2/REST")
      .getService<JourneyPlanner>();

  return (await client.dataSetsDatasetStopTimetableGet(
      dataset: 'PerthRestricted',
      stopUID: "PerthRestricted:$stopNumber",
      isRealTimeChecked: true,
      returnNotes: true,
      time: tz.TZDateTime.now(perth).toIso8601String(),
      format: Format.json))
      .body!;
}

Future<List<String>> getRoutesForStop(String stopNumber) async {
  var routes = <String>[];
  var res = await getStopTimetable(stopNumber);
  for (var trip in res.trips!) {
    if (!routes.contains(trip.summary.routeCode)) {
      routes.add(trip.summary.routeCode);
    }
  }
  return routes;
}
