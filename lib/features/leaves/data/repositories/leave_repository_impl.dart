import 'package:cloud_firestore/cloud_firestore.dart';
import '../../domain/models/leave_model.dart';
import '../../domain/repositories/leave_repository.dart';

class LeaveRepositoryImpl implements LeaveRepository {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  @override
  Future<void> createLeave(String companyId, LeaveModel leave) async {
    await _firestore
        .collection('companies')
        .doc(companyId)
        .collection('leaves')
        .doc(leave.leaveId)
        .set(leave.toFirestoreMap(isUpdate: false));
  }

  @override
  Future<void> updateLeave(String companyId, LeaveModel leave) async {
    await _firestore
        .collection('companies')
        .doc(companyId)
        .collection('leaves')
        .doc(leave.leaveId)
        .update(leave.toFirestoreMap(isUpdate: true));
  }

  @override
  Stream<List<LeaveModel>> streamLeaves(String companyId) {
    return _firestore
        .collection('companies')
        .doc(companyId)
        .collection('leaves')
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) {
        return LeaveModel.fromMap(doc.data(), doc.id);
      }).toList();
    });
  }

  @override
  Stream<LeaveModel?> streamLeaveById(String companyId, String leaveId) {
    return _firestore
        .collection('companies')
        .doc(companyId)
        .collection('leaves')
        .doc(leaveId)
        .snapshots()
        .map((doc) {
      if (doc.exists && doc.data() != null) {
        return LeaveModel.fromMap(doc.data()!, doc.id);
      }
      return null;
    });
  }
}
