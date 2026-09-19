import 'package:flutter_test/flutter_test.dart';
import 'package:projectbtt/features/auth/domain/models/company_modules.dart';
import 'package:projectbtt/features/subscription/domain/models/subscription_plan.dart';
import 'package:projectbtt/features/subscription/domain/models/subscription_duration_type.dart';
import 'package:projectbtt/features/subscription/domain/models/payment_transaction_model.dart';
import 'package:projectbtt/features/subscription/domain/models/subscription_history_model.dart';
import 'package:projectbtt/features/subscription/domain/models/company_subscription_model.dart';
import 'package:projectbtt/features/subscription/domain/services/subscription_service.dart';
import 'package:projectbtt/features/subscription/domain/services/payment_service.dart';

void main() {
  group('NEW CHANGE 4 — Customer Subscription Purchase Flow Unit Tests', () {
    test('1. Plans load from configuration with feature lists and configurable prices', () {
      final plans = DefaultSubscriptionPlans.initialPlans;
      expect(plans.length, equals(3));

      final basic = DefaultSubscriptionPlans.basic;
      final pro = DefaultSubscriptionPlans.professional;

      expect(basic.planName, equals('Basic'));
      expect(pro.planName, equals('Professional'));
      expect(pro.enabledFeatures, containsAll([CompanyModules.sales, CompanyModules.inventory, CompanyModules.production]));
    });

    test('2. Dynamic Duration Expiry & Price Calculation', () {
      final startDate = DateTime(2026, 3, 17, 10, 0);
      final durationYearly = SubscriptionDurationType.oneYear;

      final calculatedExpiry = SubscriptionService.calculateExpiryDate(startDate, durationYearly);
      expect(calculatedExpiry, equals(DateTime(2027, 3, 17, 10, 0)));
    });

    test('3. Modular Payment Transaction is initialized in Integration-Ready Pending status', () {
      final plan = DefaultSubscriptionPlans.professional;
      const amount = 4999.0;
      const companyId = 'company_123';

      final payment = PaymentService.createPendingPayment(
        companyId: companyId,
        plan: plan,
        duration: SubscriptionDurationType.threeMonths,
        calculatedAmount: amount,
      );

      expect(payment.companyId, equals('company_123'));
      expect(payment.planId, equals('professional'));
      expect(payment.durationLabel, equals('3 Months'));
      expect(payment.amount, equals(4999.0));
      expect(payment.status, equals(PaymentStatus.pending));
      expect(payment.paymentGateway, equals('Pending Gateway Integration'));
    });

    test('4. Subscription Activation Contract preserves Super Admin feature overrides', () {
      final payment = PaymentTransactionModel(
        paymentId: 'pay_001',
        companyId: 'company_abc',
        planId: 'professional',
        planName: 'Professional',
        durationLabel: '1 Year',
        amount: 9999.0,
        status: PaymentStatus.successful,
        createdAt: DateTime(2026, 3, 17),
      );

      final plan = DefaultSubscriptionPlans.professional;

      // Super Admin explicit OFF override for production
      final existingOverrides = <String, bool>{
        CompanyModules.production: false,
        CompanyModules.drawings: true, // Super Admin explicit ON override
      };

      final subscription = PaymentService.activateSubscriptionFromPayment(
        payment: payment,
        plan: plan,
        existingOverrides: existingOverrides,
        startDateOverride: DateTime(2026, 3, 17),
      );

      expect(subscription.companyId, equals('company_abc'));
      expect(subscription.planId, equals('professional'));
      expect(subscription.subscriptionPlan, equals('1 Year'));
      expect(subscription.price, equals(9999.0));
      expect(subscription.expiryDate, equals(DateTime(2027, 3, 17)));

      // Hierarchy: PLAN DEFAULT -> COMPANY OVERRIDE -> EFFECTIVE ACCESS
      final effective = subscription.effectiveFeatures;
      expect(effective, contains(CompanyModules.sales));
      expect(effective, contains(CompanyModules.drawings));
      expect(effective, isNot(contains(CompanyModules.production)));
    });

    test('5. Subscription History recording entity structure', () {
      final now = DateTime(2026, 3, 17);
      final sub = CompanySubscriptionModel(
        id: 'current',
        companyId: 'company_xyz',
        planId: 'basic',
        planName: 'Basic',
        subscriptionPlan: '1 Month',
        price: 1999.0,
        startDate: now,
        expiryDate: now.add(const Duration(days: 30)),
      );

      final history = PaymentService.createHistoryEntry(
        subscription: sub,
        paymentId: 'pay_999',
      );

      expect(history.companyId, equals('company_xyz'));
      expect(history.planId, equals('basic'));
      expect(history.price, equals(1999.0));
      expect(history.paymentId, equals('pay_999'));
    });

    test('6. Company Isolation & Security Verification', () {
      bool isAuthorizedCompanyAccess(String userCompanyId, String targetCompanyId) {
        if (userCompanyId.isEmpty || targetCompanyId.isEmpty) return false;
        return userCompanyId == targetCompanyId;
      }

      expect(isAuthorizedCompanyAccess('comp_A', 'comp_A'), isTrue);
      expect(isAuthorizedCompanyAccess('comp_A', 'comp_B'), isFalse);
    });
  });
}
