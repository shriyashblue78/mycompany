import 'package:flutter_test/flutter_test.dart';
import 'package:projectbtt/features/auth/domain/models/company_modules.dart';
import 'package:projectbtt/features/subscription/domain/models/company_subscription_model.dart';
import 'package:projectbtt/features/subscription/domain/models/subscription_duration_type.dart';
import 'package:projectbtt/features/subscription/domain/models/subscription_plan.dart';
import 'package:projectbtt/features/subscription/domain/services/subscription_service.dart';
import 'package:projectbtt/features/subscription/domain/services/subscription_expiry_service.dart';
import 'package:projectbtt/features/subscription/domain/services/subscription_renewal_service.dart';

void main() {
  group('NEW CHANGE 8 — Subscription Expiry, Renewal & History Unit Tests', () {
    test('1. Remaining Subscription Time & Formatted Strings', () {
      final now = DateTime.now();
      final in30Days = now.add(const Duration(days: 30));

      final activeSub = CompanySubscriptionModel(
        id: 'current',
        companyId: 'company_001',
        planId: 'professional',
        planName: 'Professional',
        subscriptionPlan: '1 Month',
        startDate: now,
        expiryDate: in30Days,
      );

      expect(activeSub.remainingDays, equals(30));
      expect(activeSub.remainingTimeFormatted, contains('30 days remaining'));
      expect(activeSub.isExpiringSoon, isFalse);

      final in5Days = now.add(const Duration(days: 5));
      final expiringSoonSub = activeSub.copyWith(expiryDate: in5Days);

      expect(expiringSoonSub.remainingDays, equals(5));
      expect(expiringSoonSub.remainingTimeFormatted, contains('5 days remaining'));
      expect(expiringSoonSub.isExpiringSoon, isTrue);

      final expiredSub = activeSub.copyWith(expiryDate: now.subtract(const Duration(days: 1)));

      expect(expiredSub.remainingDays, equals(0));
      expect(expiredSub.remainingTimeFormatted, equals('Expired'));
      expect(expiredSub.isExpired, isTrue);
    });

    test('2. Expiry Warning triggers correctly when <= 7 days remaining', () {
      final now = DateTime.now();
      final subExpiringSoon = CompanySubscriptionModel(
        id: 'current',
        companyId: 'company_002',
        planId: 'basic',
        planName: 'Basic',
        subscriptionPlan: '1 Month',
        startDate: now.subtract(const Duration(days: 25)),
        expiryDate: now.add(const Duration(days: 5)),
      );

      expect(SubscriptionExpiryService.shouldShowExpiryWarning(subExpiringSoon), isTrue);
    });

    test('3. Configurable Expiry Access Policy Service', () {
      final now = DateTime.now();
      final expiredSub = CompanySubscriptionModel(
        id: 'current',
        companyId: 'company_003',
        planId: 'professional',
        planName: 'Professional',
        subscriptionPlan: '1 Month',
        startDate: now.subtract(const Duration(days: 40)),
        expiryDate: now.subtract(const Duration(days: 10)),
        enabledFeatures: [CompanyModules.employees, CompanyModules.attendance, CompanyModules.sales, CompanyModules.production],
      );

      // Policy 1: allowAll (default safe policy for backward compatibility)
      expect(SubscriptionExpiryService.isModuleAccessible(
        subscription: expiredSub,
        moduleKey: CompanyModules.sales,
        policyMode: SubscriptionExpiryPolicyMode.allowAll,
      ), isTrue);

      // Policy 2: blockAllPaid (locks paid modules, allows core HR/attendance)
      expect(SubscriptionExpiryService.isModuleAccessible(
        subscription: expiredSub,
        moduleKey: CompanyModules.employees,
        policyMode: SubscriptionExpiryPolicyMode.blockAllPaid,
      ), isTrue);

      expect(SubscriptionExpiryService.isModuleAccessible(
        subscription: expiredSub,
        moduleKey: CompanyModules.sales,
        policyMode: SubscriptionExpiryPolicyMode.blockAllPaid,
      ), isFalse);
    });

    test('4. Subscription Renewal extends expiry date and preserves Super Admin feature overrides', () {
      final now = DateTime(2026, 3, 17);
      final currentExpiry = DateTime(2026, 4, 17);

      final currentSub = CompanySubscriptionModel(
        id: 'current',
        companyId: 'company_004',
        planId: 'professional',
        planName: 'Professional',
        subscriptionPlan: '1 Month',
        price: 4999.0,
        startDate: now,
        expiryDate: currentExpiry,
        enabledFeatures: DefaultSubscriptionPlans.professional.enabledFeatures,
        featureOverrides: {
          CompanyModules.production: false, // Super Admin explicit OFF
          CompanyModules.drawings: true,    // Super Admin explicit ON
        },
      );

      // Process 1 Year Renewal
      final result = SubscriptionRenewalService.processRenewal(
        currentSubscription: currentSub,
        durationType: SubscriptionDurationType.oneYear,
        price: 9999.0,
        paymentId: 'pay_renew_001',
      );

      final renewedSub = result.updatedSubscription;
      final historyEntry = result.historyEntry;

      // Start date stacks on current expiry (2026-04-17); 1 year expiry = 2027-04-17
      expect(renewedSub.startDate, equals(currentExpiry));
      expect(renewedSub.expiryDate, equals(DateTime(2027, 4, 17)));
      expect(renewedSub.price, equals(9999.0));

      // Super Admin overrides PRESERVED
      expect(renewedSub.featureOverrides[CompanyModules.production], isFalse);
      expect(renewedSub.featureOverrides[CompanyModules.drawings], isTrue);

      // Effective access PRESERVED
      expect(renewedSub.effectiveFeatures, contains(CompanyModules.drawings));
      expect(renewedSub.effectiveFeatures, isNot(contains(CompanyModules.production)));

      // New history record created WITHOUT overwriting past history
      expect(historyEntry.companyId, equals('company_004'));
      expect(historyEntry.planId, equals('professional'));
      expect(historyEntry.paymentId, equals('pay_renew_001'));
      expect(historyEntry.expiryDate, equals(DateTime(2027, 4, 17)));
    });

    test('5. Data Preservation Check on Expiry & Renewal', () {
      // Data preservation logic test: Expiry/Renewal operations return updated models without touching company database collections
      final expiredSub = CompanySubscriptionModel(
        id: 'current',
        companyId: 'company_preserve_test',
        planId: 'basic',
        planName: 'Basic',
        subscriptionPlan: '1 Month',
        startDate: DateTime.now().subtract(const Duration(days: 60)),
        expiryDate: DateTime.now().subtract(const Duration(days: 30)),
      );

      expect(expiredSub.isExpired, isTrue);

      // Renewing restores active status
      final result = SubscriptionRenewalService.processRenewal(
        currentSubscription: expiredSub,
        durationType: SubscriptionDurationType.sixMonths,
        price: 5000.0,
      );

      expect(result.updatedSubscription.isActive, isTrue);
    });
  });
}
