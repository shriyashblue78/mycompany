import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../domain/models/sale_model.dart';
import '../../domain/repositories/sale_repository.dart';
import '../../data/repositories/sale_repository_impl.dart';

// Repository Provider
final saleRepositoryProvider = Provider<SaleRepository>((ref) {
  return SaleRepositoryImpl();
});

// Search filter state provider (searches by Customer Name and Item Name)
final salesSearchQueryProvider = StateProvider<String>((ref) => '');

// Stream of all sales in the company
final companySalesStreamProvider = StreamProvider<List<SaleModel>>((ref) {
  final authState = ref.watch(authProvider);
  final companyId = authState.user?.companyId;
  if (companyId == null) {
    return Stream.value([]);
  }
  return ref.watch(saleRepositoryProvider).streamSales(companyId);
});

// Filtered stream of sales
final filteredSalesProvider = StreamProvider<List<SaleModel>>((ref) {
  final salesAsync = ref.watch(companySalesStreamProvider);
  final query = ref.watch(salesSearchQueryProvider).trim().toLowerCase();

  final list = salesAsync.value ?? const [];
  final filtered = list.where((sale) {
    if (query.isEmpty) return true;
    final customerMatch = sale.customerName.toLowerCase().contains(query);
    final itemMatch = sale.itemName.toLowerCase().contains(query);
    return customerMatch || itemMatch;
  }).toList();

  return Stream.value(filtered);
});

// Single sale details stream
final saleDetailsStreamProvider = StreamProvider.family<SaleModel?, String>((ref, saleId) {
  final authState = ref.watch(authProvider);
  final companyId = authState.user?.companyId;
  if (companyId == null) {
    return Stream.value(null);
  }
  return ref.watch(saleRepositoryProvider).streamSaleById(companyId, saleId);
});

// Helper class for Sales Dashboard Stats
class SalesStats {
  final double todaySum;
  final int todayCount;
  final double monthSum;
  final int monthCount;
  final double pendingSum;
  final int pendingCount;
  final double totalSum;

  const SalesStats({
    required this.todaySum,
    required this.todayCount,
    required this.monthSum,
    required this.monthCount,
    required this.pendingSum,
    required this.pendingCount,
    required this.totalSum,
  });
}

// Provider for calculating sales metrics
final salesStatsProvider = Provider<SalesStats>((ref) {
  final salesAsync = ref.watch(companySalesStreamProvider);
  return salesAsync.maybeWhen(
    data: (list) {
      final now = DateTime.now();

      double todaySum = 0.0;
      int todayCount = 0;

      double monthSum = 0.0;
      int monthCount = 0;

      double totalSum = 0.0;

      int pendingCount = 0;
      double pendingSum = 0.0;

      for (final sale in list) {
        final date = sale.saleDate;

        // Calculate total sum of active sales (excluding Cancelled)
        if (sale.status != 'Cancelled') {
          totalSum += sale.totalAmount;
        }

        // Today's Sales (Calendar day check)
        if (date.year == now.year && date.month == now.month && date.day == now.day) {
          todaySum += sale.totalAmount;
          todayCount++;
        }

        // This Month Sales
        if (date.year == now.year && date.month == now.month) {
          monthSum += sale.totalAmount;
          monthCount++;
        }

        // Pending Sales
        if (sale.status == 'Pending') {
          pendingSum += sale.totalAmount;
          pendingCount++;
        }
      }

      return SalesStats(
        todaySum: todaySum,
        todayCount: todayCount,
        monthSum: monthSum,
        monthCount: monthCount,
        pendingSum: pendingSum,
        pendingCount: pendingCount,
        totalSum: totalSum,
      );
    },
    orElse: () => const SalesStats(
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
