import 'package:cloud_firestore/cloud_firestore.dart';

class LeaveModel {
  final String leaveId;
  final String companyId;
  final String employeeId;
  final String uid;
  final String employeeName;
  final String department;
  final String leaveType; // Casual Leave, Sick Leave, Earned Leave, Half Day, Work From Home, Unpaid Leave
  final String reason;
  final DateTime startDate;
  final DateTime endDate;
  final double totalDays;
  final String status; // Pending, Approved, Rejected, Cancelled
  final String? approvedByUid;
  final String? approvedByName;
  final String? approvalRemarks;
  final DateTime appliedAt;
  final DateTime? approvedAt;
  final DateTime updatedAt;
  final String? supportingDocumentUrl;

  const LeaveModel({
    required this.leaveId,
    required this.companyId,
    required this.employeeId,
    required this.uid,
    required this.employeeName,
    required this.department,
    required this.leaveType,
    required this.reason,
    required this.startDate,
    required this.endDate,
    required this.totalDays,
    required this.status,
    this.approvedByUid,
    this.approvedByName,
    this.approvalRemarks,
    required this.appliedAt,
    this.approvedAt,
    required this.updatedAt,
    this.supportingDocumentUrl,
  });

  factory LeaveModel.fromMap(Map<String, dynamic> map, String id) {
    DateTime parseDate(dynamic value) {
      if (value == null) return DateTime.now();
      if (value is Timestamp) return value.toDate();
      if (value is String) {
        return DateTime.tryParse(value) ?? DateTime.now();
      }
      return DateTime.now();
    }

    DateTime? parseDateNullable(dynamic value) {
      if (value == null) return null;
      if (value is Timestamp) return value.toDate();
      if (value is String) return DateTime.tryParse(value);
      return null;
    }

    return LeaveModel(
      leaveId: id,
      companyId: (map['companyId'] ?? '') as String,
      employeeId: (map['employeeId'] ?? '') as String,
      uid: (map['uid'] ?? '') as String,
      employeeName: (map['employeeName'] ?? '') as String,
      department: (map['department'] ?? '') as String,
      leaveType: (map['leaveType'] ?? 'Casual Leave') as String,
      reason: (map['reason'] ?? '') as String,
      startDate: parseDate(map['startDate']),
      endDate: parseDate(map['endDate']),
      totalDays: (map['totalDays'] ?? 1.0) is int
          ? ((map['totalDays'] ?? 1) as int).toDouble()
          : (map['totalDays'] ?? 1.0) as double,
      status: (map['status'] ?? 'Pending') as String,
      approvedByUid: map['approvedByUid'] as String?,
      approvedByName: map['approvedByName'] as String?,
      approvalRemarks: map['approvalRemarks'] as String?,
      appliedAt: parseDate(map['appliedAt']),
      approvedAt: parseDateNullable(map['approvedAt']),
      updatedAt: parseDate(map['updatedAt']),
      supportingDocumentUrl: map['supportingDocumentUrl'] as String?,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'leaveId': leaveId,
      'companyId': companyId,
      'employeeId': employeeId,
      'uid': uid,
      'employeeName': employeeName,
      'department': department,
      'leaveType': leaveType,
      'reason': reason,
      'startDate': Timestamp.fromDate(startDate),
      'endDate': Timestamp.fromDate(endDate),
      'totalDays': totalDays,
      'status': status,
      'approvedByUid': approvedByUid,
      'approvedByName': approvedByName,
      'approvalRemarks': approvalRemarks,
      'appliedAt': Timestamp.fromDate(appliedAt),
      'approvedAt': approvedAt != null ? Timestamp.fromDate(approvedAt!) : null,
      'updatedAt': Timestamp.fromDate(updatedAt),
      'supportingDocumentUrl': supportingDocumentUrl,
    };
  }

  Map<String, dynamic> toFirestoreMap({bool isUpdate = false}) {
    final map = toMap();
    if (isUpdate) {
      map['updatedAt'] = FieldValue.serverTimestamp();
      map.remove('appliedAt');
    } else {
      map['appliedAt'] = FieldValue.serverTimestamp();
      map['updatedAt'] = FieldValue.serverTimestamp();
    }
    return map;
  }

  LeaveModel copyWith({
    String? leaveId,
    String? companyId,
    String? employeeId,
    String? uid,
    String? employeeName,
    String? department,
    String? leaveType,
    String? reason,
    DateTime? startDate,
    DateTime? endDate,
    double? totalDays,
    String? status,
    String? approvedByUid,
    String? approvedByName,
    String? approvalRemarks,
    DateTime? appliedAt,
    DateTime? approvedAt,
    DateTime? updatedAt,
    String? supportingDocumentUrl,
  }) {
    return LeaveModel(
      leaveId: leaveId ?? this.leaveId,
      companyId: companyId ?? this.companyId,
      employeeId: employeeId ?? this.employeeId,
      uid: uid ?? this.uid,
      employeeName: employeeName ?? this.employeeName,
      department: department ?? this.department,
      leaveType: leaveType ?? this.leaveType,
      reason: reason ?? this.reason,
      startDate: startDate ?? this.startDate,
      endDate: endDate ?? this.endDate,
      totalDays: totalDays ?? this.totalDays,
      status: status ?? this.status,
      approvedByUid: approvedByUid ?? this.approvedByUid,
      approvedByName: approvedByName ?? this.approvedByName,
      approvalRemarks: approvalRemarks ?? this.approvalRemarks,
      appliedAt: appliedAt ?? this.appliedAt,
      approvedAt: approvedAt ?? this.approvedAt,
      updatedAt: updatedAt ?? this.updatedAt,
      supportingDocumentUrl: supportingDocumentUrl ?? this.supportingDocumentUrl,
    );
  }
}
