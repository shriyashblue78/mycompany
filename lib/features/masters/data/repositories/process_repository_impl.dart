import 'package:cloud_firestore/cloud_firestore.dart';
import '../../domain/models/process_model.dart';
import '../../domain/repositories/process_repository.dart';

class ProcessRepositoryImpl implements ProcessRepository {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> _ref(String companyId) {
    return _firestore.collection('companies').doc(companyId).collection('processes');
  }

  @override
  Future<void> createProcess(String companyId, ProcessModel process) async {
    final docRef = process.processId.isEmpty
        ? _ref(companyId).doc()
        : _ref(companyId).doc(process.processId);

    await docRef.set(process.toFirestoreMap(isUpdate: false));
  }

  @override
  Future<void> updateProcess(String companyId, ProcessModel process) async {
    await _ref(companyId)
        .doc(process.processId)
        .update(process.toFirestoreMap(isUpdate: true));
  }

  @override
  Future<void> deleteProcess(String companyId, String processId) async {
    await _ref(companyId).doc(processId).delete();
  }

  @override
  Stream<List<ProcessModel>> streamProcesses(String companyId) {
    return _ref(companyId)
        .orderBy('processName')
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) {
        return ProcessModel.fromMap(doc.data(), doc.id);
      }).toList();
    });
  }

  @override
  Future<bool> isProcessNameTaken(String companyId, String processName, {String? excludeId}) async {
    final clean = processName.trim().toLowerCase();
    final snap = await _ref(companyId).get();
    for (final doc in snap.docs) {
      if (excludeId != null && doc.id == excludeId) continue;
      final existing = (doc.data()['processName'] ?? '').toString().trim().toLowerCase();
      if (existing == clean) return true;
    }
    return false;
  }

  @override
  Future<bool> isProcessReferenced(String companyId, String processName) async {
    final clean = processName.trim();
    if (clean.isEmpty) return false;
    try {
      // 1. Check production records
      final prodSnap = await _firestore
          .collection('companies')
          .doc(companyId)
          .collection('productions')
          .where('process', isEqualTo: clean)
          .limit(1)
          .get();
      if (prodSnap.docs.isNotEmpty) return true;

      // 2. Check inventory items
      final invSnap = await _firestore
          .collection('companies')
          .doc(companyId)
          .collection('inventory')
          .where('process', isEqualTo: clean)
          .limit(1)
          .get();
      if (invSnap.docs.isNotEmpty) return true;

      return false;
    } catch (_) {
      return false;
    }
  }
}
