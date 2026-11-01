import '../../domain/models/item_model.dart';

class OpeningBalanceEntryItem {
  final String itemId;
  final String itemDescription;
  final String partNo;
  final String storeOrWip; // 'Store' or 'WIP'
  final double openingBalance;
  final double unitRate;
  final double finishRate;

  const OpeningBalanceEntryItem({
    required this.itemId,
    required this.itemDescription,
    required this.partNo,
    required this.storeOrWip,
    required this.openingBalance,
    required this.unitRate,
    required this.finishRate,
  });
}

abstract class ItemRepository {
  Future<void> createItem(String companyId, ItemModel item);
  Future<void> updateItem(String companyId, ItemModel item);
  Future<void> deleteItem(String companyId, String itemId);
  Stream<List<ItemModel>> streamItems(String companyId);
  Stream<ItemModel?> streamItemById(String companyId, String itemId);
  Future<bool> isItemNoTaken(String companyId, String itemNo, {String? excludeItemId});
  Future<bool> isItemReferenced(String companyId, String itemId, String itemNo);
  Future<void> assignItemsToGroup(String companyId, String groupName, List<String> itemIds);
  Future<void> removeItemFromGroup(String companyId, String itemId);
  Future<void> updateGroupForItems(String companyId, String oldGroupName, String newGroupName);
  Future<int> saveOpeningBalances(String companyId, List<OpeningBalanceEntryItem> entries);
  Future<int> updateItemsHsnSac(String companyId, Map<String, String> itemIdToHsnSac);
}
