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
import 'package:timezone/data/latest.dart' show initializeTimeZones;
import 'package:timezone/standalone.dart' as tz;
import 'package:transit_dashboard/errors.dart' show errorOrResult;
import 'package:transit_dashboard/loggers.dart' show setupLogging;

import 'generated_code/journey_planner.swagger.dart'
    show Format, JourneyPlanner, StopTimetableResponse, Trip;
import 'generated_code/realtime_trip.swagger.dart' as rtt;
import 'journey_planner_service.dart' show Location, nearbyStops;

var checkNotNull = ArgumentError.checkNotNull;
var json = const JsonEncoder.withIndent('  ');
var logger = Logger('transit.dart');
var dataset = 'PerthRestricted';

Future<void> main() async {
  initializeTimeZones();
  setupLogging();

  var location = Location(-31.951548099520902, 115.85798556027436);

  var stops = await nearbyStops(location);
  logger.info('stops: ${stops.length}');
  logger.info('trips: ${stops[0].trips?.length}');

  rtt.RealtimeTrip tripClient = getRealtimeTripService();

  var stop = stops[0];
  var stopCode = stop.transitStop!.code;
  var trip = stop.trips![0];

  var tripStop = await getTripStop(tripClient, trip, stopCode);
  print(tripStop.realTimeInfo?.toJson());
}

rtt.RealtimeTrip getRealtimeTripService() {
  return getClient(
      rtt.RealtimeTrip.create,
      "http://realtime.transperth.info/SJP/TripService.svc/",
      const String.fromEnvironment("REALTIME_API_KEY"));
}

Future<rtt.TripStop> getTripStop(
    rtt.RealtimeTrip tripClient, Trip trip, String? stopCode) async {
  var realtimeTrip = errorOrResult(await tripClient.dataSetsDatasetTripGet(
      dataset: dataset,
      isRealTimeChecked: true,
      tripUid: trip.summary!.tripUid!,
      tripDate: trip.arriveTime!,
      format: rtt.Format.json));

  checkNotNull(realtimeTrip, "body");
  checkNotNull(realtimeTrip.tripStops, "tripsStops");

  return realtimeTrip.tripStops!
      .where((element) => element.transitStop != null)
      .firstWhere((element) => element.transitStop!.code == stopCode);
}

tz.TZDateTime? getRealtime(tz.TZDateTime now, rtt.RealTimeInfo? realTimeInfo) {
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

String getNowAsString() => DateFormat('yyyy-MM-ddTHH:mm').format(getNow());
tz.TZDateTime getNow() => tz.TZDateTime.now(tz.getLocation('Australia/Perth'));
