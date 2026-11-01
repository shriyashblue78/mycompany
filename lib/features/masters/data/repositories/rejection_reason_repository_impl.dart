import 'package:cloud_firestore/cloud_firestore.dart';
import '../../domain/models/rejection_reason_model.dart';
import '../../domain/repositories/rejection_reason_repository.dart';

class RejectionReasonRepositoryImpl implements RejectionReasonRepository {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> _reasonsRef(String companyId) {
    return _firestore.collection('companies').doc(companyId).collection('rejection_reasons');
  }

  @override
  Future<void> createReason(String companyId, RejectionReasonModel reason) async {
    final docRef = reason.reasonId.isEmpty
        ? _reasonsRef(companyId).doc()
        : _reasonsRef(companyId).doc(reason.reasonId);

    await docRef.set(reason.toFirestoreMap(isUpdate: false));
  }

  @override
  Future<void> updateReason(String companyId, RejectionReasonModel reason) async {
    await _reasonsRef(companyId)
        .doc(reason.reasonId)
        .update(reason.toFirestoreMap(isUpdate: true));
  }

  @override
  Future<void> deleteReason(String companyId, String reasonId) async {
    await _reasonsRef(companyId).doc(reasonId).delete();
  }

  @override
  Stream<List<RejectionReasonModel>> streamReasons(String companyId) {
    return _reasonsRef(companyId)
        .orderBy('reasonName')
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) {
        return RejectionReasonModel.fromMap(doc.data(), doc.id);
      }).toList();
    });
  }

  @override
  Future<bool> isReasonNameTaken(String companyId, String reasonName, {String? excludeReasonId}) async {
    final nameLower = reasonName.trim().toLowerCase();
    final snap = await _reasonsRef(companyId).get();
    for (final doc in snap.docs) {
      if (excludeReasonId != null && doc.id == excludeReasonId) continue;
      final existingName = (doc.data()['reasonName'] ?? '').toString().trim().toLowerCase();
      if (existingName == nameLower) {
        return true;
      }
    }
    return false;
  }
}
