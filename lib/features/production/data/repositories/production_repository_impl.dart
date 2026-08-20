import 'package:cloud_firestore/cloud_firestore.dart';
import '../../domain/models/production_model.dart';
import '../../domain/repositories/production_repository.dart';

class ProductionRepositoryImpl implements ProductionRepository {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  @override
  Future<void> createProduction(String companyId, ProductionModel production) async {
    await _firestore
        .collection('companies')
        .doc(companyId)
        .collection('production')
        .doc(production.productionId)
        .set(production.toFirestoreMap(isUpdate: false));
  }

  @override
  Future<void> updateProduction(String companyId, ProductionModel production) async {
    await _firestore
        .collection('companies')
        .doc(companyId)
        .collection('production')
        .doc(production.productionId)
        .update(production.toFirestoreMap(isUpdate: true));
  }

  @override
  Future<void> deleteProduction(String companyId, String productionId) async {
    await _firestore
        .collection('companies')
        .doc(companyId)
        .collection('production')
        .doc(productionId)
        .delete();
  }

  @override
  Stream<List<ProductionModel>> streamProductions(String companyId) {
    return _firestore
        .collection('companies')
        .doc(companyId)
        .collection('production')
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) {
        return ProductionModel.fromMap(doc.data(), doc.id);
      }).toList();
    });
  }

  @override
  Stream<ProductionModel?> streamProductionById(String companyId, String productionId) {
    return _firestore
        .collection('companies')
        .doc(companyId)
        .collection('production')
        .doc(productionId)
        .snapshots()
        .map((doc) {
      if (doc.exists && doc.data() != null) {
        return ProductionModel.fromMap(doc.data()!, doc.id);
      }
      return null;
    });
  }
}
