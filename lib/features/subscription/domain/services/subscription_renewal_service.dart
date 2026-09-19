import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/company_subscription_model.dart';
import '../models/subscription_duration_type.dart';
import '../models/subscription_history_model.dart';
import 'subscription_service.dart';

class RenewalResult {
  final CompanySubscriptionModel updatedSubscription;
  final SubscriptionHistoryModel historyEntry;

  const RenewalResult({
    required this.updatedSubscription,
    required this.historyEntry,
  });
}

class SubscriptionRenewalService {
  /// Processes a confirmed subscription renewal:
  /// 1. Calculates new start and expiry dates cleanly using calendar math.
  /// 2. Extends active subscription if currently active, or starts fresh if expired.
  /// 3. Preserves all company data and Super Admin feature overrides.
  /// 4. Creates a NEW SubscriptionHistoryModel entry without overwriting historical records.
  static RenewalResult processRenewal({
    required CompanySubscriptionModel currentSubscription,
    required SubscriptionDurationType durationType,
    required double price,
    String? paymentId,
    String actionType = 'Renewal',
  }) {
    final now = DateTime.now();

    // If currently active, stack renewal from current expiry date; if expired, start from now
    final newStartDate = currentSubscription.isActive ? currentSubscription.expiryDate : now;
    final newExpiryDate = SubscriptionService.calculateExpiryDate(newStartDate, durationType);

    final updatedSubscription = currentSubscription.copyWith(
      subscriptionPlan: durationType.label,
      price: price,
      startDate: newStartDate,
      expiryDate: newExpiryDate,
      updatedAt: now,
    );

    final historyId = FirebaseFirestore.instance.collection('companies').doc().id;
    final historyEntry = SubscriptionHistoryModel(
      historyId: historyId,
      companyId: currentSubscription.companyId,
      planId: currentSubscription.planId,
      planName: currentSubscription.planName,
      durationLabel: durationType.label,
      price: price,
      startDate: newStartDate,
      expiryDate: newExpiryDate,
      paymentId: paymentId,
      status: 'Active ($actionType)',
      createdAt: now,
    );

    return RenewalResult(
      updatedSubscription: updatedSubscription,
      historyEntry: historyEntry,
    );
  }
}
