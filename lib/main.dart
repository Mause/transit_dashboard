import 'package:awesome_notifications/awesome_notifications.dart'
    show
        AwesomeNotifications,
        NotificationActionButton,
        NotificationChannel,
        NotificationChannelGroup,
        NotificationContent,
        NotificationLayout;
import 'package:duration/duration.dart' show prettyDuration;
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart'
    show GeolocatorPlatform, LocationPermission, LocationSettings;
import 'package:get/get.dart' show Get, GetMaterialApp, ExtensionSnackbar;
import 'package:logging/logging.dart';
import 'package:material_you_colours/material_you_colours.dart'
    show getMaterialYouThemeData;
import 'package:ordered_set/comparing.dart' show Comparing;
import 'package:ordered_set/ordered_set.dart' show OrderedSet;
import 'package:sentry_flutter/sentry_flutter.dart'
    show Sentry, SentryFlutter, SentryNavigatorObserver;
import 'package:sentry_logging/sentry_logging.dart' show LoggingIntegration;
import 'package:timezone/data/latest.dart' show initializeTimeZones;
import 'package:timezone/standalone.dart' show TZDateTime, getLocation;
import 'package:transit_dashboard/journey_planner_service.dart'
    show Location, nearbyStops;
import 'package:tuple/tuple.dart';

import 'generated_code/client_index.dart' show JourneyPlanner, RealtimeTrip;
import 'generated_code/journey_planner.enums.swagger.dart';
import 'generated_code/journey_planner.swagger.dart'
    show Stop, Trip, TripSummary;
import 'transit.dart'
    show getClient, getRealtime, getRealtimeTripService, getTripStop;
import 'tuple_comparing.dart';

var awesomeNotifications = AwesomeNotifications();
var logger = Logger('main.dart');

void main() async {
  const sentryDsn = String.fromEnvironment('SENTRY_DSN');
  if (sentryDsn.isNotEmpty) {
    await SentryFlutter.init((options) {
      options.dsn = sentryDsn;
      options.tracesSampleRate = 1.0;
      options.addIntegration(LoggingIntegration());
    }, appRunner: _main);
  } else {
    logger.warning('Not running with Sentry');
    await _main();
  }
}

