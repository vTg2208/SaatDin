import 'package:flutter_test/flutter_test.dart';

import 'package:saatdin/main.dart';

void main() {
  testWidgets('SaatDin app renders auth entry flow', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const SaatDinApp());
    await tester.pump();

    expect(find.text('Get Paid'), findsOneWidget);
    expect(find.text('Automatically'), findsOneWidget);
  });
}
