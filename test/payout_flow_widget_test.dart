import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:saatdin/screens/payouts/payouts_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  testWidgets('payouts screen shows a loading state while bootstrapping data', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: PayoutsScreen(),
      ),
    );

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });
}
