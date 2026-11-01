import 'package:cloud_firestore/cloud_firestore.dart';
import '../../domain/models/state_master_model.dart';
import '../../domain/repositories/state_master_repository.dart';

class StateMasterRepositoryImpl implements StateMasterRepository {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> _statesRef(String companyId) {
    return _firestore.collection('companies').doc(companyId).collection('states_master');
  }

  // Complete official Indian States & Union Territories with GST State Codes
  static const List<Map<String, String>> defaultIndianStates = [
    {'name': 'Jammu & Kashmir', 'code': '01'},
    {'name': 'Himachal Pradesh', 'code': '02'},
    {'name': 'Punjab', 'code': '03'},
    {'name': 'Chandigarh', 'code': '04'},
    {'name': 'Uttarakhand', 'code': '05'},
    {'name': 'Haryana', 'code': '06'},
    {'name': 'Delhi', 'code': '07'},
    {'name': 'Rajasthan', 'code': '08'},
    {'name': 'Uttar Pradesh', 'code': '09'},
    {'name': 'Bihar', 'code': '10'},
    {'name': 'Sikkim', 'code': '11'},
    {'name': 'Arunachal Pradesh', 'code': '12'},
    {'name': 'Nagaland', 'code': '13'},
    {'name': 'Manipur', 'code': '14'},
    {'name': 'Mizoram', 'code': '15'},
    {'name': 'Tripura', 'code': '16'},
    {'name': 'Meghalaya', 'code': '17'},
    {'name': 'Assam', 'code': '18'},
    {'name': 'West Bengal', 'code': '19'},
    {'name': 'Jharkhand', 'code': '20'},
    {'name': 'Odisha', 'code': '21'},
    {'name': 'Chhattisgarh', 'code': '22'},
    {'name': 'Madhya Pradesh', 'code': '23'},
    {'name': 'Gujarat', 'code': '24'},
    {'name': 'Dadra & Nagar Haveli and Daman & Diu', 'code': '26'},
    {'name': 'Maharashtra', 'code': '27'},
    {'name': 'Andhra Pradesh (Old)', 'code': '28'},
    {'name': 'Karnataka', 'code': '29'},
    {'name': 'Goa', 'code': '30'},
    {'name': 'Lakshadweep', 'code': '31'},
    {'name': 'Kerala', 'code': '32'},
    {'name': 'Tamil Nadu', 'code': '33'},
    {'name': 'Puducherry', 'code': '34'},
    {'name': 'Andaman & Nicobar Islands', 'code': '35'},
    {'name': 'Telangana', 'code': '36'},
    {'name': 'Andhra Pradesh (New)', 'code': '37'},
    {'name': 'Ladakh', 'code': '38'},
    {'name': 'Other Territory', 'code': '97'},
  ];

  @override
  Future<void> createState(String companyId, StateMasterModel state) async {
    final docRef = state.stateId.isEmpty
        ? _statesRef(companyId).doc()
        : _statesRef(companyId).doc(state.stateId);

    await docRef.set(state.toFirestoreMap(isUpdate: false));
  }

  @override
  Future<void> updateState(String companyId, StateMasterModel state) async {
    await _statesRef(companyId)
        .doc(state.stateId)
        .update(state.toFirestoreMap(isUpdate: true));
  }

  @override
  Future<void> deleteState(String companyId, String stateId) async {
    await _statesRef(companyId).doc(stateId).delete();
  }

  @override
  Stream<List<StateMasterModel>> streamStates(String companyId) {
    return _statesRef(companyId)
        .orderBy('stateCode')
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) {
        return StateMasterModel.fromMap(doc.data(), doc.id);
      }).toList();
    });
  }

  @override
  Future<bool> isDuplicate(String companyId, String stateName, String stateCode, {String? excludeStateId}) async {
    final nameLower = stateName.trim().toLowerCase();
    final codeLower = stateCode.trim().toLowerCase();

    final snap = await _statesRef(companyId).get();
    for (final doc in snap.docs) {
      if (excludeStateId != null && doc.id == excludeStateId) continue;
      final existingName = (doc.data()['stateName'] ?? '').toString().trim().toLowerCase();
      final existingCode = (doc.data()['stateCode'] ?? '').toString().trim().toLowerCase();

      // Check duplicate name or duplicate code
      if (existingName == nameLower || existingCode == codeLower) {
        return true;
      }
    }
    return false;
  }

  @override
  Future<void> seedDefaultIndianStatesIfEmpty(String companyId) async {
    if (companyId.isEmpty) return;
    final collection = _statesRef(companyId);
    final snap = await collection.limit(1).get();

    // Only seed initial data when records do not already exist. Never overwrite existing user data.
    if (snap.docs.isNotEmpty) return;

    final batch = _firestore.batch();
    for (final item in defaultIndianStates) {
      final docRef = collection.doc();
      batch.set(docRef, {
        'companyId': companyId,
        'stateName': item['name']!,
        'stateCode': item['code']!,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
    }
    await batch.commit();
  }
}
