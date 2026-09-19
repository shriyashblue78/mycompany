import '../models/company_subscription_model.dart';
import '../../../auth/domain/models/company_modules.dart';

enum SubscriptionExpiryPolicyMode {
  allowAll,      // Default safe policy for backward compatibility (does not lock existing companies)
  blockAllPaid,  // Restricts all non-core paid modules upon expiry
  allowCoreOnly, // Restricts paid modules but allows core HR & attendance
  readOnly;      // Read-only mode for company data

  static SubscriptionExpiryPolicyMode fromString(String val) {
    return SubscriptionExpiryPolicyMode.values.firstWhere(
      (e) => e.name.toLowerCase() == val.trim().toLowerCase(),
      orElse: () => SubscriptionExpiryPolicyMode.allowAll,
    );
  }
}

class SubscriptionExpiryService {
  /// Calculate remaining days until subscription expiry.
  static int calculateRemainingDays(DateTime expiryDate) {
    final diff = expiryDate.difference(DateTime.now()).inDays;
    return diff < 0 ? 0 : diff;
  }

  /// Formatted remaining subscription time.
  static String formatRemainingTime(DateTime expiryDate) {
    if (!DateTime.now().isBefore(expiryDate)) {
      return 'Expired';
    }
    final days = calculateRemainingDays(expiryDate);
    if (days == 0) return 'Expiring Today';
    if (days == 1) return '1 day remaining';
    return '$days days remaining';
  }

  /// Evaluates whether an expiry warning should be displayed to the user (Expiring Soon: <= 7 days).
  static bool shouldShowExpiryWarning(CompanySubscriptionModel? subscription) {
    if (subscription == null) return false;
    return subscription.isExpiringSoon || subscription.isExpired;
  }

  /// Configurable module access evaluator based on expiry status and policy mode.
  static bool isModuleAccessible({
    required CompanySubscriptionModel? subscription,
    required String moduleKey,
    SubscriptionExpiryPolicyMode policyMode = SubscriptionExpiryPolicyMode.allowAll,
  }) {
    if (subscription == null) {
      return true; // Backward compatibility safe default
    }

    // Check base effective access (PLAN DEFAULT -> COMPANY OVERRIDE -> EFFECTIVE ACCESS)
    final isEffective = subscription.effectiveFeatures.contains(moduleKey);
    if (!isEffective) return false;

    // If active, module is accessible
    if (subscription.isActive) return true;

    // If expired, evaluate against configurable policy mode
    switch (policyMode) {
      case SubscriptionExpiryPolicyMode.allowAll:
        // Safe default: preserves existing behavior so existing companies are not unexpectedly locked
        return true;

      case SubscriptionExpiryPolicyMode.blockAllPaid:
        // Core basic modules remain accessible; paid extensions locked
        final coreModules = [CompanyModules.employees, CompanyModules.attendance, CompanyModules.leaves];
        return coreModules.contains(moduleKey);

      case SubscriptionExpiryPolicyMode.allowCoreOnly:
        final coreOnly = [CompanyModules.employees, CompanyModules.attendance];
        return coreOnly.contains(moduleKey);

      case SubscriptionExpiryPolicyMode.readOnly:
        // Handled at write-level; UI allows viewing
        return true;
    }
  }
}
