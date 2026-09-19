import 'subscription_duration_type.dart';

class SubscriptionPlanConfig {
  final String id;
  final String planName;
  final SubscriptionDurationType durationType;
  final double? price;

  const SubscriptionPlanConfig({
    required this.id,
    required this.planName,
    required this.durationType,
    this.price,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'planName': planName,
      'durationLabel': durationType.label,
      'monthCount': durationType.monthCount,
      'price': price,
    };
  }

  factory SubscriptionPlanConfig.fromMap(Map<String, dynamic> map) {
    final label = (map['durationLabel'] ?? map['planName'] ?? '1 Month') as String;
    return SubscriptionPlanConfig(
      id: (map['id'] ?? '') as String,
      planName: (map['planName'] ?? label) as String,
      durationType: SubscriptionDurationType.fromLabel(label),
      price: (map['price'] as num?)?.toDouble(),
    );
  }
}

class CentralizedSubscriptionConfig {
  static const List<SubscriptionPlanConfig> initialPlans = [
    SubscriptionPlanConfig(
      id: 'plan_1_month',
      planName: '1 Month',
      durationType: SubscriptionDurationType.oneMonth,
      price: null,
    ),
    SubscriptionPlanConfig(
      id: 'plan_3_months',
      planName: '3 Months',
      durationType: SubscriptionDurationType.threeMonths,
      price: null,
    ),
    SubscriptionPlanConfig(
      id: 'plan_6_months',
      planName: '6 Months',
      durationType: SubscriptionDurationType.sixMonths,
      price: null,
    ),
    SubscriptionPlanConfig(
      id: 'plan_1_year',
      planName: '1 Year',
      durationType: SubscriptionDurationType.oneYear,
      price: null,
    ),
  ];
}
