import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:saatdin/main.dart';

void main() {
  testWidgets('SaatDin app renders welcome screen', (WidgetTester tester) async {
    await tester.pumpWidget(const SaatDinApp());

    // Verify that the welcome screen shows key elements
    expect(find.text('Continue'), findsOneWidget);
    expect(find.text('Log In or Sign Up'), findsOneWidget);
    expect(find.byType(TextField), findsOneWidget);
  });
}