Future<void> _main() async {
  initializeTimeZones();
  await awesomeNotifications.initialize(
      // set the icon to null if you want to use the default app icon
      null,
      [
        NotificationChannel(
            channelGroupKey: 'basic_channel_group',
            channelKey: 'basic_channel',
            channelName: 'Basic notifications',
            channelDescription: 'Notification channel for basic tests',
            defaultColor: const Color(0xFF9D50DD),
            ledColor: Colors.white)
      ],
      channelGroups: [
        NotificationChannelGroup(
            channelGroupkey: 'basic_channel_group',
            channelGroupName: 'Basic group')
      ],
      debug: true);
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return FutureBuilder(
        future: getMaterialYouThemeData(),
        builder: (BuildContext context, AsyncSnapshot<ThemeData?> theme) =>
            GetMaterialApp(
              navigatorObservers: [
                SentryNavigatorObserver(),
              ],
              title: 'Transit Dashboard',
              theme: theme.data ?? ThemeData.fallback(),
              home: const MyHomePage(title: 'Transit Dashboard'),
            ));
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({Key? key, required this.title}) : super(key: key);

  // This widget is the home page of your application. It is stateful, meaning
  // that it has a State object (defined below) that contains fields that affect
  // how it looks.

  // This class is the configuration for the state. It holds the values (in this
  // case the title) provided by the parent (in this case the App widget) and
  // used by the build method of the State. Fields in a Widget subclass are
  // always marked "final".

  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

enum TimeSource { scheduled, actual, estimated }

Tuple2<TimeSource, String>? getArrivalTime(Trip trip) {
  if (trip.realTimeInfo?.actualArrivalTime != null) {
    return Tuple2(TimeSource.actual, trip.realTimeInfo!.actualArrivalTime!);
  } else if (trip.realTimeInfo?.estimatedArrivalTime != null) {
    return Tuple2(
        TimeSource.estimated, trip.realTimeInfo!.estimatedArrivalTime!);
  } else if (trip.arriveTime != null) {
    return Tuple2(TimeSource.scheduled, trip.arriveTime!);
  } else {
    return null;
  }
}

class _MyHomePageState extends State<MyHomePage> {
  JourneyPlanner client;
  RealtimeTrip realtimeTripService;

  String? routeNumber;
  String? stopNumber;

  OrderedSet<Tuple2<Stop, Trip>> routeChoices = OrderedSet(Comparing.on((t) {
    String item1 = getArrivalTime(t.item2)?.item2 ?? '0000-00-00T00:00';
    TripSummary item2 = t.item2.summary!;
    return TupleComparing([
      item1,
      TupleComparing(
          [item2.routeCode ?? item2.routeName ?? '', item2.direction!])
    ]);
  }));

  _MyHomePageState()
      : client = getClient(
            JourneyPlanner.create,
            "http://realtime.transperth.info/SJP/StopTimetableService.svc/",
            "ad89905f-d5a7-487f-a876-db39092c6ee0"),
        realtimeTripService = getRealtimeTripService();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        // Here we take the value from the MyHomePage object that was created by
        // the App.build method, and use it to set our appbar title.
        title: Title(child: Text(widget.title), color: Colors.amberAccent),
      ),
      body: Center(
        // Center is a layout widget. It takes a single child and positions it
        // in the middle of the parent.
        child: Column(
          // Column is also a layout widget. It takes a list of children and
          // arranges them vertically. By default, it sizes itself to fit its
          // children horizontally, and tries to be as tall as its parent.
          //
          // Invoke "debug painting" (press "p" in the console, choose the
          // "Toggle Debug Paint" action from the Flutter Inspector in Android
          // Studio, or the "Toggle Debug Paint" command in Visual Studio Code)
          // to see the wireframe for each widget.
          //
          // Column has various properties to control how it sizes itself and
          // how it positions its children. Here we use mainAxisAlignment to
          // center the children vertically; the main axis here is the vertical
          // axis because Columns are vertical (the cross axis would be
          // horizontal).
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            Text('Selected stop: $stopNumber, route: $routeNumber'),
            Text('Sentry enabled: ${Sentry.isEnabled}'),
            Expanded(
                child: RefreshIndicator(
                    onRefresh: reload,
                    child: routeChoices.isEmpty
                        ? Stack(
                            children: <Widget>[
                              const Center(
                                child: Text('Pull to load nearby trips'),
                              ),
                              ListView(),
                            ],
                          )
                        : ListView(
                            children: routeChoices
                                .map((tup) => TripTile(
                                    stop: tup.item1,
                                    trip: tup.item2,
                                    showNotification: showNotification))
                                .toList(),
                            primary: true)))
          ],
        ),
      ),
    );
  }

  Future<void> reload() async {
    await catcher('failed to reload', () async => loadStops());
  }

  Future<void> loadStops() async {
    setState(() {
      stopNumber = null;
      routeNumber = null;
      routeChoices.clear();
    });

    var isAllowed = await awesomeNotifications.isNotificationAllowed();
    if (!isAllowed) {
      // This is just a basic example. For real apps, you must show some
      // friendly dialog box before call the request method.
      // This is very important to not harm the user experience
      await awesomeNotifications.requestPermissionToSendNotifications();
    }

    var locationPermission =
        await GeolocatorPlatform.instance.requestPermission();
    if (locationPermission == LocationPermission.denied ||
        locationPermission == LocationPermission.deniedForever) {
      throw Exception(locationPermission.toString());
    }

    var loco = await GeolocatorPlatform.instance.getCurrentPosition(
        locationSettings:
            const LocationSettings(timeLimit: Duration(seconds: 30)));

    var stops = (await nearbyStops('eac7a147-0831-4fcf-8fa8-a5e8ffcfa039',
            Location(loco.latitude, loco.longitude)))
        .where((element) => element.trips!.isNotEmpty)
        .toList();

    setState(() {
      routeChoices.clear();
      routeChoices.addAll(stops
          .expand((e) => e.trips!.map((trip) => Tuple2(e.transitStop!, trip))));
    });
  }

  Future<void> showNotification(Stop transitStop, Trip scheduledTrip) async {
    var trip =
        await getTripStop(realtimeTripService, scheduledTrip, transitStop.code);

    if (trip.arrivalTime == null) {
      throw Exception('missing arrive time on ${trip.toJson()}');
    }

    setState(() {
      stopNumber = transitStop.code! + " " + transitStop.description!;
      routeNumber = scheduledTrip.summary!.makeSummary();
    });

    while (true) {
      var perth = getLocation('Australia/Perth');
      var now = TZDateTime.now(perth);

      var content = <String>[];

      // for now, we're assuming the realtime doesn't change
      var realtime = getRealtime(now, trip.realTimeInfo);
      var scheduled = TZDateTime.from(trip.arrivalTime!, perth);
      var datetime = realtime ?? scheduled;

      var delta = datetime.difference(now);
      if (delta < Duration.zero) break;

      content.add(prettyDuration(delta, conjunction: ', ') + ' away.');
      if (realtime == null) {
        content.add(
            'Realtime information is not available. Using scheduled time.');
      } else {
        var howLate = scheduled.difference(realtime);
        content
            .add('Running ${prettyDuration(howLate, conjunction: ', ')} late.');
      }

      await update(routeNumber!, content);
      await Future.delayed(const Duration(seconds: 3));
    }
    await update(routeNumber!, ['Departed']);
  }
}

