import 'package:cloud_firestore/cloud_firestore.dart';

enum PaymentStatus {
  pending,
  successful,
  failed,
  cancelled;

  static PaymentStatus fromString(String val) {
    return PaymentStatus.values.firstWhere(
      (e) => e.name.toLowerCase() == val.trim().toLowerCase(),
      orElse: () => PaymentStatus.pending,
    );
  }

  String get displayName {
    switch (this) {
      case PaymentStatus.pending:
        return 'Pending Integration';
      case PaymentStatus.successful:
        return 'Successful';
      case PaymentStatus.failed:
        return 'Failed';
      case PaymentStatus.cancelled:
        return 'Cancelled';
    }
  }
}

/// Modular Payment Transaction Model ready for future payment gateway integration.
class PaymentTransactionModel {
  final String paymentId;
  final String companyId;
  final String planId;
  final String planName;
  final String durationLabel;
  final double amount;
  final String currency;
  final PaymentStatus status;
  final String? transactionReference;
  final String paymentGateway;
  final DateTime createdAt;
  final DateTime? updatedAt;

  const PaymentTransactionModel({
    required this.paymentId,
    required this.companyId,
    required this.planId,
    required this.planName,
    required this.durationLabel,
    required this.amount,
    this.currency = 'INR',
    this.status = PaymentStatus.pending,
    this.transactionReference,
    this.paymentGateway = 'Pending Gateway Integration',
    required this.createdAt,
    this.updatedAt,
  });

  factory PaymentTransactionModel.fromMap(Map<String, dynamic> map, String docId) {
    DateTime parseDate(dynamic value, DateTime fallback) {
      if (value == null) return fallback;
      if (value is Timestamp) return value.toDate();
      if (value is String) return DateTime.tryParse(value) ?? fallback;
      return fallback;
    }

    final now = DateTime.now();

    return PaymentTransactionModel(
      paymentId: docId,
      companyId: (map['companyId'] ?? '') as String,
      planId: (map['planId'] ?? 'basic') as String,
      planName: (map['planName'] ?? 'Basic') as String,
      durationLabel: (map['durationLabel'] ?? '1 Month') as String,
      amount: (map['amount'] as num?)?.toDouble() ?? 0.0,
      currency: (map['currency'] ?? 'INR') as String,
      status: PaymentStatus.fromString((map['status'] ?? 'pending') as String),
      transactionReference: map['transactionReference'] as String?,
      paymentGateway: (map['paymentGateway'] ?? 'Pending Gateway Integration') as String,
      createdAt: parseDate(map['createdAt'], now),
      updatedAt: map['updatedAt'] != null ? parseDate(map['updatedAt'], now) : null,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'paymentId': paymentId,
      'companyId': companyId,
      'planId': planId,
      'planName': planName,
      'durationLabel': durationLabel,
      'amount': amount,
      'currency': currency,
      'status': status.name,
      'transactionReference': transactionReference,
      'paymentGateway': paymentGateway,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': updatedAt != null ? Timestamp.fromDate(updatedAt!) : FieldValue.serverTimestamp(),
    };
  }

  PaymentTransactionModel copyWith({
    String? paymentId,
    String? companyId,
    String? planId,
    String? planName,
    String? durationLabel,
    double? amount,
    String? currency,
    PaymentStatus? status,
    String? transactionReference,
    String? paymentGateway,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return PaymentTransactionModel(
      paymentId: paymentId ?? this.paymentId,
      companyId: companyId ?? this.companyId,
      planId: planId ?? this.planId,
      planName: planName ?? this.planName,
      durationLabel: durationLabel ?? this.durationLabel,
      amount: amount ?? this.amount,
      currency: currency ?? this.currency,
      status: status ?? this.status,
      transactionReference: transactionReference ?? this.transactionReference,
      paymentGateway: paymentGateway ?? this.paymentGateway,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
