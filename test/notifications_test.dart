import 'dart:ui' show CallbackHandle, PluginUtilities;

import 'package:flutter/services.dart'
    show MethodCall, MethodChannel, ServicesBinding;
import 'package:flutter_test/flutter_test.dart'
    show TestDefaultBinaryMessenger, testWidgets;
import 'package:transit_dashboard/background.dart' show Job, SHOW_NOTIFICATION;
import 'package:transit_dashboard/generated_code/journey_planner.swagger.dart'
    show Stop, Trip;
import 'package:transit_dashboard/main.dart' show registerBackgroundTasks;
import 'package:workmanager/workmanager.dart' show Workmanager;

void main() {
  testWidgets('description', (tester) async {
    var workManager = Workmanager();

    await mockWorkManager();

    await workManager.initialize(registerBackgroundTasks);

    var stop = Stop();
    var trip = Trip();

    await workManager.registerOneOffTask('uniqueName', SHOW_NOTIFICATION,
        inputData: Job(stop, trip).toJson());
  });
}

Future<void> mockWorkManager() async {
  var bm = (ServicesBinding.instance!.defaultBinaryMessenger
      as TestDefaultBinaryMessenger);

  var foreground = const MethodChannel(
      "be.tramckrijte.workmanager/foreground_channel_work_manager");
  var background = const MethodChannel(
      "be.tramckrijte.workmanager/background_channel_work_manager");

  bm.setMockMethodCallHandler(foreground, (message) async {
    var arguments = (message.arguments as Map);
    switch (message.method) {
      case "initialize":
        var handle = arguments['callbackHandle'];
        var callback = PluginUtilities.getCallbackFromHandle(
            CallbackHandle.fromRawHandle(handle)) as void Function()?;
        callback!();
        break;
      case "registerOneOffTask":
        var methodCall = MethodCall("method", {
          "be.tramckrijte.workmanager.DART_TASK": arguments['taskName'],
          "be.tramckrijte.workmanager.INPUT_DATA": arguments['inputData']
        });
        await bm.handlePlatformMessage(background.name,
            background.codec.encodeMethodCall(methodCall), null);
    }
  });

  bm.setMockMethodCallHandler(background, (message) async {
    switch (message.method) {
      case "backgroundChannelInitialized":
        break;
    }
  });
}
