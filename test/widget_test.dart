// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility that Flutter provides. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

// import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ordered_set/comparing.dart';

import 'package:transit_dashboard/tuple_comparing.dart';
import 'package:tuple/tuple.dart';

void main() {
/*
  testWidgets('Counter increments smoke test', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(const MyApp());

    // Verify that our counter starts at 0.
    expect(find.text('0'), findsOneWidget);
    expect(find.text('1'), findsNothing);

    // Tap the '+' icon and trigger a frame.
    await tester.tap(find.byIcon(Icons.add));
    await tester.pump();

    // Verify that our counter has incremented.
    expect(find.text('0'), findsNothing);
    expect(find.text('1'), findsOneWidget);
  });
  */
  test('tuple sorting', () {
    expect(TupleComparing([1, 2]).compareTo(TupleComparing([1, 2])), equals(0));
    expect(
        TupleComparing([1, 1]).compareTo(TupleComparing([1, 2])), equals(-1));
    var actual = [
      const Tuple2(1, 2),
      const Tuple2(1, 1),
    ]..sort(Comparing.on((t) => toComparable<num, num>(t)));
    expect(
        actual,
        equals(const [
          Tuple2(1, 1),
          Tuple2(1, 2),
        ]));
  });
}
