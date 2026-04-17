import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:saatdin/screens/welcome_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  testWidgets('welcome screen enables continue for a valid phone number', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: WelcomeScreen(),
      ),
    );

    expect(find.text('Continue'), findsOneWidget);
    expect(find.text('Enter mobile number'), findsOneWidget);

    await tester.enterText(find.byType(TextField), '9876543210');
    await tester.pump();

    final text = tester.widget<Text>(find.text('Continue'));
    expect(text.style?.color, equals(Colors.white));
  });
}
