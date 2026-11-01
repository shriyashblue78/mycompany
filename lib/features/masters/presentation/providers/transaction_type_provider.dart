import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../domain/models/transaction_type_model.dart';
import '../../domain/repositories/transaction_type_repository.dart';
import '../../data/repositories/transaction_type_repository_impl.dart';

final transactionTypeRepositoryProvider = Provider<TransactionTypeRepository>((ref) {
  return TransactionTypeRepositoryImpl();
});

final transactionTypeSearchQueryProvider = StateProvider<String>((ref) => '');

final companyTransactionTypesStreamProvider = StreamProvider<List<TransactionTypeModel>>((ref) {
  final authState = ref.watch(authProvider);
  final companyId = authState.user?.companyId;
  if (companyId == null || companyId.isEmpty) {
    return Stream.value([]);
  }
  return ref.watch(transactionTypeRepositoryProvider).streamTransactionTypes(companyId);
});

final filteredTransactionTypesProvider = Provider<AsyncValue<List<TransactionTypeModel>>>((ref) {
  final typesAsync = ref.watch(companyTransactionTypesStreamProvider);
  final query = ref.watch(transactionTypeSearchQueryProvider).trim().toLowerCase();

  return typesAsync.whenData((list) {
    if (query.isEmpty) return list;
    return list.where((t) {
      final nameMatch = t.typeName.toLowerCase().contains(query);
      final catMatch = (t.category ?? '').toLowerCase().contains(query);
      final descMatch = (t.description ?? '').toLowerCase().contains(query);
      return nameMatch || catMatch || descMatch;
    }).toList();
  });
});
