import 'package:flutter_test/flutter_test.dart';

import 'package:saatdin/models/claim_model.dart';
import 'package:saatdin/models/plan_model.dart';

void main() {
  group('Claim model', () {
    test('creates from valid data', () {
      final claim = Claim(
        id: '#C00001',
        type: ClaimType.rainLock,
        status: ClaimStatus.settled,
        amount: 400.0,
        date: DateTime(2026, 3, 15),
        description: 'Auto-settled: RainLock Heavy rainfall detected.',
      );

      expect(claim.id, '#C00001');
      expect(claim.type, ClaimType.rainLock);
      expect(claim.status, ClaimStatus.settled);
      expect(claim.amount, 400.0);
    });

    test('typeName maps correctly', () {
      final claim = Claim(
        id: '#C00002',
        type: ClaimType.aqiGuard,
        status: ClaimStatus.pending,
        amount: 300.0,
        date: DateTime(2026, 3, 16),
        description: 'AQI test',
      );
      expect(claim.typeName, 'Air Quality Alert');
      expect(claim.typeShortName, 'AQI Guard');
    });

    test('ClaimType values cover all trigger types', () {
      expect(ClaimType.values.length, 5);
      expect(ClaimType.values, contains(ClaimType.rainLock));
      expect(ClaimType.values, contains(ClaimType.aqiGuard));
      expect(ClaimType.values, contains(ClaimType.trafficBlock));
      expect(ClaimType.values, contains(ClaimType.zoneLock));
      expect(ClaimType.values, contains(ClaimType.heatBlock));
    });

    test('ClaimStatus values cover all states', () {
      expect(ClaimStatus.values.length, 5);
      expect(ClaimStatus.values, contains(ClaimStatus.pending));
      expect(ClaimStatus.values, contains(ClaimStatus.inReview));
      expect(ClaimStatus.values, contains(ClaimStatus.escalated));
      expect(ClaimStatus.values, contains(ClaimStatus.settled));
      expect(ClaimStatus.values, contains(ClaimStatus.rejected));
    });

    test('statusLabel returns readable text', () {
      final claim = Claim(
        id: '#C00003',
        type: ClaimType.zoneLock,
        status: ClaimStatus.inReview,
        amount: 400.0,
        date: DateTime(2026, 3, 17),
        description: 'Zone test',
      );
      expect(claim.statusLabel, 'In Review');
    });
  });

  group('InsurancePlan model', () {
    test('parses from JSON', () {
      final json = {
        'name': 'Standard',
        'weeklyPremium': 55,
        'perTriggerPayout': 400,
        'maxDaysPerWeek': 3,
        'isPopular': true,
      };

      final plan = InsurancePlan.fromJson(json);
      expect(plan.name, 'Standard');
      expect(plan.weeklyPremium, 55);
      expect(plan.perTriggerPayout, 400);
      expect(plan.maxDaysPerWeek, 3);
      expect(plan.isPopular, true);
    });

    test('getPlans returns three tiers', () {
      final plans = InsurancePlan.getPlans();
      expect(plans.length, 3);
      expect(plans[0].name, 'Basic');
      expect(plans[1].name, 'Standard');
      expect(plans[2].name, 'Premium');
    });

    test('Standard plan is popular', () {
      final plans = InsurancePlan.getPlans();
      final standard = plans.firstWhere((p) => p.name == 'Standard');
      expect(standard.isPopular, true);
    });

    test('toJson round-trips correctly', () {
      final plan = InsurancePlan(
        name: 'Test',
        weeklyPremium: 30,
        perTriggerPayout: 200,
        maxDaysPerWeek: 2,
        isPopular: false,
      );
      final json = plan.toJson();
      final roundTripped = InsurancePlan.fromJson(json);
      expect(roundTripped.name, plan.name);
      expect(roundTripped.weeklyPremium, plan.weeklyPremium);
    });
  });
}
