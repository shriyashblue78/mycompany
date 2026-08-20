import 'package:cloud_firestore/cloud_firestore.dart';

class AttendanceModel {
  final String attendanceId;
  final String companyId;
  final String employeeId;
  final String uid;
  final DateTime date; // The calendar date (local)
  final DateTime? checkInTime; // Local check-in time
  final DateTime? checkOutTime; // Local check-out time
  final double workingHours;
  final String status; // Present, Absent, Half Day, Late, Holiday, Leave
  final String? remarks;
  final DateTime createdAt;
  final DateTime updatedAt;

  const AttendanceModel({
    required this.attendanceId,
    required this.companyId,
    required this.employeeId,
    required this.uid,
    required this.date,
    this.checkInTime,
    this.checkOutTime,
    required this.workingHours,
    required this.status,
    this.remarks,
    required this.createdAt,
    required this.updatedAt,
  });

  factory AttendanceModel.fromMap(Map<String, dynamic> map) {
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

    DateTime parsedDate;
    final rawDate = map['date'];
    if (rawDate is String) {
      parsedDate = DateTime.tryParse(rawDate) ?? DateTime.now();
    } else {
      parsedDate = parseDate(rawDate);
    }

    return AttendanceModel(
      attendanceId: (map['attendanceId'] ?? '') as String,
      companyId: (map['companyId'] ?? '') as String,
      employeeId: (map['employeeId'] ?? '') as String,
      uid: (map['uid'] ?? '') as String,
      date: parsedDate,
      checkInTime: parseDateNullable(map['checkInTime']),
      checkOutTime: parseDateNullable(map['checkOutTime']),
      workingHours: (map['workingHours'] ?? 0.0) is int
          ? ((map['workingHours'] ?? 0) as int).toDouble()
          : (map['workingHours'] ?? 0.0) as double,
      status: (map['status'] ?? 'Absent') as String,
      remarks: map['remarks'] as String?,
      createdAt: parseDate(map['createdAt']),
      updatedAt: parseDate(map['updatedAt']),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'attendanceId': attendanceId,
      'companyId': companyId,
      'employeeId': employeeId,
      'uid': uid,
      'date': '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}',
      'checkInTime': checkInTime != null ? Timestamp.fromDate(checkInTime!) : null,
      'checkOutTime': checkOutTime != null ? Timestamp.fromDate(checkOutTime!) : null,
      'workingHours': workingHours,
      'status': status,
      'remarks': remarks,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
    };
  }

  Map<String, dynamic> toFirestoreMap({bool isUpdate = false}) {
    final map = toMap();
    if (isUpdate) {
      map['updatedAt'] = FieldValue.serverTimestamp();
      map.remove('createdAt');
    } else {
      map['createdAt'] = FieldValue.serverTimestamp();
      map['updatedAt'] = FieldValue.serverTimestamp();
    }
    return map;
  }

  AttendanceModel copyWith({
    String? attendanceId,
    String? companyId,
    String? employeeId,
    String? uid,
    DateTime? date,
    DateTime? checkInTime,
    DateTime? checkOutTime,
    double? workingHours,
    String? status,
    String? remarks,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return AttendanceModel(
      attendanceId: attendanceId ?? this.attendanceId,
      companyId: companyId ?? this.companyId,
      employeeId: employeeId ?? this.employeeId,
      uid: uid ?? this.uid,
      date: date ?? this.date,
      checkInTime: checkInTime ?? this.checkInTime,
      checkOutTime: checkOutTime ?? this.checkOutTime,
      workingHours: workingHours ?? this.workingHours,
      status: status ?? this.status,
      remarks: remarks ?? this.remarks,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
