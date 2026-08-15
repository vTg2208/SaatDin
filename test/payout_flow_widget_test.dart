import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:saatdin/screens/payouts/payouts_screen.dart';
import 'package:saatdin/models/payment_order_model.dart';
import 'package:saatdin/models/plan_model.dart';
import 'package:saatdin/models/user_model.dart';
import 'package:saatdin/routes/app_routes.dart';
import 'package:saatdin/screens/onboarding/payment/payment_flow_arguments.dart';
import 'package:saatdin/screens/onboarding/payment/payment_method_screen.dart';
import 'package:saatdin/screens/onboarding/payment/payment_success_screen.dart';
import 'package:saatdin/services/api_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  testWidgets('payouts screen shows a loading state while bootstrapping data', (
    tester,
  ) async {
    await tester.pumpWidget(const MaterialApp(home: PayoutsScreen()));

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });

  testWidgets('pending retry reuses the existing payment order', (
    tester,
  ) async {
    final api = _FakePaymentApi(completeAsPaid: false);
    await _pumpPaymentFlow(tester, api);

    await tester.ensureVisible(find.text('Proceed with Paytm'));
    await tester.tap(find.text('Proceed with Paytm'));
    await tester.pump(const Duration(seconds: 2));

    expect(find.byType(PaymentSuccessScreen), findsNothing);
    expect(api.createCalls, 1);

    await tester.ensureVisible(find.text('Proceed with Paytm'));
    await tester.tap(find.text('Proceed with Paytm'));
    await tester.pump(const Duration(seconds: 2));

    expect(api.createCalls, 1);
  });

  testWidgets('paid order is required to open payment success', (tester) async {
    final api = _FakePaymentApi(completeAsPaid: true);
    await _pumpPaymentFlow(tester, api);

    await tester.ensureVisible(find.text('Proceed with Paytm'));
    await tester.tap(find.text('Proceed with Paytm'));
    await tester.pumpAndSettle();

    expect(find.byType(PaymentSuccessScreen), findsOneWidget);
    expect(find.text('Cover scheduled'), findsOneWidget);
  });
}

Future<void> _pumpPaymentFlow(WidgetTester tester, PaymentOrderApi api) async {
  tester.view.physicalSize = const Size(1080, 1920);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  await tester.pumpWidget(
    MaterialApp(
      initialRoute: AppRoutes.paymentMethod,
      routes: {
        AppRoutes.paymentMethod: (context) =>
            PaymentMethodScreen(paymentApi: api),
        AppRoutes.paymentSuccess: (context) => const PaymentSuccessScreen(),
      },
      onGenerateInitialRoutes: (initialRoute) => [
        MaterialPageRoute<void>(
          settings: RouteSettings(name: initialRoute, arguments: _arguments),
          builder: (context) => PaymentMethodScreen(paymentApi: api),
        ),
      ],
    ),
  );
  await tester.pumpAndSettle();
}

const _arguments = PaymentFlowArguments(
  plan: InsurancePlan(
    name: 'Standard',
    weeklyPremium: 60,
    perTriggerPayout: 400,
    maxDaysPerWeek: 3,
  ),
  phone: '9876543210',
  name: 'Raju',
  platform: 'Blinkit',
  zone: 'Bellandur',
  pincode: '560103',
);

class _FakePaymentApi implements PaymentOrderApi {
  _FakePaymentApi({required this.completeAsPaid});

  final bool completeAsPaid;
  int createCalls = 0;

  PaymentOrder get _pending => _order(PaymentOrderStatus.pending);
  PaymentOrder get _paid => _order(PaymentOrderStatus.paid);

  @override
  Future<PaymentOrder> completeSandboxPaymentOrder(String orderId) async {
    return completeAsPaid ? _paid : _pending;
  }

  @override
  Future<PaymentOrder> createPaymentOrder({
    required String clientRequestId,
  }) async {
    createCalls += 1;
    return _pending;
  }

  @override
  Future<PaymentOrder> getPaymentOrder(String orderId) async => _pending;

  @override
  Future<User?> registerUser({
    required String phone,
    required String platformName,
    required String zone,
    required String planName,
    String? name,
  }) async => const User.empty(phone: '9876543210');

  PaymentOrder _order(PaymentOrderStatus status) => PaymentOrder(
    id: '63c40536-b23a-4d52-8360-1a08454dcd10',
    status: status,
    provider: 'sandbox',
    amount: 60,
    currency: 'INR',
    coverageWeekStart: DateTime.utc(2026, 8, 17),
    expiresAt: DateTime.utc(2026, 8, 15, 8, 15),
    checkoutData: const {'providerOrderId': 'sandbox-order-1'},
  );
}
