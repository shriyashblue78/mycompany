import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../domain/models/tax_model.dart';
import '../../domain/repositories/tax_repository.dart';
import '../../data/repositories/tax_repository_impl.dart';

final taxRepositoryProvider = Provider<TaxRepository>((ref) {
  return TaxRepositoryImpl();
});

final taxSearchQueryProvider = StateProvider<String>((ref) => '');

final companyTaxesStreamProvider = StreamProvider<List<TaxModel>>((ref) {
  final authState = ref.watch(authProvider);
  final companyId = authState.user?.companyId;
  if (companyId == null || companyId.isEmpty) {
    return Stream.value([]);
  }
  return ref.watch(taxRepositoryProvider).streamTaxes(companyId);
});

final taxDetailsStreamProvider = StreamProvider.family<TaxModel?, String>((ref, taxId) {
  final authState = ref.watch(authProvider);
  final companyId = authState.user?.companyId;
  if (companyId == null || companyId.isEmpty) {
    return Stream.value(null);
  }
  return ref.watch(taxRepositoryProvider).streamTaxById(companyId, taxId);
});

final filteredTaxesProvider = Provider<AsyncValue<List<TaxModel>>>((ref) {
  final taxesAsync = ref.watch(companyTaxesStreamProvider);
  final query = ref.watch(taxSearchQueryProvider).trim().toLowerCase();

  return taxesAsync.whenData((list) {
    if (query.isEmpty) return list;
    return list.where((t) {
      final nameMatch = t.taxCategory.toLowerCase().contains(query);
      final shortMatch = t.shortName.toLowerCase().contains(query);
      final remarkMatch = t.remarkOnInvoice.toLowerCase().contains(query);
      return nameMatch || shortMatch || remarkMatch;
    }).toList();
  });
});
