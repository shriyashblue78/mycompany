import 'package:cloud_firestore/cloud_firestore.dart';

/// Historical audit model tracking past and active subscriptions per company.
class SubscriptionHistoryModel {
  final String historyId;
  final String companyId;
  final String planId;
  final String planName;
  final String durationLabel;
  final double? price;
  final DateTime startDate;
  final DateTime expiryDate;
  final String? paymentId;
  final String status;
  final DateTime createdAt;

  const SubscriptionHistoryModel({
    required this.historyId,
    required this.companyId,
    required this.planId,
    required this.planName,
    required this.durationLabel,
    this.price,
    required this.startDate,
    required this.expiryDate,
    this.paymentId,
    required this.status,
    required this.createdAt,
  });

  factory SubscriptionHistoryModel.fromMap(Map<String, dynamic> map, String docId) {
    DateTime parseDate(dynamic value, DateTime fallback) {
      if (value == null) return fallback;
      if (value is Timestamp) return value.toDate();
      if (value is String) return DateTime.tryParse(value) ?? fallback;
      return fallback;
    }

    final now = DateTime.now();

    return SubscriptionHistoryModel(
      historyId: docId,
      companyId: (map['companyId'] ?? '') as String,
      planId: (map['planId'] ?? 'basic') as String,
      planName: (map['planName'] ?? 'Basic') as String,
      durationLabel: (map['durationLabel'] ?? '1 Month') as String,
      price: (map['price'] as num?)?.toDouble(),
      startDate: parseDate(map['startDate'], now),
      expiryDate: parseDate(map['expiryDate'], now),
      paymentId: map['paymentId'] as String?,
      status: (map['status'] ?? 'Active') as String,
      createdAt: parseDate(map['createdAt'], now),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'historyId': historyId,
      'companyId': companyId,
      'planId': planId,
      'planName': planName,
      'durationLabel': durationLabel,
      'price': price,
      'startDate': Timestamp.fromDate(startDate),
      'expiryDate': Timestamp.fromDate(expiryDate),
      'paymentId': paymentId,
      'status': status,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }
}
