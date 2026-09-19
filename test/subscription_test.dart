import 'package:flutter_test/flutter_test.dart';
import 'package:projectbtt/features/subscription/domain/models/company_subscription_model.dart';
import 'package:projectbtt/features/subscription/domain/models/subscription_duration_type.dart';
import 'package:projectbtt/features/subscription/domain/models/subscription_plan_config.dart';
import 'package:projectbtt/features/subscription/domain/services/subscription_service.dart';

void main() {
  group('Subscription Duration Configurations', () {
    test('Initial plans are configured without hardcoded prices', () {
      final plans = CentralizedSubscriptionConfig.initialPlans;
      expect(plans.length, equals(4));

      final planNames = plans.map((p) => p.planName).toList();
      expect(planNames, containsAll(['1 Month', '3 Months', '6 Months', '1 Year']));

      for (final plan in plans) {
        expect(plan.price, isNull);
      }
    });

    test('SubscriptionDurationType maps labels correctly', () {
      expect(SubscriptionDurationType.fromLabel('1 Month'), equals(SubscriptionDurationType.oneMonth));
      expect(SubscriptionDurationType.fromLabel('3 Months'), equals(SubscriptionDurationType.threeMonths));
      expect(SubscriptionDurationType.fromLabel('6 Months'), equals(SubscriptionDurationType.sixMonths));
      expect(SubscriptionDurationType.fromLabel('1 Year'), equals(SubscriptionDurationType.oneYear));
    });
  });

  group('Calendar-Based Expiry Calculation for All 4 Durations', () {
    final baseDate = DateTime(2026, 3, 15, 10, 30, 0);

    test('1 Month duration calculates expiry 1 month from start date', () {
      final expiry = SubscriptionService.calculateExpiryDate(baseDate, SubscriptionDurationType.oneMonth);
      expect(expiry, equals(DateTime(2026, 4, 15, 10, 30, 0)));
    });

    test('3 Months duration calculates expiry 3 months from start date', () {
      final expiry = SubscriptionService.calculateExpiryDate(baseDate, SubscriptionDurationType.threeMonths);
      expect(expiry, equals(DateTime(2026, 6, 15, 10, 30, 0)));
    });

    test('6 Months duration calculates expiry 6 months from start date', () {
      final expiry = SubscriptionService.calculateExpiryDate(baseDate, SubscriptionDurationType.sixMonths);
      expect(expiry, equals(DateTime(2026, 9, 15, 10, 30, 0)));
    });

    test('1 Year duration calculates expiry 1 year from start date', () {
      final expiry = SubscriptionService.calculateExpiryDate(baseDate, SubscriptionDurationType.oneYear);
      expect(expiry, equals(DateTime(2027, 3, 15, 10, 30, 0)));
    });

    test('Handles month-end day rollover correctly (e.g. Jan 31 + 1 month -> Feb 28)', () {
      final jan31 = DateTime(2026, 1, 31, 12, 0, 0);
      final expiry = SubscriptionService.calculateExpiryDate(jan31, SubscriptionDurationType.oneMonth);
      expect(expiry, equals(DateTime(2026, 2, 28, 12, 0, 0)));
    });

    test('Handles leap year day rollover correctly (e.g. Feb 29 leap year + 1 year -> Feb 28 non-leap)', () {
      final leapFeb29 = DateTime(2024, 2, 29, 12, 0, 0);
      final expiry = SubscriptionService.calculateExpiryDate(leapFeb29, SubscriptionDurationType.oneYear);
      expect(expiry, equals(DateTime(2025, 2, 28, 12, 0, 0)));
    });
  });

  group('Active / Expired Status Calculation', () {
    test('Status is Active when current time is before expiry date', () {
      final startDate = DateTime(2026, 1, 1);
      final expiryDate = DateTime(2026, 2, 1);

      final model = CompanySubscriptionModel(
        id: 'sub_123',
        companyId: 'comp_001',
        planId: 'basic',
        planName: 'Basic',
        subscriptionPlan: '1 Month',
        startDate: startDate,
        expiryDate: expiryDate,
      );

      final beforeExpiry = DateTime(2026, 1, 20);
      expect(model.getStatusAt(beforeExpiry), equals('Active'));
    });

    test('Status is Expired when current time is on or after expiry date', () {
      final startDate = DateTime(2026, 1, 1);
      final expiryDate = DateTime(2026, 2, 1);

      final model = CompanySubscriptionModel(
        id: 'sub_123',
        companyId: 'comp_001',
        planId: 'basic',
        planName: 'Basic',
        subscriptionPlan: '1 Month',
        startDate: startDate,
        expiryDate: expiryDate,
      );

      final exactExpiry = DateTime(2026, 2, 1);
      final afterExpiry = DateTime(2026, 2, 2);

      expect(model.getStatusAt(exactExpiry), equals('Expired'));
      expect(model.getStatusAt(afterExpiry), equals('Expired'));
    });
  });

  group('Company Isolation & Model Serialization / Backward Compatibility', () {
    test('CompanySubscriptionModel serializes and deserializes correctly', () {
      final now = DateTime(2026, 3, 17, 10, 0, 0);
      final expiry = DateTime(2026, 6, 17, 10, 0, 0);

      final sub = CompanySubscriptionModel(
        id: 'current',
        companyId: 'company_abc',
        planId: 'pro',
        planName: 'Professional',
        subscriptionPlan: '3 Months',
        startDate: now,
        expiryDate: expiry,
      );

      final map = sub.toMap();
      expect(map['companyId'], equals('company_abc'));
      expect(map['subscriptionPlan'], equals('3 Months'));
      expect(map['status'], equals(sub.status));

      final restored = CompanySubscriptionModel.fromMap({
        'companyId': 'company_abc',
        'subscriptionPlan': '3 Months',
        'startDate': now.toIso8601String(),
        'expiryDate': expiry.toIso8601String(),
      }, 'current');

      expect(restored.companyId, equals('company_abc'));
      expect(restored.subscriptionPlan, equals('3 Months'));
      expect(restored.startDate, equals(now));
      expect(restored.expiryDate, equals(expiry));
    });

    test('Handles missing fields safely for backward compatibility', () {
      final fallbackModel = CompanySubscriptionModel.fromMap({}, 'current');

      expect(fallbackModel.id, equals('current'));
      expect(fallbackModel.companyId, equals(''));
      expect(fallbackModel.subscriptionPlan, equals('1 Month'));
      expect(fallbackModel.startDate, isA<DateTime>());
      expect(fallbackModel.expiryDate, isA<DateTime>());
      expect(fallbackModel.status, equals('Active'));
    });
  });
}
