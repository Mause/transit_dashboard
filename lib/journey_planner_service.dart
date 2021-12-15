import 'dart:convert' show jsonDecode;

import 'package:json_annotation/json_annotation.dart'
    show JsonSerializable, $checkedNew, $checkedConvert;

import 'client.dart' show client;

part 'journey_planner_service.g.dart';

Future<List<NearbyTransitStop>> nearbyStops(
    String apikey, Location location) async {
  var res = await client.get(Uri.http(
      "au-journeyplanner.silverrailtech.com",
      "journeyplannerservice/v2/REST/Datasets/PerthRestricted/NearbyTransitStops",
      {
        "ApiKey": apikey,
        "format": "json",
        "GeoCoordinate": "${location.latitude},${location.longitude}"
      }));

  var body = jsonDecode(res.body);
  print(body);
  if (res.statusCode != 200) {
    var status = Status.fromJson(body['Status']);
    throw Exception(status.details[0].message);;
  }

  return NearbyStopsResponse.fromJson(body).transitStopPaths;
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
class NearbyStopsResponse {
  List<NearbyTransitStop> transitStopPaths;

  NearbyStopsResponse(this.transitStopPaths);

  factory NearbyStopsResponse.fromJson(Map<String, dynamic> json) =>
      _$NearbyStopsResponseFromJson(json);

  Map<String, dynamic> toJson() => _$NearbyStopsResponseToJson(this);
}

class Location {
  num latitude;
  num longitude;

  Location(this.latitude, this.longitude);
}

@JsonSerializable()
class Status {
  int severity;
  List<Detail> details;

  Status(this.severity, this.details);

  factory Status.fromJson(Map<String, dynamic> json) => _$StatusFromJson(json);

  Map<String, dynamic> toJson() => _$StatusToJson(this);
}

@JsonSerializable()
class Detail {
  int code;
  String message;

  Detail(this.code, this.message);

  factory Detail.fromJson(Map<String, dynamic> json) => _$DetailFromJson(json);

  Map<String, dynamic> toJson() => _$DetailToJson(this);
}
