import 'package:cloud_firestore/cloud_firestore.dart';
import '../../domain/models/inventory_item_model.dart';
import '../../domain/repositories/inventory_repository.dart';

class InventoryRepositoryImpl implements InventoryRepository {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  @override
  Future<void> createItem(String companyId, InventoryItemModel item) async {
    await _firestore
        .collection('companies')
        .doc(companyId)
        .collection('inventory')
        .doc(item.itemId)
        .set(item.toFirestoreMap(isUpdate: false));
  }

  @override
  Future<void> updateItem(String companyId, InventoryItemModel item) async {
    await _firestore
        .collection('companies')
        .doc(companyId)
        .collection('inventory')
        .doc(item.itemId)
        .update(item.toFirestoreMap(isUpdate: true));
  }

  @override
  Future<void> deleteItem(String companyId, String itemId) async {
    await _firestore
        .collection('companies')
        .doc(companyId)
        .collection('inventory')
        .doc(itemId)
        .delete();
  }

  @override
  Stream<List<InventoryItemModel>> streamItems(String companyId) {
    return _firestore
        .collection('companies')
        .doc(companyId)
        .collection('inventory')
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) {
        return InventoryItemModel.fromMap(doc.data(), doc.id);
      }).toList();
    });
  }

  @override
  Stream<InventoryItemModel?> streamItemById(String companyId, String itemId) {
    return _firestore
        .collection('companies')
        .doc(companyId)
        .collection('inventory')
        .doc(itemId)
        .snapshots()
        .map((doc) {
      if (doc.exists && doc.data() != null) {
        return InventoryItemModel.fromMap(doc.data()!, doc.id);
      }
      return null;
    });
  }
}