class TripTile extends StatelessWidget {
  final Trip trip;
  final Stop stop;
  final Future<void> Function(Stop stop, Trip trip) showNotification;

  const TripTile(
      {Key? key,
      required this.trip,
      required this.stop,
      required this.showNotification})
      : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Card(
        elevation: 18.0,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.start,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ListTile(
                iconColor: getIconColor(trip.summary!),
                leading: getIcon(trip.summary!),
                title: Text(trip.summary!.makeSummary()),
                subtitle: Text('Mode: ' +
                    (trip.summary?.mode?.name ?? 'Unknown') +
                    ', Time: ' +
                    (getArrivalTime(trip)?.toList().join(", ") ?? 'Unknown'))),
            ButtonBar(
              children: [
                ElevatedButton(
                  onPressed: () async {
                    await catcher('failed to show notification',
                        () async => showNotification(stop, trip));
                  },
                  child: const Text('Track'),
                )
              ],
            )
          ],
        ));
  }
}

Future<void> catcher(String hint, Future<void> Function() cb) async {
  try {
    await cb();
  } catch (e, s) {
    logger.shout(hint, e, s);
    await Sentry.captureException(e, stackTrace: s, hint: hint);
    Get.snackbar(e.toString(), s.toString());
  }
}

extension MakeSummary on TripSummary {
  String makeSummary() {
    return first([routeCode, routeName, mode]) + ' to $headsign';
  }
}

getIconColor(TripSummary summary) {
  if (summary.routeName!.endsWith('CAT')) {
    var color = summary.routeName!.split(' ')[0].toLowerCase();
    switch (color) {
      case "yellow":
        return Colors.yellow;
      case "blue":
        return Colors.blue;
      case "black":
        return Colors.black;
      case "red":
        return Colors.red;
    }
  }
  return Colors.black;
}

Icon getIcon(TripSummary summary) {
  if (summary.routeName!.endsWith('CAT')) {
    return const Icon(Icons.pets);
  }

  IconData icon;
  switch (summary.mode) {
    case TripSummaryMode.bus:
      icon = Icons.directions_bus;
      break;
    case TripSummaryMode.ferry:
      icon = Icons.directions_ferry;
      break;
    case TripSummaryMode.rail:
      icon = Icons.directions_train;
      break;
    default:
      icon = Icons.circle_outlined;
  }

  return Icon(icon);
}

String first(List<Object?> parts) {
  return parts
      .map((e) => e.toString())
      .where((element) => element.isNotEmpty)
      .first;
}

Future<void> update(String title, List<String> text) async =>
    awesomeNotifications.createNotification(
        content: NotificationContent(
            id: 10,
            channelKey: 'basic_channel',
            title: title,
            summary: text[0],
            body: text.join('<br>'),
            notificationLayout: NotificationLayout.BigText),
        actionButtons: [
          NotificationActionButton(key: 'dismiss', label: 'Dismiss')
        ]);

extension OrderedSetExt<E> on Iterable<E> {
  OrderedSet<E> toOrderedSet([int Function(E e1, E e2)? compare]) {
    var orderedSet = OrderedSet<E>(compare);
    orderedSet.addAll(this);
    return orderedSet;
  }
}
