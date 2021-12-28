// ignore_for_file: avoid_print

import 'dart:async' show Future, FutureOr;
import 'dart:convert' show JsonEncoder;

import 'package:chopper/chopper.dart'
    show
        ChopperClient,
        ChopperService,
        Converter,
        ErrorConverter,
        Request,
        Response;
import 'package:intl/intl.dart';
import 'package:logging/logging.dart' show Logger;
import 'package:sentry/sentry.dart' show SentryHttpClient;
import 'package:timezone/standalone.dart' as tz;
import 'package:transit_dashboard/errors.dart' show errorOrResult;
import 'package:transit_dashboard/loggers.dart' show setupLogging;
import 'package:tuple/tuple.dart';

import 'generated_code/journey_planner.swagger.dart'
    show
        Format,
        JourneyPlanner,
        RealTimeInfo,
        Stop,
        StopTimetableResponse,
        Trip;
import 'journey_planner_service.dart' show Location, nearbyStops;

var json = const JsonEncoder.withIndent('  ');
var logger = Logger('transit.dart');
var dataset = 'PerthRestricted';

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

  Set<Tuple2<Stop, Trip>> nearbyBuses = (await Future.wait(stops
          .map((stop) => getStopTimetable(client, stop.transitStop!.code!))))
      .where((element) {
        if (element.trips == null) {
          logger.warning('${element.toJson()} has no trips');
        }
        return element.trips != null;
      })
      .expand((element) =>
          element.trips!.map((e) => Tuple2(element.requestedStop!, e)))
      .where((element) {
        var good = getRealtime(now, element.item2.realTimeInfo) != null;
        if (!good) {
          logger.warning('${element.item2.toJson()} has no real time info');
        }
        return good;
      })
      .toSet();

  print(json.convert({
    'closest': nearbyBuses.map((e) => e.item1.description).toSet().toList()
  }));
  var nearbyBus = nearbyBuses.first;

  var realTimeInfo = nearbyBus.item2.realTimeInfo!;
  tz.TZDateTime? arrivalDateTime = getRealtime(now, realTimeInfo);

  assert(arrivalDateTime != null, "Arrival time must exist");

  print({
    "now": now,
    "realTimeInfo": realTimeInfo.toJson(),
    "arrivalDateTime": arrivalDateTime
  });

  createNotification(
      nearbyBus.item1.description!,
      nearbyBus.item2.summary!.routeCode! +
          ' ' +
          nearbyBus.item2.summary!.headsign!,
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
          // errorConverter: ErrorConvert(baseClient.client.converter!),
          interceptors: [
            (Request request) => request.copyWith(
                parameters: request.parameters
                  ..putIfAbsent('ApiKey', () => apiKey))
          ],
          baseUrl: baseUrl)
      .getService<T>();
}

class ErrorConvert extends ErrorConverter {
  Converter converter;

  ErrorConvert(this.converter);

  @override
  FutureOr<Response<dynamic>> convertError<BodyType, InnerType>(
      Response<dynamic> response) async {
    return await converter.convertResponse<BodyType, InnerType>(response);
  }
}

tz.TZDateTime toDateTime(tz.TZDateTime now, String strung) {
  assert(strung.length == 8, strung);

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
      dataset: dataset,
      stop: "$dataset:$stopNumber",
      isRealTimeChecked: true,
      returnNotes: true,
      time: time,
      format: Format.json));
}

String getNowAsString() => DateFormat('yyyy-MM-ddTHH:mm')
    .format(tz.TZDateTime.now(tz.getLocation('Australia/Perth')));
