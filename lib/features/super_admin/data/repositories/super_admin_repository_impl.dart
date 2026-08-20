import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../auth/domain/models/company_model.dart';
import '../../domain/repositories/super_admin_repository.dart';

class SuperAdminRepositoryImpl implements SuperAdminRepository {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  @override
  Stream<List<CompanyModel>> streamCompanies() {
    return _firestore
        .collection('companies')
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) {
        return CompanyModel.fromMap(doc.data(), doc.id);
      }).toList();
    });
  }

  @override
  Stream<CompanyModel?> streamCompanyById(String companyId) {
    return _firestore
        .collection('companies')
        .doc(companyId)
        .snapshots()
        .map((doc) {
      if (doc.exists && doc.data() != null) {
        return CompanyModel.fromMap(doc.data()!, doc.id);
      }
      return null;
    });
  }

  @override
  Future<void> createCompany(CompanyModel company) async {
    await _firestore
        .collection('companies')
        .doc(company.companyId)
        .set(company.toMap());
  }

  @override
  Future<void> updateCompany(CompanyModel company) async {
    await _firestore
        .collection('companies')
        .doc(company.companyId)
        .update(company.toMap()..['updatedAt'] = FieldValue.serverTimestamp());
  }

  @override
  Future<void> suspendCompany(String companyId) async {
    await _firestore
        .collection('companies')
        .doc(companyId)
        .update({
      'status': 'Suspended',
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  @override
  Future<void> activateCompany(String companyId) async {
    await _firestore
        .collection('companies')
        .doc(companyId)
        .update({
      'status': 'Active',
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  @override
  Future<void> archiveCompany(String companyId) async {
    await _firestore
        .collection('companies')
        .doc(companyId)
        .update({
      'status': 'Archived',
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  @override
  Future<String> generateNextCompanyCode() async {
    final counterRef = _firestore.collection('system_counters').doc('companyCounter');
    
    final newCodeValue = await _firestore.runTransaction<int>((transaction) async {
      final snapshot = await transaction.get(counterRef);
      if (!snapshot.exists) {
        transaction.set(counterRef, {'lastCodeValue': 1});
        return 1;
      }
      final currentVal = (snapshot.data()?['lastCodeValue'] ?? 0) as int;
      final nextVal = currentVal + 1;
      transaction.update(counterRef, {'lastCodeValue': nextVal});
      return nextVal;
    });

    final paddedStr = newCodeValue.toString().padLeft(4, '0');
    return 'CMP$paddedStr';
  }

  @override
  Future<bool> isCompanyNameDuplicate(String name) async {
    final snapshot = await _firestore
        .collection('companies')
        .where('companyName', isEqualTo: name)
        .limit(1)
        .get();
    return snapshot.docs.isNotEmpty;
  }

  @override
  Future<bool> isCompanyCodeDuplicate(String code) async {
    final snapshot = await _firestore
        .collection('companies')
        .where('companyCode', isEqualTo: code)
        .limit(1)
        .get();
    return snapshot.docs.isNotEmpty;
  }
}
