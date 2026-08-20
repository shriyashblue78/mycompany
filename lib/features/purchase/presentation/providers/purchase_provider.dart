import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../domain/models/purchase_model.dart';
import '../../domain/repositories/purchase_repository.dart';
import '../../data/repositories/purchase_repository_impl.dart';

// Repository Provider
final purchaseRepositoryProvider = Provider<PurchaseRepository>((ref) {
  return PurchaseRepositoryImpl();
});

// Search filter state provider (searches by Supplier and Item Name)
final purchaseSearchQueryProvider = StateProvider<String>((ref) => '');

// Stream of all purchases in the company
final companyPurchasesStreamProvider = StreamProvider<List<PurchaseModel>>((ref) {
  final authState = ref.watch(authProvider);
  final companyId = authState.user?.companyId;
  if (companyId == null) {
    return Stream.value([]);
  }
  return ref.watch(purchaseRepositoryProvider).streamPurchases(companyId);
});

// Filtered stream of purchases
final filteredPurchasesProvider = StreamProvider<List<PurchaseModel>>((ref) {
  final purchaseStream = ref.watch(companyPurchasesStreamProvider.stream);
  final query = ref.watch(purchaseSearchQueryProvider).trim().toLowerCase();

  return purchaseStream.map((list) {
    return list.where((purchase) {
      if (query.isEmpty) return true;
      final supplierMatch = purchase.supplierName.toLowerCase().contains(query);
      final itemMatch = purchase.itemName.toLowerCase().contains(query);
      return supplierMatch || itemMatch;
    }).toList();
  });
});

// Single purchase details stream
final purchaseDetailsStreamProvider = StreamProvider.family<PurchaseModel?, String>((ref, purchaseId) {
  final authState = ref.watch(authProvider);
  final companyId = authState.user?.companyId;
  if (companyId == null) {
    return Stream.value(null);
  }
  return ref.watch(purchaseRepositoryProvider).streamPurchaseById(companyId, purchaseId);
});

// Helper class for Purchase Dashboard Stats
class PurchaseStats {
  final double todaySum;
  final int todayCount;
  final double monthSum;
  final int monthCount;
  final double pendingSum;
  final int pendingCount;
  final double totalSum;

  const PurchaseStats({
    required this.todaySum,
    required this.todayCount,
    required this.monthSum,
    required this.monthCount,
    required this.pendingSum,
    required this.pendingCount,
    required this.totalSum,
  });
}

// Provider for calculating purchase metrics
final purchaseStatsProvider = Provider<PurchaseStats>((ref) {
  final purchasesAsync = ref.watch(companyPurchasesStreamProvider);
  return purchasesAsync.maybeWhen(
    data: (list) {
      final now = DateTime.now();
      
      double todaySum = 0.0;
      int todayCount = 0;
      
      double monthSum = 0.0;
      int monthCount = 0;
      
      double totalSum = 0.0;
      
      int pendingCount = 0;
      double pendingSum = 0.0;

      for (final purchase in list) {
        final date = purchase.purchaseDate;
        
        // Calculate total sum of active purchases (Received & Pending) or all purchases.
        // Let's include everything except Cancelled in the Total sum.
        if (purchase.status != 'Cancelled') {
          totalSum += purchase.totalAmount;
        }

        // Today's Purchases (Calendar day check)
        if (date.year == now.year && date.month == now.month && date.day == now.day) {
          todaySum += purchase.totalAmount;
          todayCount++;
        }

        // This Month Purchases
        if (date.year == now.year && date.month == now.month) {
          monthSum += purchase.totalAmount;
          monthCount++;
        }

        // Pending Purchases
        if (purchase.status == 'Pending') {
          pendingSum += purchase.totalAmount;
          pendingCount++;
        }
      }

      return PurchaseStats(
        todaySum: todaySum,
        todayCount: todayCount,
        monthSum: monthSum,
        monthCount: monthCount,
        pendingSum: pendingSum,
        pendingCount: pendingCount,
        totalSum: totalSum,
      );
    },
    orElse: () => const PurchaseStats(
      todaySum: 0.0,
      todayCount: 0,
      monthSum: 0.0,
      monthCount: 0,
      pendingSum: 0.0,
      pendingCount: 0,
      totalSum: 0.0,
    ),
  );
});
