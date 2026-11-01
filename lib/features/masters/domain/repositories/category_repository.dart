import '../../domain/models/category_model.dart';

abstract class CategoryRepository {
  Future<void> createCategory(String companyId, CategoryModel category);
  Future<void> updateCategory(String companyId, CategoryModel category);
  Future<void> deleteCategory(String companyId, String categoryId);
  Stream<List<CategoryModel>> streamCategories(String companyId);
  Future<bool> isCategoryReferenced(String companyId, String categoryName);
}
