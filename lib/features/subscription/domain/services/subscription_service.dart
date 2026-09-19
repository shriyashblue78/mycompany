import '../models/company_subscription_model.dart';
import '../models/subscription_duration_type.dart';

class SubscriptionService {
  /// Proper calendar-based date calculation for subscription expiry.
  /// - 1 Month → automatically calculate expiry 1 month from start date
  /// - 3 Months → automatically calculate expiry 3 months from start date
  /// - 6 Months → automatically calculate expiry 6 months from start date
  /// - 1 Year → automatically calculate expiry 1 year from start date
  static DateTime calculateExpiryDate(DateTime startDate, SubscriptionDurationType durationType) {
    int year = startDate.year;
    int month = startDate.month + durationType.monthCount;
    int day = startDate.day;

    // Handle month overflow into future years
    year += (month - 1) ~/ 12;
    month = ((month - 1) % 12) + 1;

    // Handle calendar day rollover (e.g., Jan 31 + 1 month -> Feb 28/29)
    int daysInTargetMonth = DateTime(year, month + 1, 0).day;
    if (day > daysInTargetMonth) {
      day = daysInTargetMonth;
    }

    return DateTime(
      year,
      month,
      day,
      startDate.hour,
      startDate.minute,
      startDate.second,
      startDate.millisecond,
      startDate.microsecond,
    );
  }

  /// Create a new CompanySubscriptionModel with proper start date and calculated expiry date.
  static CompanySubscriptionModel createSubscription({
    required String id,
    required String companyId,
    required String subscriptionPlan,
    required SubscriptionDurationType durationType,
    String? planId,
    String? planName,
    double? price,
    DateTime? startDate,
  }) {
    final start = startDate ?? DateTime.now();
    final expiry = calculateExpiryDate(start, durationType);

    return CompanySubscriptionModel(
      id: id,
      companyId: companyId,
      planId: planId ?? 'basic',
      planName: planName ?? subscriptionPlan,
      subscriptionPlan: subscriptionPlan,
      price: price,
      startDate: start,
      expiryDate: expiry,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
  }

  /// Automatically determine subscription status:
  /// - Active → current date/time is before expiry
  /// - Expired → current date/time has reached/passed expiry
  static String determineStatus(DateTime expiryDate, {DateTime? referenceDate}) {
    final ref = referenceDate ?? DateTime.now();
    return ref.isBefore(expiryDate) ? 'Active' : 'Expired';
  }
}
