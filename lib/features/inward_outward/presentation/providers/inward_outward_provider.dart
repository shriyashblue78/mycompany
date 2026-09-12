import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../data/repositories/inward_outward_repository_impl.dart';
import '../../domain/models/inward_outward_model.dart';

final inwardOutwardListStreamProvider = StreamProvider.autoDispose<List<InwardOutwardModel>>((ref) {
  final authState = ref.watch(authProvider);
  final companyId = authState.user?.companyId ?? '';
  if (companyId.isEmpty) return Stream.value([]);

  final repository = ref.watch(inwardOutwardRepositoryProvider);
  return repository.streamRecords(companyId);
});

class InwardOutwardStats {
  final int totalCount;
  final int inwardCount;
  final int outwardCount;

  const InwardOutwardStats({
    required this.totalCount,
    required this.inwardCount,
    required this.outwardCount,
  });
}

final inwardOutwardStatsProvider = Provider.autoDispose<InwardOutwardStats>((ref) {
  final recordsAsync = ref.watch(inwardOutwardListStreamProvider);
  final records = recordsAsync.asData?.value ?? [];

  int inward = 0;
  int outward = 0;

  for (final r in records) {
    if (r.direction.toLowerCase() == 'inward') {
      inward++;
    } else {
      outward++;
    }
  }

  return InwardOutwardStats(
    totalCount: records.length,
    inwardCount: inward,
    outwardCount: outward,
  );
});
