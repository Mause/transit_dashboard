// ignore_for_file: avoid_print

import 'dart:convert' show JsonEncoder;

import 'package:chopper/chopper.dart'
    show ChopperClient, ChopperService, Request;
import 'package:intl/intl.dart';
import 'package:logger/logger.dart' as logger;
import 'package:logging/logging.dart' show Logger, Level;
import 'package:timezone/standalone.dart' as tz;

import 'generated_code/journey_planner.swagger.dart'
    show Format, JourneyPlanner, RealTimeInfo, Stop, StopTimetableResponse, Trip;
import 'journey_planner_service.dart' show Location, nearbyStops;
import 'pair.dart' show Pair;

var json = const JsonEncoder.withIndent('  ');

Future<void> main() async {
  await tz.initializeTimeZone();
  var perth = tz.getLocation('Australia/Perth');

  Logger.root.level = Level.ALL; // defaults to Level.INFO
  var pretty = logger.Logger();
  Logger.root.onRecord
      .listen((record) => pretty.log(logger.Level.info, record.message));

  var location = Location(-31.951548099520902, 115.85798556027436);

  var apiKey = 'eac7a147-0831-4fcf-8fa8-a5e8ffcfa039';
  var stops = await nearbyStops(apiKey, location);

  JourneyPlanner client = getClient(
      JourneyPlanner.create,
      // "http://au-journeyplanner.silverrailtech.com/journeyplannerservice/v2/REST",
      "http://realtime.transperth.info/SJP/StopTimetableService.svc/",
      // apiKey
      "ad89905f-d5a7-487f-a876-db39092c6ee0"
  );

  Set<Pair<Stop, Trip>> nearbyBuses = (await Future.wait(
      stops.map((stop) => getStopTimetable(client, stop.transitStop.code))))
      .where((element) => element.trips != null)
      .expand((element) =>
      element.trips!.map((e) => Pair.of(element.requestedStop!, e)))
      .where((element) => getRealtime(element.right.realTimeInfo) != null)
      .toSet();

  print(json.convert({
    'closest': nearbyBuses.map((e) => e.left.description).toSet().toList()
  }));
  var nearbyBus = nearbyBuses.first;

  var realTimeInfo = nearbyBus.right.realTimeInfo!;
  String? arrivalTime = getRealtime(realTimeInfo);

  assert(arrivalTime != null, "Arrival time must exist");

  var now = tz.TZDateTime.now(perth);
  var arrivalDateTime = toDateTime(now, arrivalTime!);
  print({
    "now": now,
    "realTimeInfo": realTimeInfo.toJson(),
    "arrivalDateTime": arrivalDateTime
  });

  createNotification(
      nearbyBus.left.description!,
      nearbyBus.right.summary!.routeCode! +
          ' ' +
          nearbyBus.right.summary!.headsign!,
      now.difference(arrivalDateTime));
}

String? getRealtime(RealTimeInfo? realTimeInfo) {
  return realTimeInfo == null ? null : realTimeInfo.estimatedArrivalTime == null
      ? realTimeInfo.actualArrivalTime
      : null;
}

T getClient<T extends ChopperService>(
    T Function() create, String baseUrl, String apiKey) {
  var baseClient = create();
  return ChopperClient(
      services: [baseClient],
      converter: baseClient.client.converter,
      interceptors: [
            (Request request) => Request(
            request.method, request.url, request.baseUrl,
            parameters: request.parameters
              ..putIfAbsent('ApiKey', () => apiKey))
      ],
      baseUrl: baseUrl)
      .getService<T>();
}

DateTime toDateTime(tz.TZDateTime now, String s) {
  var parts = s.split(':').map((e) => int.parse(e)).toList();
  return tz.TZDateTime(
      now.location, now.year, now.month, now.day, parts[0], parts[1], parts[2]);
}

void createNotification(String description, String routeCode, Duration delta) {
  print({"description": description, "routeCode": routeCode, "delta": delta});
}

Future<StopTimetableResponse> getStopTimetable(
    JourneyPlanner client, String stopNumber) async {
  var perth = tz.getLocation('Australia/Perth');

  var time = DateFormat('yyyy-MM-ddTHH:mm').format(tz.TZDateTime.now(perth));

  return (await client.dataSetsDatasetStopTimetableGet(
      dataset: 'PerthRestricted',
      stopUID: "PerthRestricted:$stopNumber",
      isRealTimeChecked: true,
      returnNotes: true,
      time: time,
      format: Format.json))
      .body!;
}
