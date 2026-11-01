import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../domain/models/item_model.dart';
import '../../domain/repositories/item_repository.dart';
import '../../data/repositories/item_repository_impl.dart';

final itemRepositoryProvider = Provider<ItemRepository>((ref) {
  return ItemRepositoryImpl();
});

final itemSearchQueryProvider = StateProvider<String>((ref) => '');

final itemCategoryFilterProvider = StateProvider<String>((ref) => 'All');

final companyItemsStreamProvider = StreamProvider<List<ItemModel>>((ref) {
  final authState = ref.watch(authProvider);
  final companyId = authState.user?.companyId;
  if (companyId == null || companyId.isEmpty) {
    return Stream.value([]);
  }
  return ref.watch(itemRepositoryProvider).streamItems(companyId);
});

final itemDetailsStreamProvider = StreamProvider.family<ItemModel?, String>((ref, itemId) {
  final authState = ref.watch(authProvider);
  final companyId = authState.user?.companyId;
  if (companyId == null || companyId.isEmpty) {
    return Stream.value(null);
  }
  return ref.watch(itemRepositoryProvider).streamItemById(companyId, itemId);
});

final filteredItemsProvider = Provider<AsyncValue<List<ItemModel>>>((ref) {
  final itemsAsync = ref.watch(companyItemsStreamProvider);
  final query = ref.watch(itemSearchQueryProvider).trim().toLowerCase();
  final categoryFilter = ref.watch(itemCategoryFilterProvider);

  return itemsAsync.whenData((list) {
    return list.where((item) {
      if (categoryFilter != 'All' && item.category != categoryFilter) {
        return false;
      }
      if (query.isEmpty) return true;
      final nameMatch = item.itemDescription.toLowerCase().contains(query);
      final partMatch = item.itemNo.toLowerCase().contains(query);
      final catMatch = item.category.toLowerCase().contains(query);
      final groupMatch = (item.underGroup ?? '').toLowerCase().contains(query);
      return nameMatch || partMatch || catMatch || groupMatch;
    }).toList();
  });
});
