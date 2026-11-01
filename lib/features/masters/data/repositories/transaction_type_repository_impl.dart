import 'package:cloud_firestore/cloud_firestore.dart';
import '../../domain/models/transaction_type_model.dart';
import '../../domain/repositories/transaction_type_repository.dart';

class TransactionTypeRepositoryImpl implements TransactionTypeRepository {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> _typesRef(String companyId) {
    return _firestore.collection('companies').doc(companyId).collection('transaction_types');
  }

  @override
  Future<void> createTransactionType(String companyId, TransactionTypeModel type) async {
    final docRef = type.typeId.isEmpty
        ? _typesRef(companyId).doc()
        : _typesRef(companyId).doc(type.typeId);

    await docRef.set(type.toFirestoreMap(isUpdate: false));
  }

  @override
  Future<void> updateTransactionType(String companyId, TransactionTypeModel type) async {
    await _typesRef(companyId)
        .doc(type.typeId)
        .update(type.toFirestoreMap(isUpdate: true));
  }

  @override
  Future<void> deleteTransactionType(String companyId, String typeId) async {
    await _typesRef(companyId).doc(typeId).delete();
  }

  @override
  Stream<List<TransactionTypeModel>> streamTransactionTypes(String companyId) {
    return _typesRef(companyId)
        .orderBy('typeName')
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) {
        return TransactionTypeModel.fromMap(doc.data(), doc.id);
      }).toList();
    });
  }

  @override
  Future<bool> isTypeNameTaken(String companyId, String typeName, {String? excludeTypeId}) async {
    final nameLower = typeName.trim().toLowerCase();
    final snap = await _typesRef(companyId).get();
    for (final doc in snap.docs) {
      if (excludeTypeId != null && doc.id == excludeTypeId) continue;
      final existingName = (doc.data()['typeName'] ?? '').toString().trim().toLowerCase();
      if (existingName == nameLower) {
        return true;
      }
    }
    return false;
  }
}
