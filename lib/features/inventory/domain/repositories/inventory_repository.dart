import '../models/inventory_item_model.dart';

abstract class InventoryRepository {
  Future<void> createItem(String companyId, InventoryItemModel item);
  Future<void> updateItem(String companyId, InventoryItemModel item);
  Future<void> deleteItem(String companyId, String itemId);
  Stream<List<InventoryItemModel>> streamItems(String companyId);
  Stream<InventoryItemModel?> streamItemById(String companyId, String itemId);
}
