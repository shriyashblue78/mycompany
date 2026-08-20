import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../domain/models/inventory_item_model.dart';
import '../../domain/repositories/inventory_repository.dart';
import '../../data/repositories/inventory_repository_impl.dart';

// Repository Provider
final inventoryRepositoryProvider = Provider<InventoryRepository>((ref) {
  return InventoryRepositoryImpl();
});

// Filter state providers
final inventorySearchQueryProvider = StateProvider<String>((ref) => '');
final inventoryCategoryFilterProvider = StateProvider<String?>((ref) => null);

// Constants
const List<String> kInventoryCategories = [
  'Raw Material',
  'Finished Goods',
  'Consumables',
  'Others',
];

const List<String> kInventoryUnits = [
  'Nos',
  'Kg',
  'Litre',
  'Meter',
  'Box',
];

// Stream of all items in the company inventory
final companyInventoryStreamProvider = StreamProvider<List<InventoryItemModel>>((ref) {
  final authState = ref.watch(authProvider);
  final companyId = authState.user?.companyId;
  if (companyId == null) {
    return Stream.value([]);
  }
  return ref.watch(inventoryRepositoryProvider).streamItems(companyId);
});

// Filtered stream of items
final filteredInventoryProvider = Provider<AsyncValue<List<InventoryItemModel>>>((ref) {
  final query = ref.watch(inventorySearchQueryProvider).trim().toLowerCase();
  final category = ref.watch(inventoryCategoryFilterProvider);
  final inventoryAsync = ref.watch(companyInventoryStreamProvider);

  return inventoryAsync.when(
    loading: () => const AsyncValue.loading(),
    error: (err, stack) => AsyncValue.error(err, stack),
    data: (list) {
      final filteredList = list.where((item) {
        // 1. Search Query (Matches: Item Name)
        if (query.isNotEmpty && !item.itemName.toLowerCase().contains(query)) {
          return false;
        }

        // 2. Category Filter
        if (category != null && category != 'All' && item.category != category) {
          return false;
        }

        return true;
      }).toList();

      return AsyncValue.data(filteredList);
    },
  );
});

// Single item details stream
final inventoryDetailsStreamProvider = StreamProvider.family<InventoryItemModel?, String>((ref, itemId) {
  final authState = ref.watch(authProvider);
  final companyId = authState.user?.companyId;
  if (companyId == null) {
    return Stream.value(null);
  }
  return ref.watch(inventoryRepositoryProvider).streamItemById(companyId, itemId);
});
