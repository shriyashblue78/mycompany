import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../domain/models/rejection_reason_model.dart';
import '../../domain/repositories/rejection_reason_repository.dart';
import '../../data/repositories/rejection_reason_repository_impl.dart';

final rejectionReasonRepositoryProvider = Provider<RejectionReasonRepository>((ref) {
  return RejectionReasonRepositoryImpl();
});

final rejectionReasonSearchQueryProvider = StateProvider<String>((ref) => '');

final companyRejectionReasonsStreamProvider = StreamProvider<List<RejectionReasonModel>>((ref) {
  final authState = ref.watch(authProvider);
  final companyId = authState.user?.companyId;
  if (companyId == null || companyId.isEmpty) {
    return Stream.value([]);
  }
  return ref.watch(rejectionReasonRepositoryProvider).streamReasons(companyId);
});

final filteredRejectionReasonsProvider = Provider<AsyncValue<List<RejectionReasonModel>>>((ref) {
  final reasonsAsync = ref.watch(companyRejectionReasonsStreamProvider);
  final query = ref.watch(rejectionReasonSearchQueryProvider).trim().toLowerCase();

  return reasonsAsync.whenData((list) {
    if (query.isEmpty) return list;
    return list.where((r) {
      return r.reasonName.toLowerCase().contains(query);
    }).toList();
  });
});
