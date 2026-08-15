import 'package:flutter_test/flutter_test.dart';

import 'package:saatdin/models/claim_model.dart';
import 'package:saatdin/models/plan_model.dart';
import 'package:saatdin/models/payment_order_model.dart';

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

    test('parses backend snake_case fields', () {
      final plan = InsurancePlan.fromJson(const {
        'name': 'Premium',
        'weekly_premium': 88,
        'per_trigger_payout': 550,
        'max_days_per_week': 4,
        'is_popular': false,
      });

      expect(plan.weeklyPremium, 88);
      expect(plan.perTriggerPayout, 550);
      expect(plan.maxDaysPerWeek, 4);
      expect(plan.isPopular, false);
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

  group('PaymentOrder model', () {
    test('parses verified payment order response', () {
      final order = PaymentOrder.fromJson(const {
        'orderId': '63c40536-b23a-4d52-8360-1a08454dcd10',
        'status': 'PENDING',
        'provider': 'sandbox',
        'amount': '75.00',
        'currency': 'INR',
        'coverageWeekStart': '2026-08-17',
        'expiresAt': '2026-08-15T08:15:00Z',
        'checkoutData': {'providerOrderId': 'sandbox-order-1'},
      });

      expect(order.id, '63c40536-b23a-4d52-8360-1a08454dcd10');
      expect(order.amount, 75.0);
      expect(order.isPending, isTrue);
      expect(order.isPaid, isFalse);
      expect(order.coverageWeekStart, DateTime.utc(2026, 8, 17));
    });

    test('rejects unknown status', () {
      expect(
        () => PaymentOrder.fromJson(const {
          'orderId': '63c40536-b23a-4d52-8360-1a08454dcd10',
          'status': 'SETTLED',
          'provider': 'sandbox',
          'amount': 75,
          'currency': 'INR',
          'coverageWeekStart': '2026-08-17',
          'expiresAt': '2026-08-15T08:15:00Z',
          'checkoutData': <String, dynamic>{},
        }),
        throwsFormatException,
      );
    });
  });
}
