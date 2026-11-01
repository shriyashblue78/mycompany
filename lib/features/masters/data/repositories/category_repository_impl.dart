import 'package:cloud_firestore/cloud_firestore.dart';
import '../../domain/models/category_model.dart';
import '../../domain/repositories/category_repository.dart';

class CategoryRepositoryImpl implements CategoryRepository {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> _categoriesRef(String companyId) {
    return _firestore.collection('companies').doc(companyId).collection('categories');
  }

  @override
  Future<void> createCategory(String companyId, CategoryModel category) async {
    final docRef = category.categoryId.isEmpty
        ? _categoriesRef(companyId).doc()
        : _categoriesRef(companyId).doc(category.categoryId);

    await docRef.set(category.toFirestoreMap(isUpdate: false));
  }

  @override
  Future<void> updateCategory(String companyId, CategoryModel category) async {
    await _categoriesRef(companyId)
        .doc(category.categoryId)
        .update(category.toFirestoreMap(isUpdate: true));
  }

  @override
  Future<void> deleteCategory(String companyId, String categoryId) async {
    await _categoriesRef(companyId).doc(categoryId).delete();
  }

  @override
  Stream<List<CategoryModel>> streamCategories(String companyId) {
    return _categoriesRef(companyId)
        .orderBy('categoryName')
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) {
        return CategoryModel.fromMap(doc.data(), doc.id);
      }).toList();
    });
  }

  @override
  Future<bool> isCategoryReferenced(String companyId, String categoryName) async {
    if (categoryName.trim().isEmpty) return false;
    try {
      final snap = await _firestore
          .collection('companies')
          .doc(companyId)
          .collection('inventory')
          .where('category', isEqualTo: categoryName.trim())
          .limit(1)
          .get();
      return snap.docs.isNotEmpty;
    } catch (_) {
      return false;
    }
  }
}
