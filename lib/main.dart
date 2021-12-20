import 'package:awesome_notifications/awesome_notifications.dart'
    show
        AwesomeNotifications,
        NotificationChannel,
        NotificationChannelGroup,
        NotificationContent;
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart'
    show GeolocatorPlatform, LocationPermission, LocationSettings;
import 'package:get/get.dart'
    show Get, GetMaterialApp, /*ExtensionDialog,*/ ExtensionSnackbar;
import 'package:logging/logging.dart';
import 'package:timezone/data/latest.dart' show initializeTimeZones;
import 'package:timezone/standalone.dart' show TZDateTime, getLocation;
import 'package:transit_dashboard/journey_planner_service.dart'
    show Location, nearbyStops;

import 'generated_code/journey_planner.swagger.dart' show JourneyPlanner;
import 'transit.dart' show getClient, getRealtime, getStopTimetable, toDateTime;

var awesomeNotifications = AwesomeNotifications();

void main() async {
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
    return GetMaterialApp(
      title: 'Transit Dashboard',
      theme: ThemeData(
        // This is the theme of your application.
        //
        // Try running your application with "flutter run". You'll see the
        // application has a blue toolbar. Then, without quitting the app, try
        // changing the primarySwatch below to Colors.green and then invoke
        // "hot reload" (press "r" in the console where you ran "flutter run",
        // or simply save your changes to "hot reload" in a Flutter IDE).
        // Notice that the counter didn't reset back to zero; the application
        // is not restarted.
        primarySwatch: Colors.blue,
      ),
      home: const MyHomePage(title: 'Flutter Demo Home Page'),
    );
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
  int _counter = 0;
  late JourneyPlanner client;

  String? routeNumber;
  String? stopNumber;

  _MyHomePageState() {
    client = getClient(
        JourneyPlanner.create,
        "http://realtime.transperth.info/SJP/StopTimetableService.svc/",
        "ad89905f-d5a7-487f-a876-db39092c6ee0");
  }

  void _incrementCounter() {
    setState(() {
      // This call to setState tells the Flutter framework that something has
      // changed in this State, which causes it to rerun the build method below
      // so that the display can reflect the updated values. If we changed
      // _counter without calling setState(), then the build method would not be
      // called again, and so nothing would appear to happen.
      _counter++;
    });
  }

  @override
  Widget build(BuildContext context) {
    // This method is rerun every time setState is called, for instance as done
    // by the _incrementCounter method above.
    //
    // The Flutter framework has been optimized to make rerunning build methods
    // fast, so that you can just rebuild anything that needs updating rather
    // than having to individually change instances of widgets.
    return Scaffold(
      appBar: AppBar(
        // Here we take the value from the MyHomePage object that was created by
        // the App.build method, and use it to set our appbar title.
        title: Text(widget.title),
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
            MaterialButton(
                child: const Text('Load stops'),
                onPressed: () async {
                  try {
                    await loadStops();
                  } catch (e, s) {
                    Logger('main.dart').shout('failed to load stops', e, s);
                    Get.snackbar(e.toString(), s.toString());
                  }
                }),
            const Text(
              'You have pushed the button this many times:',
            ),
            Text(
              '$_counter',
              style: Theme.of(context).textTheme.headline4,
            ),
            Text('Selected stop: $stopNumber'),
            Text('Selected route: $routeNumber'),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _incrementCounter,
        tooltip: 'Increment',
        child: const Icon(Icons.add),
      ), // This trailing comma makes auto-formatting nicer for build methods.
    );
  }

  Future<void> loadStops() async {
    setState(() {
      stopNumber = null;
      routeNumber = null;
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
    if (locationPermission == LocationPermission.always ||
        locationPermission == LocationPermission.whileInUse) {
      var loco = await GeolocatorPlatform.instance.getCurrentPosition(
          locationSettings:
              const LocationSettings(timeLimit: Duration(seconds: 30)));

      var stops = await nearbyStops('eac7a147-0831-4fcf-8fa8-a5e8ffcfa039',
          Location(loco.latitude, loco.longitude));

      /*
      await Get.defaultDialog(
          title: 'Stops',
          content: ListView(
              children: stops
                  .map((e) => ListTile(
                      title: Text(e.transitStop!.description!),
                      subtitle: Text(
                          '${e.transitStop!.code} - ${e.distance} metres away')))
                  .toList()));
      */

      var transitStop = stops.first.transitStop!;
      var stopNumber = transitStop.code!;
      setState(() {
        this.stopNumber = stopNumber + " " + transitStop.description!;
      });

      var response = await getStopTimetable(client, stopNumber);
      if (response.trips!.isEmpty) {
        setState(() {
          routeNumber = "No trips at stop";
        });
        return;
      }

      var trip = response.trips![0];

      setState(() {
        routeNumber = trip.summary!.routeCode;
      });

      var title = '$routeNumber to ${trip.summary!.headsign}';

      if (getRealtime(trip.realTimeInfo) == null) {
        await update(title, 'No realtime information available');
        return;
      }

      while (true) {
        // for now, we're assuming the realtime doesn't change
        var now = TZDateTime.now(getLocation('Australia/Perth'));
        var delta =
            toDateTime(now, getRealtime(trip.realTimeInfo)!).difference(now);

        if (delta < Duration.zero) break;

        var strung = delta.toString().split(':').map(int.parse).toList();

        await update(title, '${strung[1]} minutes, ${strung[2]} seconds away');
        await Future.delayed(const Duration(seconds: 3));
      }
      await update(title, 'Departed');
    } else {
      throw Exception(locationPermission.toString());
    }
  }
}

update(title, text) async => await awesomeNotifications.createNotification(
    content: NotificationContent(
        id: 10, channelKey: 'basic_channel', title: title, body: text));
