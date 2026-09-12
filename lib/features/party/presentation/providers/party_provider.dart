import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../domain/models/party_model.dart';
import '../../domain/repositories/party_repository.dart';
import '../../data/repositories/party_repository_impl.dart';

// Repository Provider
final partyRepositoryProvider = Provider<PartyRepository>((ref) {
  return PartyRepositoryImpl();
});

// Search filter state provider (searches by Party Name, GSTIN, Vendor Code)
final partySearchQueryProvider = StateProvider<String>((ref) => '');

// Party Type Filter State Provider ('All', 'Customer', 'Supplier')
final partyTypeFilterProvider = StateProvider<String>((ref) => 'All');

// Stream of all parties in the company
final companyPartiesStreamProvider = StreamProvider<List<PartyModel>>((ref) {
  final authState = ref.watch(authProvider);
  final companyId = authState.user?.companyId;
  if (companyId == null) {
    return Stream.value([]);
  }
  return ref.watch(partyRepositoryProvider).streamParties(companyId);
});

// Filtered list of parties (synchronous provider derived from companyPartiesStreamProvider)
final filteredPartiesProvider = Provider<AsyncValue<List<PartyModel>>>((ref) {
  final partiesAsync = ref.watch(companyPartiesStreamProvider);
  final query = ref.watch(partySearchQueryProvider).trim().toLowerCase();
  final typeFilter = ref.watch(partyTypeFilterProvider);

  return partiesAsync.whenData((list) {
    return list.where((party) {
      if (typeFilter != 'All' && party.partyType != typeFilter) {
        return false;
      }
      if (query.isEmpty) return true;
      final nameMatch = party.partyName.toLowerCase().contains(query);
      final gstinMatch = party.gstin.toLowerCase().contains(query);
      final vendorCodeMatch = party.vendorCode.toLowerCase().contains(query);
      return nameMatch || gstinMatch || vendorCodeMatch;
    }).toList();
  });
});

// Single party details stream
final partyDetailsStreamProvider = StreamProvider.family<PartyModel?, String>((ref, partyId) {
  final authState = ref.watch(authProvider);
  final companyId = authState.user?.companyId;
  if (companyId == null) {
    return Stream.value(null);
  }
  return ref.watch(partyRepositoryProvider).streamPartyById(companyId, partyId);
});
