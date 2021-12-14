import 'package:sentry/sentry.dart';
import 'dart:core';
import 'package:json_annotation/json_annotation.dart';
import 'dart:convert';
import 'package:timezone/standalone.dart' as tz;

part 'main.g.dart';

var client = SentryHttpClient(captureFailedRequests: true);

void main() async {
  await tz.initializeTimeZone();
  var perth = tz.getLocation('Australia/Perth');

  try {
    var r = await client.get(Uri.https(
      "realtime.transperth.info",
      "/SJP/StopTimetableService.svc/DataSets/PerthRestricted/StopTimetable",
      {
        "StopUID": "PerthRestricted:11706",
        "IsRealTimeChecked": "true",
        "ReturnNotes": "true",
        "Time": tz.TZDateTime.now(perth).toIso8601String(),
        "format": "json",
        "ApiKey": "ad89905f-d5a7-487f-a876-db39092c6ee0"
      },
    ));
    var body = jsonDecode(r.body);
    var res = Response.fromJson(body);
    print(jsonEncode(res));
    var routes = [];
    for (var trip in res.trips) {
      if (!routes.contains(trip.summary.routeCode)) {
        routes.add(trip.summary.routeCode);
      }
    }
    // print(jsonEncode(trips.toList()));
    print(routes);
  } finally {
    client.close();
  }
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

  factory Stop.fromJson(Map<String, dynamic> json) =>
      _$StopFromJson(json);

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
  Summary(this.routeCode);
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
