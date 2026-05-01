// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:carelink/app_router.dart';

void main() {
  testWidgets('App launches without errors', (WidgetTester tester) async {
    // Build our app with ProviderScope wrapper and trigger a frame.
    await tester.pumpWidget(
      const ProviderScope(
        child: CarelinkApp(),
      ),
    );

    // Verify app loaded successfully by checking for loading indicator or initial screen
    expect(find.byType(MaterialApp), findsOneWidget);
  });
}
