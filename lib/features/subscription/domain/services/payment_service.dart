import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/payment_transaction_model.dart';
import '../models/subscription_plan.dart';
import '../models/company_subscription_model.dart';
import '../models/subscription_history_model.dart';
import '../models/subscription_duration_type.dart';
import 'subscription_service.dart';
import 'effective_feature_service.dart';

class PaymentService {
  /// Create a new modular PaymentTransactionModel in 'pending' (integration ready) status.
  static PaymentTransactionModel createPendingPayment({
    required String companyId,
    required SubscriptionPlan plan,
    required SubscriptionDurationType duration,
    required double calculatedAmount,
  }) {
    final paymentId = FirebaseFirestore.instance.collection('companies').doc().id;

    return PaymentTransactionModel(
      paymentId: paymentId,
      companyId: companyId,
      planId: plan.planId,
      planName: plan.planName,
      durationLabel: duration.label,
      amount: calculatedAmount,
      currency: 'INR',
      status: PaymentStatus.pending,
      paymentGateway: 'Pending Gateway Integration',
      createdAt: DateTime.now(),
    );
  }

  /// Activates subscription upon confirmed payment, preserving existing Super Admin feature overrides.
  static CompanySubscriptionModel activateSubscriptionFromPayment({
    required PaymentTransactionModel payment,
    required SubscriptionPlan plan,
    Map<String, bool> existingOverrides = const {},
    DateTime? startDateOverride,
  }) {
    final start = startDateOverride ?? DateTime.now();
    final durationType = SubscriptionDurationType.fromLabel(payment.durationLabel);
    final expiry = SubscriptionService.calculateExpiryDate(start, durationType);

    // Compute effective features (PLAN DEFAULT -> COMPANY OVERRIDE -> EFFECTIVE ACCESS)
    final effectiveFeatures = EffectiveFeatureService.calculateEffectiveFeatures(
      planDefaultFeatures: plan.enabledFeatures,
      featureOverrides: existingOverrides,
    );

    return CompanySubscriptionModel(
      id: 'current',
      companyId: payment.companyId,
      planId: plan.planId,
      planName: plan.planName,
      subscriptionPlan: payment.durationLabel,
      price: payment.amount,
      startDate: start,
      expiryDate: expiry,
      enabledFeatures: plan.enabledFeatures,
      featureOverrides: existingOverrides,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
  }

  /// Create a SubscriptionHistoryModel entry for historical auditing.
  static SubscriptionHistoryModel createHistoryEntry({
    required CompanySubscriptionModel subscription,
    required String paymentId,
  }) {
    final historyId = FirebaseFirestore.instance.collection('companies').doc().id;

    return SubscriptionHistoryModel(
      historyId: historyId,
      companyId: subscription.companyId,
      planId: subscription.planId,
      planName: subscription.planName,
      durationLabel: subscription.subscriptionPlan,
      price: subscription.price,
      startDate: subscription.startDate,
      expiryDate: subscription.expiryDate,
      paymentId: paymentId,
      status: subscription.status,
      createdAt: DateTime.now(),
    );
  }
}
