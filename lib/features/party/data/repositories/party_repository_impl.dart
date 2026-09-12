import 'package:cloud_firestore/cloud_firestore.dart';
import '../../domain/models/party_model.dart';
import '../../domain/repositories/party_repository.dart';

class PartyRepositoryImpl implements PartyRepository {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  @override
  Future<void> createParty(String companyId, PartyModel party) async {
    await _firestore
        .collection('companies')
        .doc(companyId)
        .collection('parties')
        .doc(party.partyId)
        .set(party.toFirestoreMap(isUpdate: false));
  }

  @override
  Future<void> updateParty(String companyId, PartyModel party) async {
    await _firestore
        .collection('companies')
        .doc(companyId)
        .collection('parties')
        .doc(party.partyId)
        .update(party.toFirestoreMap(isUpdate: true));
  }

  @override
  Future<void> deleteParty(String companyId, String partyId) async {
    await _firestore
        .collection('companies')
        .doc(companyId)
        .collection('parties')
        .doc(partyId)
        .delete();
  }

  @override
  Stream<List<PartyModel>> streamParties(String companyId) {
    return _firestore
        .collection('companies')
        .doc(companyId)
        .collection('parties')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) {
        return PartyModel.fromMap(doc.data(), doc.id);
      }).toList();
    });
  }

  @override
  Stream<PartyModel?> streamPartyById(String companyId, String partyId) {
    return _firestore
        .collection('companies')
        .doc(companyId)
        .collection('parties')
        .doc(partyId)
        .snapshots()
        .map((doc) {
      if (doc.exists && doc.data() != null) {
        return PartyModel.fromMap(doc.data()!, doc.id);
      }
      return null;
    });
  }
}
