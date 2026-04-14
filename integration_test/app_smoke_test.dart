import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'package:saatdin/main.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('app boots into an auth-capable entry surface', (tester) async {
    await tester.pumpWidget(const SaatDinApp());
    await tester.pumpAndSettle(const Duration(milliseconds: 400));

    final visible = find.text('Continue').evaluate().isNotEmpty ||
        find.text('Restoring your coverage session...').evaluate().isNotEmpty ||
        find.text('Get Started').evaluate().isNotEmpty;

    expect(visible, isTrue);
  });
}
