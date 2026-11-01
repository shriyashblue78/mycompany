import 'package:cloud_firestore/cloud_firestore.dart';
import '../../domain/models/item_model.dart';
import '../../domain/repositories/item_repository.dart';

class ItemRepositoryImpl implements ItemRepository {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> _itemsRef(String companyId) {
    return _firestore.collection('companies').doc(companyId).collection('inventory');
  }

  @override
  Future<void> createItem(String companyId, ItemModel item) async {
    final docRef = item.itemId.isEmpty
        ? _itemsRef(companyId).doc()
        : _itemsRef(companyId).doc(item.itemId);

    await docRef.set(item.toFirestoreMap(isUpdate: false));
  }

  @override
  Future<void> updateItem(String companyId, ItemModel item) async {
    await _itemsRef(companyId)
        .doc(item.itemId)
        .update(item.toFirestoreMap(isUpdate: true));
  }

  @override
  Future<void> deleteItem(String companyId, String itemId) async {
    await _itemsRef(companyId).doc(itemId).delete();
  }

  @override
  Stream<List<ItemModel>> streamItems(String companyId) {
    return _itemsRef(companyId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) {
        return ItemModel.fromMap(doc.data(), doc.id);
      }).toList();
    });
  }

  @override
  Stream<ItemModel?> streamItemById(String companyId, String itemId) {
    return _itemsRef(companyId).doc(itemId).snapshots().map((doc) {
      if (doc.exists && doc.data() != null) {
        return ItemModel.fromMap(doc.data()!, doc.id);
      }
      return null;
    });
  }

  @override
  Future<bool> isItemNoTaken(String companyId, String itemNo, {String? excludeItemId}) async {
    final cleanNo = itemNo.trim().toLowerCase();
    final snap = await _itemsRef(companyId).get();
    for (final doc in snap.docs) {
      if (excludeItemId != null && doc.id == excludeItemId) continue;
      final data = doc.data();
      final existingNo = (data['itemNo'] ?? data['partNumber'] ?? '').toString().trim().toLowerCase();
      if (existingNo == cleanNo) {
        return true;
      }
    }
    return false;
  }

  @override
  Future<bool> isItemReferenced(String companyId, String itemId, String itemNo) async {
    final cleanNo = itemNo.trim();
    try {
      // 1. Check purchases
      final purchaseSnap = await _firestore
          .collection('companies')
          .doc(companyId)
          .collection('purchases')
          .where('itemId', isEqualTo: itemId)
          .limit(1)
          .get();
      if (purchaseSnap.docs.isNotEmpty) return true;

      // 2. Check sales
      final salesSnap = await _firestore
          .collection('companies')
          .doc(companyId)
          .collection('sales')
          .where('itemId', isEqualTo: itemId)
          .limit(1)
          .get();
      if (salesSnap.docs.isNotEmpty) return true;

      // 3. Check inward/outward
      final ioSnap = await _firestore
          .collection('companies')
          .doc(companyId)
          .collection('inward_outward')
          .where('itemNumber', isEqualTo: cleanNo)
          .limit(1)
          .get();
      if (ioSnap.docs.isNotEmpty) return true;

      // 4. Check production
      final prodSnap = await _firestore
          .collection('companies')
          .doc(companyId)
          .collection('productions')
          .where('partNumber', isEqualTo: cleanNo)
          .limit(1)
          .get();
      if (prodSnap.docs.isNotEmpty) return true;

      return false;
    } catch (_) {
      return false;
    }
  }

  @override
  Future<void> assignItemsToGroup(String companyId, String groupName, List<String> itemIds) async {
    if (itemIds.isEmpty) return;
    final batch = _firestore.batch();
    final cleanGroup = groupName.trim();
    for (final id in itemIds) {
      final docRef = _itemsRef(companyId).doc(id);
      batch.update(docRef, {
        'underGroup': cleanGroup,
        'group': cleanGroup,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    }
    await batch.commit();
  }

  @override
  Future<void> removeItemFromGroup(String companyId, String itemId) async {
    await _itemsRef(companyId).doc(itemId).update({
      'underGroup': FieldValue.delete(),
      'group': FieldValue.delete(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  @override
  Future<void> updateGroupForItems(String companyId, String oldGroupName, String newGroupName) async {
    final cleanOld = oldGroupName.trim();
    final cleanNew = newGroupName.trim();
    if (cleanOld.isEmpty || cleanNew.isEmpty || cleanOld == cleanNew) return;

    final snap = await _itemsRef(companyId).get();
    final batch = _firestore.batch();
    bool hasUpdates = false;

    for (final doc in snap.docs) {
      final data = doc.data();
      final itemGroup = (data['underGroup'] ?? data['group'] ?? '').toString().trim();
      if (itemGroup.toLowerCase() == cleanOld.toLowerCase()) {
        batch.update(doc.reference, {
          'underGroup': cleanNew,
          'group': cleanNew,
          'updatedAt': FieldValue.serverTimestamp(),
        });
        hasUpdates = true;
      }
    }

    if (hasUpdates) {
      await batch.commit();
    }
  }

  @override
  Future<int> saveOpeningBalances(String companyId, List<OpeningBalanceEntryItem> entries) async {
    int savedCount = 0;
    final batch = _firestore.batch();

    for (final entry in entries) {
      final docRef = _itemsRef(companyId).doc(entry.itemId);
      final docSnap = await docRef.get();
      if (!docSnap.exists) continue;

      final data = docSnap.data() ?? {};
      final alreadyRecorded = (data['hasOpeningBalance'] ?? data['openingBalanceEntered'] ?? false) as bool;
      if (alreadyRecorded) {
        // Prevent duplicate opening entries and preserve existing transaction history
        continue;
      }

      final currentStockNum = (data['currentStock'] as num?)?.toDouble() ?? 0.0;
      final newStock = currentStockNum == 0.0 ? entry.openingBalance : currentStockNum;

      batch.update(docRef, {
        'openingBalance': entry.openingBalance,
        'storeOrWip': entry.storeOrWip,
        'storeLocation': entry.storeOrWip,
        'unitRate': entry.unitRate,
        'finishRate': entry.finishRate,
        'currentStock': newStock,
        'hasOpeningBalance': true,
        'openingBalanceEntered': true,
        'openingBalanceRecordedAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
      savedCount++;
    }

    if (savedCount > 0) {
      await batch.commit();
    }
    return savedCount;
  }

  @override
  Future<int> updateItemsHsnSac(String companyId, Map<String, String> itemIdToHsnSac) async {
    if (itemIdToHsnSac.isEmpty) return 0;
    final batch = _firestore.batch();
    int count = 0;

    for (final entry in itemIdToHsnSac.entries) {
      final docRef = _itemsRef(companyId).doc(entry.key);
      batch.update(docRef, {
        'hsnSac': entry.value.trim().isEmpty ? null : entry.value.trim(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
      count++;
    }

    if (count > 0) {
      await batch.commit();
    }
    return count;
  }
}
