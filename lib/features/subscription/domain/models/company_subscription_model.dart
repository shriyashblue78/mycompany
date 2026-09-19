import 'package:cloud_firestore/cloud_firestore.dart';
import 'company_feature_access.dart';
import 'subscription_duration_type.dart';
import '../../../auth/domain/models/company_modules.dart';

class CompanySubscriptionModel {
  final String id;
  final String companyId;
  final String planId;
  final String planName;
  final String subscriptionPlan; // Duration label e.g. "3 Months"
  final double? price;
  final DateTime startDate;
  final DateTime expiryDate;
  final List<String> enabledFeatures;
  final Map<String, bool> featureOverrides;
  final List<String> addonFeatures;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const CompanySubscriptionModel({
    required this.id,
    required this.companyId,
    required this.planId,
    required this.planName,
    required this.subscriptionPlan,
    this.price,
    required this.startDate,
    required this.expiryDate,
    this.enabledFeatures = const [],
    this.featureOverrides = const {},
    this.addonFeatures = const [],
    this.createdAt,
    this.updatedAt,
  });

  /// Dynamic Status Evaluation:
  /// - Active → current date/time is before expiry and > 7 days remaining
  /// - Expiring Soon → current date/time is before expiry and <= 7 days remaining
  /// - Expired → current date/time has reached/passed expiry
  String get status => calculateStatusAt(DateTime.now());

  bool get isActive => DateTime.now().isBefore(expiryDate);
  bool get isExpired => !isActive;
  bool get isExpiringSoon => isActive && remainingDays <= 7;

  /// Calculated remaining days until expiry
  int get remainingDays {
    final diff = expiryDate.difference(DateTime.now()).inDays;
    return diff < 0 ? 0 : diff;
  }

  /// Formatted remaining subscription time
  String get remainingTimeFormatted {
    if (isExpired) return 'Expired';
    if (remainingDays == 0) return 'Expiring Today';
    if (remainingDays == 1) return '1 day remaining';
    return '$remainingDays days remaining';
  }

  /// Calculate precise status given a reference date/time
  String calculateStatusAt(DateTime referenceTime) {
    if (!referenceTime.isBefore(expiryDate)) {
      return 'Expired';
    }
    final difference = expiryDate.difference(referenceTime);
    if (difference.inDays <= 7) {
      return 'Expiring Soon';
    }
    return 'Active';
  }

  String getStatusAt(DateTime referenceTime) => calculateStatusAt(referenceTime);

  /// Calculates effective features following:
  /// PLAN DEFAULT → COMPANY OVERRIDE → EFFECTIVE FEATURE ACCESS
  List<String> get effectiveFeatures {
    final access = CompanyFeatureAccess(
      companyId: companyId,
      planId: planId,
      planDefaultFeatures: enabledFeatures,
      featureOverrides: featureOverrides,
    );
    final base = access.effectiveFeatures;
    if (addonFeatures.isEmpty) return base;
    return (Set<String>.from(base)..addAll(addonFeatures)).toList();
  }

  factory CompanySubscriptionModel.fromMap(Map<String, dynamic> map, String docId) {
    DateTime parseDate(dynamic value, DateTime fallback) {
      if (value == null) return fallback;
      if (value is Timestamp) return value.toDate();
      if (value is String) return DateTime.tryParse(value) ?? fallback;
      return fallback;
    }

    final now = DateTime.now();
    final start = parseDate(map['startDate'], now);
    final planStr = (map['subscriptionPlan'] ?? map['planName'] ?? '1 Month') as String;
    final planIdStr = (map['planId'] ?? 'basic') as String;
    final planNameStr = (map['planName'] ?? planStr) as String;

    final defaultExpiry = map['expiryDate'] != null
        ? parseDate(map['expiryDate'], now)
        : _calculateExpiryFallback(start, planStr);

    final featuresRaw = map['enabledFeatures'] as List?;
    final enabledFeatures = featuresRaw != null
        ? List<String>.from(featuresRaw)
        : List<String>.from(CompanyModules.all);

    final overridesRaw = map['featureOverrides'] as Map?;
    final featureOverrides = overridesRaw != null
        ? overridesRaw.map((k, v) => MapEntry(k.toString(), v == true))
        : <String, bool>{};

    final addonsRaw = map['addonFeatures'] as List?;
    final addonFeatures = addonsRaw != null ? List<String>.from(addonsRaw) : <String>[];

    return CompanySubscriptionModel(
      id: docId,
      companyId: (map['companyId'] ?? '') as String,
      planId: planIdStr,
      planName: planNameStr,
      subscriptionPlan: planStr,
      price: (map['price'] as num?)?.toDouble(),
      startDate: start,
      expiryDate: defaultExpiry,
      enabledFeatures: enabledFeatures,
      featureOverrides: featureOverrides,
      addonFeatures: addonFeatures,
      createdAt: map['createdAt'] != null ? parseDate(map['createdAt'], now) : null,
      updatedAt: map['updatedAt'] != null ? parseDate(map['updatedAt'], now) : null,
    );
  }

  static DateTime _calculateExpiryFallback(DateTime start, String planLabel) {
    final durationType = SubscriptionDurationType.fromLabel(planLabel);
    int year = start.year;
    int month = start.month + durationType.monthCount;
    int day = start.day;

    year += (month - 1) ~/ 12;
    month = ((month - 1) % 12) + 1;

    int daysInTargetMonth = DateTime(year, month + 1, 0).day;
    if (day > daysInTargetMonth) {
      day = daysInTargetMonth;
    }

    return DateTime(
      year,
      month,
      day,
      start.hour,
      start.minute,
      start.second,
      start.millisecond,
      start.microsecond,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'companyId': companyId,
      'planId': planId,
      'planName': planName,
      'subscriptionPlan': subscriptionPlan,
      'price': price,
      'startDate': Timestamp.fromDate(startDate),
      'expiryDate': Timestamp.fromDate(expiryDate),
      'status': status,
      'remainingDays': remainingDays,
      'remainingTimeFormatted': remainingTimeFormatted,
      'enabledFeatures': enabledFeatures,
      'featureOverrides': featureOverrides,
      'effectiveFeatures': effectiveFeatures,
      'addonFeatures': addonFeatures,
      'createdAt': createdAt != null ? Timestamp.fromDate(createdAt!) : FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    };
  }

  CompanySubscriptionModel copyWith({
    String? id,
    String? companyId,
    String? planId,
    String? planName,
    String? subscriptionPlan,
    double? price,
    DateTime? startDate,
    DateTime? expiryDate,
    List<String>? enabledFeatures,
    Map<String, bool>? featureOverrides,
    List<String>? addonFeatures,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return CompanySubscriptionModel(
      id: id ?? this.id,
      companyId: companyId ?? this.companyId,
      planId: planId ?? this.planId,
      planName: planName ?? this.planName,
      subscriptionPlan: subscriptionPlan ?? this.subscriptionPlan,
      price: price ?? this.price,
      startDate: startDate ?? this.startDate,
      expiryDate: expiryDate ?? this.expiryDate,
      enabledFeatures: enabledFeatures ?? this.enabledFeatures,
      featureOverrides: featureOverrides ?? this.featureOverrides,
      addonFeatures: addonFeatures ?? this.addonFeatures,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
