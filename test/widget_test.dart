import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

// Your actual app package name
import 'package:crictrax/main.dart';

void main() {
  testWidgets('Splash screen builds successfully test', (WidgetTester tester) async {
    // 1. Build our Cricket app instead of MyApp
    await tester.pumpWidget(const CricketApp());

    // 2. Verify that the splash screen text 'CRICTRAX' renders on screen
    expect(find.text('CRICTRAX'), findsOneWidget);
  });
}