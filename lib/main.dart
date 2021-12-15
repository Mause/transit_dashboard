import 'dart:convert' show JsonEncoder, jsonDecode;

import 'package:json_annotation/json_annotation.dart' show JsonSerializable, $checkedConvert, $checkedNew;
import 'package:sentry/sentry.dart' show SentryHttpClient;
import 'package:timezone/standalone.dart' as tz;

import 'client.dart' show client;
import 'journey_planner_service.dart' show Location, nearbyStops;

part 'main.g.dart';

var json = JsonEncoder.withIndent('  ');

void main() async {
  await tz.initializeTimeZone();

  var location = Location(-31, 115);

  var stops = await nearbyStops("", location);

  Set<Pair<Stop, Trip>> nearbyBuses = (await Future.wait(
          stops.map((stop) => getStopTimetable(stop.transitStop.code))))
      .where((element) => element.trips != null)
      .expand((element) =>
          element.trips!.map((e) => Pair.of(element.requestedStop, e)))
      .toSet();

  var nearbyBus = nearbyBuses.first;

  createNotification(
      nearbyBus.left.description,
      nearbyBus.right.summary.routeCode + ' ' + nearbyBus.right.summary.headsign,
      DateTime.now().difference(
          toDateTime(nearbyBus.right.realTimeInfo!.estimatedArrivalTime!)));
}

DateTime toDateTime(String s) {
  var n = DateTime.now();
  var parts = s.split(':').map((e) => int.parse(e)).toList();
  return DateTime(n.year, n.month, n.day, parts[0], parts[1], parts[2]);
}

void createNotification(String description, String routeCode, Duration delta) {}

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
  for (var trip in res.trips) {
    if (!routes.contains(trip.summary.routeCode)) {
      routes.add(trip.summary.routeCode);
    }
  }
  return routes;
}

@JsonSerializable()
class Response {
  List<Trip> trips;
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
