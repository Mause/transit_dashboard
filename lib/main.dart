import 'package:sentry/sentry.dart';
import 'dart:core';
import 'package:json_annotation/json_annotation.dart';
import 'dart:convert';

part 'main.g.dart';

var client = SentryHttpClient(captureFailedRequests: true);

void main() async {
  try {
    var r = await client.get(Uri.https(
      "realtime.transperth.info",
      "/SJP/StopTimetableService.svc/DataSets/PerthRestricted/StopTimetable",
      {
        "StopUID": "PerthRestricted:11706",
        "IsRealTimeChecked": "true",
        "ReturnNotes": "true",
        "Time": DateTime.now().toIso8601String(),
        "format": "json",
        "ApiKey": "ad89905f-d5a7-487f-a876-db39092c6ee0"
      },
    ));
    print(jsonEncode(Response.fromJson(jsonDecode(r.body)).trips.toList()));
  } finally {
    client.close();
  }
}

@JsonSerializable()
class Response {
  List<Trip> trips;

  Response(this.trips);

  factory Response.fromJson(Map<String, dynamic> json) =>
      _$ResponseFromJson(json);

  Map<String, dynamic> toJson() => _$ResponseToJson(this);
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
  RealTimeInfo();
  factory RealTimeInfo.fromJson(Map<String, dynamic> json) =>
      _$RealTimeInfoFromJson(json);

  Map<String, dynamic> toJson() => _$RealTimeInfoToJson(this);
}
