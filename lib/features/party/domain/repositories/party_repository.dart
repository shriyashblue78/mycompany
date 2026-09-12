import '../models/party_model.dart';

abstract class PartyRepository {
  Future<void> createParty(String companyId, PartyModel party);
  Future<void> updateParty(String companyId, PartyModel party);
  Future<void> deleteParty(String companyId, String partyId);
  Stream<List<PartyModel>> streamParties(String companyId);
  Stream<PartyModel?> streamPartyById(String companyId, String partyId);
}
