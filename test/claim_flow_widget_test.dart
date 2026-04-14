import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:saatdin/screens/claims/zone_lock_report_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  testWidgets('zone lock report validates required fields', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: ZoneLockReportScreen(),
      ),
    );

    await tester.tap(find.text('Submit ZoneLock Report'));
    await tester.pump();

    expect(find.text('Location is required'), findsOneWidget);
    expect(find.text('Description is required'), findsOneWidget);
  });
}
