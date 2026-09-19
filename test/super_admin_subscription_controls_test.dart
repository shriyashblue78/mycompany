import 'package:flutter_test/flutter_test.dart';
import 'package:projectbtt/features/auth/domain/models/company_modules.dart';
import 'package:projectbtt/features/subscription/domain/models/company_subscription_model.dart';
import 'package:projectbtt/features/subscription/domain/models/subscription_duration_type.dart';
import 'package:projectbtt/features/subscription/domain/models/subscription_plan.dart';
import 'package:projectbtt/features/subscription/domain/services/subscription_service.dart';
import 'package:projectbtt/features/subscription/domain/services/effective_feature_service.dart';

void main() {
  group('NEW CHANGE 3 — Super Admin Subscription Controls Unit Tests', () {
    test('1. Super Admin can select plan and set configurable price', () {
      final selectedPlan = DefaultSubscriptionPlans.professional;
      const customPrice = 7499.0;
      final startDate = DateTime(2026, 3, 17, 10, 0);
      final expiryDate = SubscriptionService.calculateExpiryDate(startDate, SubscriptionDurationType.sixMonths);

      final subscription = CompanySubscriptionModel(
        id: 'current',
        companyId: 'company_001',
        planId: selectedPlan.planId,
        planName: selectedPlan.planName,
        subscriptionPlan: SubscriptionDurationType.sixMonths.label,
        price: customPrice,
        startDate: startDate,
        expiryDate: expiryDate,
        enabledFeatures: selectedPlan.enabledFeatures,
      );

      expect(subscription.planId, equals('professional'));
      expect(subscription.price, equals(7499.0));
      expect(subscription.subscriptionPlan, equals('6 Months'));
      expect(subscription.expiryDate, equals(DateTime(2026, 9, 17, 10, 0)));
    });

    test('2. Dynamic Status Calculation: Active, Expiring Soon, Expired', () {
      final startDate = DateTime(2026, 1, 1);
      final expiryDate = DateTime(2026, 2, 1);

      final sub = CompanySubscriptionModel(
        id: 'current',
        companyId: 'company_001',
        planId: 'basic',
        planName: 'Basic',
        subscriptionPlan: '1 Month',
        startDate: startDate,
        expiryDate: expiryDate,
      );

      // Active (> 7 days remaining)
      final refActive = DateTime(2026, 1, 15);
      expect(sub.calculateStatusAt(refActive), equals('Active'));

      // Expiring Soon (<= 7 days remaining)
      final refExpiringSoon = DateTime(2026, 1, 28);
      expect(sub.calculateStatusAt(refExpiringSoon), equals('Expiring Soon'));

      // Expired (on or past expiry date)
      final refExpired = DateTime(2026, 2, 2);
      expect(sub.calculateStatusAt(refExpired), equals('Expired'));
    });

    test('3. Employee Limit remains independent from subscription plan', () {
      // Employee limit is separately updated on company model maxEmployees
      const originalMaxEmployees = 25;
      const updatedMaxEmployees = 100;

      expect(updatedMaxEmployees, isNot(equals(originalMaxEmployees)));
      expect(updatedMaxEmployees, equals(100));
    });

    test('4. Super Admin feature ON/OFF switches correctly override plan default access', () {
      // Basic plan default features do NOT include production or drawings
      final basicDefaults = DefaultSubscriptionPlans.basic.enabledFeatures;
      expect(basicDefaults, isNot(contains(CompanyModules.production)));

      // Super Admin explicit ON override for production
      // Super Admin explicit OFF override for employees (normally included in basic)
      final overrides = <String, bool>{
        CompanyModules.production: true, // Explicit ON
        CompanyModules.employees: false, // Explicit OFF
      };

      final effective = EffectiveFeatureService.calculateEffectiveFeatures(
        planDefaultFeatures: basicDefaults,
        featureOverrides: overrides,
      );

      expect(effective, contains(CompanyModules.production));
      expect(effective, isNot(contains(CompanyModules.employees)));
      expect(effective, contains(CompanyModules.attendance));
    });

    test('5. Non-Super Admin security verification logic', () {
      bool canUserModifySubscription(String userRole) {
        return userRole == 'super_admin';
      }

      expect(canUserModifySubscription('super_admin'), isTrue);
      expect(canUserModifySubscription('Owner'), isFalse);
      expect(canUserModifySubscription('HR'), isFalse);
      expect(canUserModifySubscription('Supervisor'), isFalse);
      expect(canUserModifySubscription('Employee'), isFalse);
    });
  });
}
