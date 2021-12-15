import 'package:json_annotation/json_annotation.dart'
    show JsonSerializable, $checkedNew, $checkedConvert;

import 'client.dart' show client;
import 'errors.dart' show errorOrResult;

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

  return errorOrResult<NearbyStopsResponse>(res, NearbyStopsResponse.fromJson).transitStopPaths;
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
