enum SubscriptionDurationType {
  oneMonth(1, '1 Month'),
  threeMonths(3, '3 Months'),
  sixMonths(6, '6 Months'),
  oneYear(12, '1 Year');

  final int monthCount;
  final String label;

  const SubscriptionDurationType(this.monthCount, this.label);

  static SubscriptionDurationType fromLabel(String label) {
    final normalized = label.trim().toLowerCase();
    for (final duration in SubscriptionDurationType.values) {
      if (duration.label.toLowerCase() == normalized) {
        return duration;
      }
    }
    // Fallback search by month count or default to one month
    if (normalized.contains('3')) return SubscriptionDurationType.threeMonths;
    if (normalized.contains('6')) return SubscriptionDurationType.sixMonths;
    if (normalized.contains('year') || normalized.contains('12')) {
      return SubscriptionDurationType.oneYear;
    }
    return SubscriptionDurationType.oneMonth;
  }
}
