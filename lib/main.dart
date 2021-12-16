import 'dart:convert' show JsonEncoder, jsonDecode;

import 'package:json_annotation/json_annotation.dart'
    show JsonSerializable, $checkedConvert, $checkedNew;
import 'package:timezone/standalone.dart' as tz;
import 'package:logging/logging.dart' show Logger, Level;
import 'package:logger/logger.dart' as logger;

import 'client.dart' show client;
import 'journey_planner_service.dart' show Location, nearbyStops;
import 'pair.dart' show Pair;

part 'main.g.dart';

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
    "realTimeInfo": realTimeInfo,
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

Future<Response> getStopTimetable(String stopNumber) async {
  var perth = tz.getLocation('Australia/Perth');

  var r = await client.get(Uri.https(
    "realtime.transperth.info",
    "/SJP/StopTimetableService.svc/DataSets/PerthRestricted/StopTimetable",
    {
      "StopUID": "PerthRestricted:$stopNumber",
      "IsRealTimeChecked": "true",
      "ReturnNotes": "true",
      "Time": tz.TZDateTime.now(perth).toIso8601String(),
      "format": "json",
      "ApiKey": "ad89905f-d5a7-487f-a876-db39092c6ee0"
    },
  ));
  return Response.fromJson(jsonDecode(r.body));
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

@JsonSerializable()
class Response {
  List<Trip>? trips;
  Stop requestedStop;

  Response(this.trips, this.requestedStop);

  factory Response.fromJson(Map<String, dynamic> json) =>
      _$ResponseFromJson(json);

  Map<String, dynamic> toJson() => _$ResponseToJson(this);
}

@JsonSerializable()
class Stop {
  String description;

  Stop(this.description);

  factory Stop.fromJson(Map<String, dynamic> json) => _$StopFromJson(json);

  Map<String, dynamic> toJson() => _$StopToJson(this);
}

@JsonSerializable()
class Trip {
  RealTimeInfo? realTimeInfo;
  Summary summary;

  Trip(this.realTimeInfo, this.summary);

  factory Trip.fromJson(Map<String, dynamic> json) => _$TripFromJson(json);

  Map<String, dynamic> toJson() => _$TripToJson(this);
}

@JsonSerializable()
class Summary {
  String routeCode;
  String headsign;

  Summary(this.routeCode, this.headsign);

  factory Summary.fromJson(Map<String, dynamic> json) =>
      _$SummaryFromJson(json);

  Map<String, dynamic> toJson() => _$SummaryToJson(this);
}

@JsonSerializable()
class RealTimeInfo {
  String? estimatedArrivalTime;
  String? actualArrivalTime;

  RealTimeInfo(this.estimatedArrivalTime, this.actualArrivalTime);

  factory RealTimeInfo.fromJson(Map<String, dynamic> json) =>
      _$RealTimeInfoFromJson(json);

  Map<String, dynamic> toJson() => _$RealTimeInfoToJson(this);
}
