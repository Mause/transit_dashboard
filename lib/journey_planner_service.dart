import 'package:sentry/sentry.dart';
import 'dart:core';
import 'package:json_annotation/json_annotation.dart';
import 'dart:convert';

part 'journey_planner_service.g.dart';

var client = SentryHttpClient(captureFailedRequests: true);

Future<List<NearbyTransitStop>> nearbyStops(String apikey, Location location) async {
  var res = await client.get(Uri.http(
      "au-journeyplanner.silverrailtech.com",
      "journeyplannerservice/v2/REST/Datasets/PerthRestricted/NearbyTransitStops",
      {
        "ApiKey": apikey,
        "format": "json",
        "GeoCoordinate": "${location.latitude},${location.longitude}"
      }));

  return Response.fromJson(jsonDecode(res.body)).transitStopPaths;
}

@JsonSerializable()
class NearbyTransitStop {
  num distance;
  TransitStop transitStop;

  NearbyTransitStop(this.distance, this.transitStop);

  factory NearbyTransitStop.fromJson(Map<String, dynamic> json) =>
      _$NearbyTransitStopFromJson(json);

  Map<String, dynamic> toJson() => _$NearbyTransitStopToJson(this);
}

@JsonSerializable()
class TransitStop {
  String position;
  String code;
  String description;

  TransitStop(this.position, this.code, this.description);

  factory TransitStop.fromJson(Map<String, dynamic> json) =>
      _$TransitStopFromJson(json);

  Map<String, dynamic> toJson() => _$TransitStopToJson(this);
}

@JsonSerializable()
class Response {
  List<NearbyTransitStop> transitStopPaths;

  Response(this.transitStopPaths);

  factory RealTimeInfo.fromJson(Map<String, dynamic> json) =>
      _$RealTimeInfoFromJson(json);

  Map<String, dynamic> toJson() => _$RealTimeInfoToJson(this);
}

class Location {
  num latitude;
  num longitude;
  Location(this.latitude, this.longitude);
}
