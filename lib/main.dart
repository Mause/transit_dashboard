import 'package:sentry/sentry.dart' show SentryHttpClient;
import 'dart:core' show DateTime, Duration, Future, List, Map, String, Uri;
import 'package:json_annotation/json_annotation.dart' show JsonSerializable;
import 'dart:convert' show JsonEncoder, jsonDecode;
import 'package:timezone/standalone.dart' as tz;

import 'journey_planner_service.dart' show Location, nearbyStops;

part 'main.g.dart';

var client = SentryHttpClient(captureFailedRequests: true);
var json = JsonEncoder.withIndent('  ');

void main() async {
  await tz.initializeTimeZone();

  var location = Location(-31, 115);

  var stops = await nearbyStops("", location);

  var nearbyBuses = (
    await Future.wait(
      stops.map((stop) => getStopTimetable(stop.transitStop.code))
    )
  ).flatMap().toSet();

  var nearbyBus = nearbyBuses[0];

  createNotification(
    nearbyBus.requestedStop.description,
    nearbyBus.route.code,
    DateTime.now().difference(nearbyBus.realTimeInfo.estimatedArrivalTime)
  );
}

void createNotification(String description, String routeCode, Duration delta) {}

Future<Response> getStopTimetable(String stopNumber) {
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
