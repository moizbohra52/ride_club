import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ride_club/core/theme/app_theme.dart';
import 'package:ride_club/widgets/app_card.dart';

void main() {
  Widget wrap(Widget child) => MaterialApp(
        theme: AppTheme.light,
        home: Scaffold(body: child),
      );

  testWidgets('renders its child', (WidgetTester tester) async {
    await tester.pumpWidget(wrap(const AppCard(child: Text('hello'))));
    expect(find.text('hello'), findsOneWidget);
  });

  testWidgets('calls onTap when tapped', (WidgetTester tester) async {
    int taps = 0;
    await tester.pumpWidget(wrap(AppCard(
      onTap: () => taps++,
      child: const Text('tap me'),
    )));
    await tester.tap(find.text('tap me'));
    expect(taps, 1);
  });

  testWidgets('is not tappable when onTap is null', (WidgetTester tester) async {
    await tester.pumpWidget(wrap(const AppCard(child: Text('static'))));
    expect(find.byType(InkWell), findsNothing);
  });

  testWidgets('renders an accent strip when accentColor is given',
      (WidgetTester tester) async {
    await tester.pumpWidget(wrap(AppCard(
      accentColor: Colors.red,
      child: const Text('accented'),
    )));
    expect(find.text('accented'), findsOneWidget);
  });
}
