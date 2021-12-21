import 'package:awesome_notifications/awesome_notifications.dart'
    show
        AwesomeNotifications,
        NotificationChannel,
        NotificationLayout,
        NotificationChannelGroup,
        NotificationContent;
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

import 'generated_code/journey_planner.enums.swagger.dart';
import 'generated_code/journey_planner.swagger.dart'
    show JourneyPlanner, Stop, Trip, TripSummary;
import 'transit.dart' show getClient, getRealtime;

var awesomeNotifications = AwesomeNotifications();
var logger = Logger('main.dart');

void main() async {
  const sentryDsn = String.fromEnvironment('SENTRY_DSN');
  if (sentryDsn.isEmpty) {
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

class _MyHomePageState extends State<MyHomePage> {
  late JourneyPlanner client;

  String? routeNumber;
  String? stopNumber;

  OrderedSet<Tuple2<Stop, Trip>> routeChoices =
      OrderedSet(Comparing.on((t) => t.item2.summary!.hashCode));

  _MyHomePageState() {
    client = getClient(
        JourneyPlanner.create,
        "http://realtime.transperth.info/SJP/StopTimetableService.svc/",
        "ad89905f-d5a7-487f-a876-db39092c6ee0");
  }

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
                            children: routeChoices.map((tup) {
                              var element = tup.item2;
                              return ListTile(
                                  iconColor: getIconColor(element.summary!),
                                  leading: getIcon(element.summary!),
                                  title: Text(element.summary!.makeSummary()),
                                  subtitle: Column(
                                    children: [
                                      SizedBox(
                                          height: 50,
                                          child: Text('Mode: ' +
                                              (element.summary?.mode?.name ??
                                                  'Unknown') +
                                              ', Time: ' +
                                              (element.arriveTime ??
                                                  'Unknown'))),
                                      Row(
                                        children: [
                                          ElevatedButton(
                                            onPressed: () async {
                                              await catcher(
                                                  'failed to show notification',
                                                  () async =>
                                                      await showNotification(
                                                          tup.item1,
                                                          tup.item2));
                                            },
                                            child: const Text('Track'),
                                          )
                                        ],
                                      )
                                    ],
                                  ));
                            }).toList(),
                            primary: true)))
          ],
        ),
      ),
    );
  }

  Future<void> reload() async {
    await catcher('failed to reload', () async => await loadStops());
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

  showNotification(Stop transitStop, Trip trip) async {
    if (trip.arriveTime == null) {
      throw Exception('missing arrive time on ${trip.toJson()}');
    }
    var summary = trip.summary!;

    setState(() {
      stopNumber = transitStop.code! + " " + transitStop.description!;
      routeNumber = summary.makeSummary();
    });

    while (true) {
      var perth = getLocation('Australia/Perth');
      var now = TZDateTime.now(perth);

      var content = [];

      // for now, we're assuming the realtime doesn't change
      var realtime = getRealtime(now, trip.realTimeInfo);
      var scheduled = TZDateTime.parse(perth, trip.arriveTime!);
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

      await update(routeNumber, content.join(' \n\n'));
      await Future.delayed(const Duration(seconds: 3));
    }
    await update(routeNumber, 'Departed');
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
    case TripSummaryMode.train:
      icon = Icons.directions_train;
      break;
    default:
      icon = Icons.circle_outlined;
  }

  return Icon(icon);
}

first(List<dynamic> parts) {
  return parts
      .map((e) => e.toString())
      .where((element) => element.isNotEmpty)
      .first;
}

update(String title, String text) async => await awesomeNotifications.createNotification(
    content: NotificationContent(
        id: 10,
        channelKey: 'basic_channel',
        title: title,
        summary: text.replaceAll('\n', '<br><br>'),
        body: text.replaceAll('\n', '<br><br>'),
        notificationLayout: NotificationLayout.BigText));

extension OrderedSetExt<E> on Iterable<E> {
  OrderedSet<E> toOrderedSet([int Function(E e1, E e2)? compare]) {
    var orderedSet = OrderedSet<E>(compare);
    orderedSet.addAll(this);
    return orderedSet;
  }
}
