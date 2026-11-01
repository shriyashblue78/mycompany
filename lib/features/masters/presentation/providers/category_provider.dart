import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../domain/models/category_model.dart';
import '../../domain/repositories/category_repository.dart';
import '../../data/repositories/category_repository_impl.dart';

final categoryRepositoryProvider = Provider<CategoryRepository>((ref) {
  return CategoryRepositoryImpl();
});

final categorySearchQueryProvider = StateProvider<String>((ref) => '');

final companyCategoriesStreamProvider = StreamProvider<List<CategoryModel>>((ref) {
  final authState = ref.watch(authProvider);
  final companyId = authState.user?.companyId;
  if (companyId == null || companyId.isEmpty) {
    return Stream.value([]);
  }
  return ref.watch(categoryRepositoryProvider).streamCategories(companyId);
});

final filteredCategoriesProvider = Provider<AsyncValue<List<CategoryModel>>>((ref) {
  final categoriesAsync = ref.watch(companyCategoriesStreamProvider);
  final query = ref.watch(categorySearchQueryProvider).trim().toLowerCase();

  return categoriesAsync.whenData((list) {
    if (query.isEmpty) return list;
    return list.where((cat) {
      return cat.categoryName.toLowerCase().contains(query);
    }).toList();
  });
});
