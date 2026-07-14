import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ride_club/widgets/status_badge.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Widget wrap(Widget child) => MaterialApp(home: Scaffold(body: child));

  testWidgets('count badge shows the number', (WidgetTester tester) async {
    await tester.pumpWidget(wrap(StatusBadge.count(count: 3)));
    expect(find.text('3'), findsOneWidget);
  });

  testWidgets('count badge caps display at 9+', (WidgetTester tester) async {
    await tester.pumpWidget(wrap(StatusBadge.count(count: 42)));
    expect(find.text('9+'), findsOneWidget);
  });

  testWidgets('count badge renders nothing for zero', (WidgetTester tester) async {
    await tester.pumpWidget(wrap(StatusBadge.count(count: 0)));
    expect(find.byType(StatusBadge), findsOneWidget);
    expect(find.text('0'), findsNothing);
  });

  testWidgets('label badge shows its label', (WidgetTester tester) async {
    await tester.pumpWidget(
        wrap(StatusBadge.label(label: 'Host', color: Colors.blue)));
    expect(find.text('Host'), findsOneWidget);
  });
}
