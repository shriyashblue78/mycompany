import 'package:cloud_firestore/cloud_firestore.dart';

class FirestoreService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  /// Retrieve a document by path
  Future<DocumentSnapshot<Map<String, dynamic>>> getDoc(String path) async {
    try {
      return await _db.doc(path).get();
    } catch (e) {
      throw Exception('Failed to fetch data from database: $e');
    }
  }

  /// Write/Set a document by path
  Future<void> setDoc(String path, Map<String, dynamic> data, {bool merge = true}) async {
    try {
      await _db.doc(path).set(data, SetOptions(merge: merge));
    } catch (e) {
      throw Exception('Failed to save data to database: $e');
    }
  }

  /// Update an existing document by path
  Future<void> updateDoc(String path, Map<String, dynamic> data) async {
    try {
      await _db.doc(path).update(data);
    } catch (e) {
      throw Exception('Failed to update database record: $e');
    }
  }

  /// Delete a document by path
  Future<void> deleteDoc(String path) async {
    try {
      await _db.doc(path).delete();
    } catch (e) {
      throw Exception('Failed to delete database record: $e');
    }
  }

  /// Stream of a document by path
  Stream<DocumentSnapshot<Map<String, dynamic>>> streamDoc(String path) {
    return _db.doc(path).snapshots();
  }

  /// Get a collection stream
  Stream<QuerySnapshot<Map<String, dynamic>>> streamCollection(String path) {
    return _db.collection(path).snapshots();
  }

  /// Query a subcollection under a specific company to guarantee multi-tenancy segregation
  Stream<QuerySnapshot<Map<String, dynamic>>> streamCompanySubcollection({
    required String companyId,
    required String subcollection,
  }) {
    return _db
        .collection('companies')
        .doc(companyId)
        .collection(subcollection)
        .snapshots();
  }

  /// Retrieve a static list of documents from a company subcollection
  Future<QuerySnapshot<Map<String, dynamic>>> getCompanySubcollection({
    required String companyId,
    required String subcollection,
  }) async {
    try {
      return await _db
          .collection('companies')
          .doc(companyId)
          .collection(subcollection)
          .get();
    } catch (e) {
      throw Exception('Failed to fetch subcollection $subcollection: $e');
    }
  }

  /// Write a document under a company's subcollection
  Future<void> setCompanyDoc({
    required String companyId,
    required String subcollection,
    required String docId,
    required Map<String, dynamic> data,
  }) async {
    final path = 'companies/$companyId/$subcollection/$docId';
    await setDoc(path, data);
  }
}
