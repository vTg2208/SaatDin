import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:saatdin/models/plan_model.dart';
import 'package:saatdin/models/platform_model.dart';
import 'package:saatdin/models/user_model.dart';
import 'package:saatdin/models/zone_risk_model.dart';
import 'package:saatdin/routes/app_routes.dart';
import 'package:saatdin/screens/onboarding/plan_selection_screen.dart';
import 'package:saatdin/screens/onboarding/platform_selection_screen.dart';
import 'package:saatdin/screens/onboarding/zone_selection_screen.dart';
import 'package:saatdin/services/api_service.dart';

void main() {
  testWidgets('Platform step navigates to zone step with selected platform', (
    WidgetTester tester,
  ) async {
    Map<String, dynamic>? forwardedArgs;

    await tester.pumpWidget(
      MaterialApp(
        onGenerateRoute: (settings) {
          if (settings.name == AppRoutes.zoneSelect) {
            forwardedArgs = settings.arguments as Map<String, dynamic>?;
            return MaterialPageRoute<void>(
              builder: (_) => const Scaffold(body: Text('Zone Destination')),
              settings: settings,
            );
          }

          return MaterialPageRoute<void>(
            builder: (_) => PlatformSelectionScreen(
              initialArgs: const {'phone': '9876543210', 'name': 'Asha'},
              platformsLoader: (_) async => DeliveryPlatform.getPlatforms(),
            ),
            settings: settings,
          );
        },
      ),
    );

    await tester.pumpAndSettle();

    await tester.tap(find.text('Blinkit'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();

    expect(find.text('Zone Destination'), findsOneWidget);
    expect(forwardedArgs?['platform'], equals('Blinkit'));
    expect(forwardedArgs?['phone'], equals('9876543210'));
    expect(forwardedArgs?['name'], equals('Asha'));
  });

  testWidgets('Zone step navigates to plan step with selected zone details', (
    WidgetTester tester,
  ) async {
    Map<String, dynamic>? forwardedArgs;

    final zones = <ZoneRisk>[
      const ZoneRisk(
        pincode: '560103',
        name: 'Bellandur',
        lat: 0,
        lon: 0,
        blinkit: true,
        zepto: true,
        swiggyInstamart: true,
        floodRiskScore: 0,
        aqiRiskScore: 0,
        trafficCongestionScore: 0,
        compositeRiskScore: 0,
        zoneRiskMultiplier: 1.2,
        riskTier: 'MEDIUM',
        customRainLockThresholdMm3hr: 35,
      ),
    ];

    await tester.pumpWidget(
      MaterialApp(
        onGenerateRoute: (settings) {
          if (settings.name == AppRoutes.planSelect) {
            forwardedArgs = settings.arguments as Map<String, dynamic>?;
            return MaterialPageRoute<void>(
              builder: (_) => const Scaffold(body: Text('Plan Destination')),
              settings: settings,
            );
          }

          return MaterialPageRoute<void>(
            builder: (_) => ZoneSelectionScreen(
              initialArgs: const {
                'platform': 'Blinkit',
                'phone': '9123456789',
                'name': 'Ravi',
              },
              zonesLoader: (_, __) async => zones,
            ),
            settings: settings,
          );
        },
      ),
    );

    await tester.pumpAndSettle();

    await tester.tap(find.text('Bellandur (560103)'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();

    expect(find.text('Plan Destination'), findsOneWidget);
    expect(forwardedArgs?['platform'], equals('Blinkit'));
    expect(forwardedArgs?['zone'], equals('Bellandur'));
    expect(forwardedArgs?['pincode'], equals('560103'));
    expect(forwardedArgs?['phone'], equals('9123456789'));
    expect(forwardedArgs?['name'], equals('Ravi'));
  });

  testWidgets('Plan step registers user and goes to home', (
    WidgetTester tester,
  ) async {
    String? capturedPlan;
    String? capturedPhone;
    String? capturedZone;
    String? capturedPlatform;

    final plans = <InsurancePlan>[
      const InsurancePlan(
        name: 'Basic',
        weeklyPremium: 45,
        perTriggerPayout: 250,
        maxDaysPerWeek: 2,
      ),
      const InsurancePlan(
        name: 'Standard',
        weeklyPremium: 69,
        perTriggerPayout: 400,
        maxDaysPerWeek: 3,
        isPopular: true,
      ),
      const InsurancePlan(
        name: 'Premium',
        weeklyPremium: 89,
        perTriggerPayout: 550,
        maxDaysPerWeek: 4,
      ),
    ];

    await tester.pumpWidget(
      MaterialApp(
        onGenerateRoute: (settings) {
          if (settings.name == AppRoutes.home) {
            return MaterialPageRoute<void>(
              builder: (_) => const Scaffold(body: Text('Home Destination')),
              settings: settings,
            );
          }

          return MaterialPageRoute<void>(
            builder: (_) => PlanSelectionScreen(
              initialArgs: const {
                'platform': 'Blinkit',
                'zone': 'Bellandur',
                'pincode': '560103',
                'phone': '9000000000',
                'name': 'Nisha',
              },
              plansLoader: (_, {required zone, required platform}) async =>
                  plans,
              workerStatusLoader: (_) async =>
                  const WorkerStatus(phone: '9000000000', exists: false),
              registerUser:
                  (
                    _, {
                    required phone,
                    required platformName,
                    required zone,
                    required planName,
                    String? name,
                  }) async {
                    capturedPhone = phone;
                    capturedPlatform = platformName;
                    capturedZone = zone;
                    capturedPlan = planName;
                    return const User(
                      name: 'Nisha',
                      phone: '9000000000',
                      platform: 'Blinkit',
                      zone: 'Bellandur',
                      zonePincode: '560103',
                      plan: 'Premium',
                      policyId: 'PX-1',
                      totalEarnings: 0,
                      earningsProtected: 0,
                      isVerified: true,
                    );
                  },
            ),
            settings: settings,
          );
        },
      ),
    );

    await tester.pumpAndSettle();

    await tester.tap(find.text('Premium'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Activate for ₹89/week'));
    await tester.pumpAndSettle();

    expect(find.text('Home Destination'), findsOneWidget);
    expect(capturedPhone, equals('9000000000'));
    expect(capturedPlatform, equals('Blinkit'));
    expect(capturedZone, equals('560103'));
    expect(capturedPlan, equals('Premium'));
  });
}
