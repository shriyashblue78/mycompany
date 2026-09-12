import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/models/inward_outward_model.dart';
import '../../domain/repositories/inward_outward_repository.dart';

final inwardOutwardRepositoryProvider = Provider<InwardOutwardRepository>((ref) {
  return InwardOutwardRepositoryImpl(FirebaseFirestore.instance);
});

class InwardOutwardRepositoryImpl implements InwardOutwardRepository {
  final FirebaseFirestore _firestore;

  InwardOutwardRepositoryImpl(this._firestore);

  CollectionReference<Map<String, dynamic>> _collection(String companyId) {
    return _firestore
        .collection('companies')
        .doc(companyId)
        .collection('inward_outward');
  }

  @override
  Future<void> addRecord(String companyId, InwardOutwardModel record) async {
    final docRef = record.id.isNotEmpty
        ? _collection(companyId).doc(record.id)
        : _collection(companyId).doc();
    
    final data = record.copyWith(id: docRef.id).toMap();
    await docRef.set(data);
  }

  @override
  Future<void> updateRecord(String companyId, InwardOutwardModel record) async {
    await _collection(companyId).doc(record.id).update(record.toMap());
  }

  @override
  Future<void> deleteRecord(String companyId, String recordId) async {
    await _collection(companyId).doc(recordId).delete();
  }

  @override
  Stream<List<InwardOutwardModel>> streamRecords(String companyId) {
    if (companyId.isEmpty) return Stream.value([]);
    
    return _collection(companyId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs
          .map((doc) => InwardOutwardModel.fromMap(doc.data(), doc.id))
          .toList();
    });
  }
}
