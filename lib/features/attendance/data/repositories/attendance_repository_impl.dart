import 'package:cloud_firestore/cloud_firestore.dart';
import '../../domain/models/attendance_model.dart';
import '../../domain/repositories/attendance_repository.dart';

class AttendanceRepositoryImpl implements AttendanceRepository {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  @override
  Future<void> checkIn(String companyId, AttendanceModel attendance) async {
    if (attendance.companyId != companyId) {
      throw Exception('Security Violation: Company mismatch.');
    }

    final docRef = _firestore
        .collection('companies')
        .doc(companyId)
        .collection('attendance')
        .doc(attendance.attendanceId);

    return _firestore.runTransaction((transaction) async {
      final snapshot = await transaction.get(docRef);
      if (snapshot.exists) {
        throw Exception('Duplicate Check-In: You are already checked in for today.');
      }
      transaction.set(docRef, attendance.toFirestoreMap(isUpdate: false));
    });
  }

  @override
  Future<void> checkOut({
    required String companyId,
    required String attendanceId,
    required DateTime checkOutTime,
    required double workingHours,
    required String status,
    String? remarks,
  }) async {
    final docRef = _firestore
        .collection('companies')
        .doc(companyId)
        .collection('attendance')
        .doc(attendanceId);

    return _firestore.runTransaction((transaction) async {
      final snapshot = await transaction.get(docRef);
      if (!snapshot.exists) {
        throw Exception('No Check-In record found. You must check in before checking out.');
      }

      final data = snapshot.data();
      if (data != null && data['checkOutTime'] != null) {
        throw Exception('Duplicate Check-Out: You have already checked out for today.');
      }

      transaction.update(docRef, {
        'checkOutTime': Timestamp.fromDate(checkOutTime),
        'workingHours': workingHours,
        'status': status,
        // ignore: use_null_aware_elements
        if (remarks != null) 'remarks': remarks,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    });
  }

  @override
  Future<AttendanceModel?> getTodayAttendance(
    String companyId,
    String employeeId,
    String dateStr,
  ) async {
    final docId = '${employeeId}_$dateStr';
    final doc = await _firestore
        .collection('companies')
        .doc(companyId)
        .collection('attendance')
        .doc(docId)
        .get();

    if (doc.exists && doc.data() != null) {
      return AttendanceModel.fromMap(doc.data()!);
    }
    return null;
  }

  @override
  Stream<AttendanceModel?> streamTodayAttendance(
    String companyId,
    String employeeId,
    String dateStr,
  ) {
    final docId = '${employeeId}_$dateStr';
    return _firestore
        .collection('companies')
        .doc(companyId)
        .collection('attendance')
        .doc(docId)
        .snapshots()
        .map((doc) {
          if (doc.exists && doc.data() != null) {
            return AttendanceModel.fromMap(doc.data()!);
          }
          return null;
        });
  }

  @override
  Stream<List<AttendanceModel>> streamEmployeeAttendance(
    String companyId,
    String employeeId,
  ) {
    return _firestore
        .collection('companies')
        .doc(companyId)
        .collection('attendance')
        .where('employeeId', isEqualTo: employeeId)
        .orderBy('date', descending: true)
        .snapshots()
        .map((snapshot) {
          return snapshot.docs.map((doc) {
            return AttendanceModel.fromMap(doc.data());
          }).toList();
        });
  }

  @override
  Stream<List<AttendanceModel>> streamCompanyAttendance(String companyId) {
    return _firestore
        .collection('companies')
        .doc(companyId)
        .collection('attendance')
        .orderBy('date', descending: true)
        .snapshots()
        .map((snapshot) {
          return snapshot.docs.map((doc) {
            return AttendanceModel.fromMap(doc.data());
          }).toList();
        });
  }

  @override
  Future<List<AttendanceModel>> getCompanyAttendanceList(String companyId) async {
    final snapshot = await _firestore
        .collection('companies')
        .doc(companyId)
        .collection('attendance')
        .orderBy('date', descending: true)
        .get();

    return snapshot.docs.map((doc) {
      return AttendanceModel.fromMap(doc.data());
    }).toList();
  }
}
