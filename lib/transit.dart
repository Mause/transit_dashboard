// ignore_for_file: avoid_print

import 'dart:convert' show JsonEncoder;

import 'package:chopper/chopper.dart'
    show ChopperClient, ChopperService, Request;
import 'package:intl/intl.dart';
import 'package:logging/logging.dart' show Logger;
import 'package:sentry_flutter/sentry_flutter.dart' show SentryHttpClient;
import 'package:timezone/standalone.dart' as tz;
import 'package:transit_dashboard/errors.dart' show errorOrResult;
import 'package:transit_dashboard/loggers.dart' show setupLogging;

import 'generated_code/journey_planner.swagger.dart'
    show
        Format,
        JourneyPlanner,
        RealTimeInfo,
        Stop,
        StopTimetableResponse,
        Trip;
import 'journey_planner_service.dart' show Location, nearbyStops;
import 'pair.dart' show Pair;

var json = const JsonEncoder.withIndent('  ');
var logger = Logger('transit.dart');

Future<void> main() async {
  await tz.initializeTimeZone();
  var perth = tz.getLocation('Australia/Perth');
  setupLogging();

  var location = Location(-31.951548099520902, 115.85798556027436);

  var apiKey = 'eac7a147-0831-4fcf-8fa8-a5e8ffcfa039';
  var stops = await nearbyStops(apiKey, location);
  logger.info('stops: ${stops.length}');
  logger.info('trips: ${stops[0].trips?.length}');

  JourneyPlanner client = getClient(
      JourneyPlanner.create,
      // "http://au-journeyplanner.silverrailtech.com/journeyplannerservice/v2/REST",
      "http://realtime.transperth.info/SJP/StopTimetableService.svc/",
      // apiKey
      "ad89905f-d5a7-487f-a876-db39092c6ee0");

  var now = tz.TZDateTime.now(perth);

  Set<Pair<Stop, Trip>> nearbyBuses = (await Future.wait(stops
          .map((stop) => getStopTimetable(client, stop.transitStop!.code!))))
      .where((element) {
        if (element.trips == null) {
          logger.warning('${element.toJson()} has no trips');
        }
        return element.trips != null;
      })
      .expand((element) =>
          element.trips!.map((e) => Pair.of(element.requestedStop!, e)))
      .where((element) {
        var good = getRealtime(now, element.right.realTimeInfo) != null;
        if (!good) {
          logger.warning('${element.right.toJson()} has no real time info');
        }
        return good;
      })
      .toSet();

  print(json.convert({
    'closest': nearbyBuses.map((e) => e.left.description).toSet().toList()
  }));
  var nearbyBus = nearbyBuses.first;

  var realTimeInfo = nearbyBus.right.realTimeInfo!;
  tz.TZDateTime? arrivalDateTime = getRealtime(now, realTimeInfo);

  assert(arrivalDateTime != null, "Arrival time must exist");

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
      now.difference(arrivalDateTime!));
}

tz.TZDateTime? getRealtime(tz.TZDateTime now, RealTimeInfo? realTimeInfo) {
  if (realTimeInfo?.estimatedArrivalTime != null) {
    return toDateTime(now, realTimeInfo!.estimatedArrivalTime!);
  } else if (realTimeInfo?.actualArrivalTime != null) {
    return toDateTime(now, realTimeInfo!.actualArrivalTime!);
  } else {
    return null;
  }
}

T getClient<T extends ChopperService>(
    T Function() create, String baseUrl, String apiKey) {
  var baseClient = create();
  return ChopperClient(
          client: SentryHttpClient(
              captureFailedRequests: true,
              networkTracing: true,
              recordBreadcrumbs: true,
              sendDefaultPii: true),
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

tz.TZDateTime toDateTime(tz.TZDateTime now, String strung) {
  assert(strung.length == 6, strung);

  var parts = strung.split(':').map((e) => int.parse(e)).toList();
  return tz.TZDateTime(
      now.location, now.year, now.month, now.day, parts[0], parts[1], parts[2]);
}

void createNotification(String description, String routeCode, Duration delta) {
  print({"description": description, "routeCode": routeCode, "delta": delta});
}

Future<StopTimetableResponse> getStopTimetable(
    JourneyPlanner client, String stopNumber) async {
  var time = getNowAsString();

  return errorOrResult(await client.dataSetsDatasetStopTimetableGet(
      dataset: 'PerthRestricted',
      stop: "PerthRestricted:$stopNumber",
      isRealTimeChecked: true,
      returnNotes: true,
      time: time,
      format: Format.json));
}

String getNowAsString() => DateFormat('yyyy-MM-ddTHH:mm')
    .format(tz.TZDateTime.now(tz.getLocation('Australia/Perth')));
