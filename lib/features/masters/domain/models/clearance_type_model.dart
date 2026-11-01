import 'package:cloud_firestore/cloud_firestore.dart';

class ClearanceTypeModel {
  final String clearanceId;
  final String companyId;
  final String clearanceType; // Required name
  final bool isCgstApplicable;
  final bool isSgstApplicable;
  final bool isIgstApplicable;
  final bool isCessApplicable;
  final String? remark;
  final String deFlag; // 'D' (Domestic) or 'E' (Export)
  final String? bondDetails;
  final DateTime createdAt;
  final DateTime updatedAt;

  const ClearanceTypeModel({
    required this.clearanceId,
    required this.companyId,
    required this.clearanceType,
    this.isCgstApplicable = true,
    this.isSgstApplicable = true,
    this.isIgstApplicable = false,
    this.isCessApplicable = false,
    this.remark,
    this.deFlag = 'D',
    this.bondDetails,
    required this.createdAt,
    required this.updatedAt,
  });

  factory ClearanceTypeModel.fromMap(Map<String, dynamic> map, String id) {
    DateTime parseDate(dynamic value) {
      if (value == null) return DateTime.now();
      if (value is Timestamp) return value.toDate();
      if (value is String) return DateTime.tryParse(value) ?? DateTime.now();
      return DateTime.now();
    }

    return ClearanceTypeModel(
      clearanceId: id,
      companyId: (map['companyId'] ?? '') as String,
      clearanceType: (map['clearanceType'] ?? '') as String,
      isCgstApplicable: (map['isCgstApplicable'] ?? true) as bool,
      isSgstApplicable: (map['isSgstApplicable'] ?? true) as bool,
      isIgstApplicable: (map['isIgstApplicable'] ?? false) as bool,
      isCessApplicable: (map['isCessApplicable'] ?? false) as bool,
      remark: map['remark'] as String?,
      deFlag: (map['deFlag'] ?? 'D') as String,
      bondDetails: map['bondDetails'] as String?,
      createdAt: parseDate(map['createdAt']),
      updatedAt: parseDate(map['updatedAt']),
    );
  }

  Map<String, dynamic> toFirestoreMap({bool isUpdate = false}) {
    return {
      'companyId': companyId,
      'clearanceType': clearanceType.trim(),
      'isCgstApplicable': isCgstApplicable,
      'isSgstApplicable': isSgstApplicable,
      'isIgstApplicable': isIgstApplicable,
      'isCessApplicable': isCessApplicable,
      'remark': (remark != null && remark!.trim().isNotEmpty) ? remark!.trim() : null,
      'deFlag': deFlag.trim(),
      'bondDetails': (bondDetails != null && bondDetails!.trim().isNotEmpty) ? bondDetails!.trim() : null,
      if (!isUpdate) 'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    };
  }

  ClearanceTypeModel copyWith({
    String? clearanceId,
    String? companyId,
    String? clearanceType,
    bool? isCgstApplicable,
    bool? isSgstApplicable,
    bool? isIgstApplicable,
    bool? isCessApplicable,
    String? remark,
    String? deFlag,
    String? bondDetails,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return ClearanceTypeModel(
      clearanceId: clearanceId ?? this.clearanceId,
      companyId: companyId ?? this.companyId,
      clearanceType: clearanceType ?? this.clearanceType,
      isCgstApplicable: isCgstApplicable ?? this.isCgstApplicable,
      isSgstApplicable: isSgstApplicable ?? this.isSgstApplicable,
      isIgstApplicable: isIgstApplicable ?? this.isIgstApplicable,
      isCessApplicable: isCessApplicable ?? this.isCessApplicable,
      remark: remark ?? this.remark,
      deFlag: deFlag ?? this.deFlag,
      bondDetails: bondDetails ?? this.bondDetails,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
