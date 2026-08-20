import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_sizes.dart';
import '../../../../core/widgets/erp_drawer.dart';
import '../../../../core/widgets/responsive_layout.dart';
import '../../../../core/widgets/responsive_widgets.dart';
import '../providers/sales_provider.dart';
import '../../domain/models/sale_model.dart';
import '../../../auth/presentation/providers/auth_provider.dart';

// Selected date filter state ('Today', 'This Week', 'This Month', 'Custom Date Range')
final salesDateFilterProvider = StateProvider<String>((ref) => 'Today');
final salesCustomDateRangeProvider = StateProvider<DateTimeRange?>((ref) => null);

class SalesAnalyticsScreen extends ConsumerWidget {
  const SalesAnalyticsScreen({super.key});

  // Indian Rupee currency format (e.g. ₹2,45,000)
  String formatIndianRupees(double amount) {
    final formatter = NumberFormat.currency(
      locale: 'en_IN',
      symbol: '₹',
      decimalDigits: 0,
    );
    return formatter.format(amount);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final salesAsync = ref.watch(companySalesStreamProvider);
    final dateFilter = ref.watch(salesDateFilterProvider);
    final customDateRange = ref.watch(salesCustomDateRangeProvider);

    final authState = ref.watch(authProvider);
    final company = authState.selectedCompany ?? 'Apex Industries';

    final isMobile = ResponsiveLayout.isMobile(context);

    // Categories filter options
    final dateFilters = [
      'Today',
      'This Week',
      'This Month',
      'Custom Date Range',
    ];

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    bool isWithinFilter(DateTime date) {
      final cleanDate = DateTime(date.year, date.month, date.day);
      if (dateFilter == 'Today') {
        return cleanDate.year == now.year && cleanDate.month == now.month && cleanDate.day == now.day;
      } else if (dateFilter == 'This Week') {
        final weekday = today.weekday;
        final startOfWeek = today.subtract(Duration(days: weekday - 1));
        final endOfWeek = today.add(Duration(days: 7 - weekday));
        return (cleanDate.isAfter(startOfWeek) || cleanDate.isAtSameMomentAs(startOfWeek)) &&
            (cleanDate.isBefore(endOfWeek) || cleanDate.isAtSameMomentAs(endOfWeek));
      } else if (dateFilter == 'This Month') {
        return cleanDate.year == now.year && cleanDate.month == now.month;
      } else if (dateFilter == 'Custom Date Range') {
        if (customDateRange == null) return false;
        final start = DateTime(customDateRange.start.year, customDateRange.start.month, customDateRange.start.day);
        final end = DateTime(customDateRange.end.year, customDateRange.end.month, customDateRange.end.day);
        return (cleanDate.isAfter(start) || cleanDate.isAtSameMomentAs(start)) &&
            (cleanDate.isBefore(end) || cleanDate.isAtSameMomentAs(end));
      }
      return false;
    }

    Widget buildScreenContent(List<SaleModel> allSales) {
      // 1. Filter out Cancelled sales immediately
      final activeSales = allSales.where((s) => s.status != 'Cancelled').toList();

      // 2. Filter by selected date option
      final periodSales = activeSales.where((s) => isWithinFilter(s.saleDate)).toList();

      // 3. Compute Metrics
      final double totalSalesAmount = periodSales.fold(0.0, (sum, s) => sum + s.totalAmount);
      final int salesCount = periodSales.length;
      final double avgSaleValue = salesCount > 0 ? totalSalesAmount / salesCount : 0.0;
      final double highestSale = salesCount > 0
          ? periodSales.map((s) => s.totalAmount).reduce((a, b) => a > b ? a : b)
          : 0.0;
      final double lowestSale = salesCount > 0
          ? periodSales.map((s) => s.totalAmount).reduce((a, b) => a < b ? a : b)
          : 0.0;

      // 4. Monthly Comparison computation (only when 'This Month' is selected)
      double currentMonthSum = 0.0;
      double previousMonthSum = 0.0;
      double diffSum = 0.0;
      double percentChange = 0.0;
      bool hasPreviousMonthData = false;

      if (dateFilter == 'This Month') {
        final prevMonthYear = now.month == 1 ? now.year - 1 : now.year;
        final prevMonth = now.month == 1 ? 12 : now.month - 1;

        final currentMonthSales = activeSales.where((s) => s.saleDate.year == now.year && s.saleDate.month == now.month).toList();
        final previousMonthSales = activeSales.where((s) => s.saleDate.year == prevMonthYear && s.saleDate.month == prevMonth).toList();

        currentMonthSum = currentMonthSales.fold(0.0, (sum, s) => sum + s.totalAmount);
        previousMonthSum = previousMonthSales.fold(0.0, (sum, s) => sum + s.totalAmount);
        diffSum = currentMonthSum - previousMonthSum;

        hasPreviousMonthData = previousMonthSales.isNotEmpty;
        if (hasPreviousMonthData && previousMonthSum > 0) {
          percentChange = (diffSum / previousMonthSum) * 100;
        }
      }

      // 5. Generate trend graph spots
      List<FlSpot> spots = [];
      if (periodSales.isEmpty) {
        spots = [const FlSpot(0, 0)];
      } else {
        if (dateFilter == 'Today') {
          final hourly = <int, double>{};
          for (final s in periodSales) {
            hourly[s.saleDate.hour] = (hourly[s.saleDate.hour] ?? 0.0) + s.totalAmount;
          }
          spots = List.generate(24, (i) => FlSpot(i.toDouble(), hourly[i] ?? 0.0));
        } else if (dateFilter == 'This Week') {
          final weekly = <int, double>{};
          for (final s in periodSales) {
            weekly[s.saleDate.weekday] = (weekly[s.saleDate.weekday] ?? 0.0) + s.totalAmount;
          }
          spots = List.generate(7, (i) => FlSpot((i + 1).toDouble(), weekly[i + 1] ?? 0.0));
        } else if (dateFilter == 'This Month') {
          final monthly = <int, double>{};
          for (final s in periodSales) {
            monthly[s.saleDate.day] = (monthly[s.saleDate.day] ?? 0.0) + s.totalAmount;
          }
          spots = List.generate(now.day, (i) => FlSpot((i + 1).toDouble(), monthly[i + 1] ?? 0.0));
        } else {
          // Custom range: sort sales chronologically and plot index vs amount
          final sorted = List<SaleModel>.from(periodSales)..sort((a, b) => a.saleDate.compareTo(b.saleDate));
          spots = List.generate(sorted.length, (i) => FlSpot(i.toDouble(), sorted[i].totalAmount));
        }
      }

      final Widget statsWidget = GridView.count(
        crossAxisCount: isMobile ? 2 : 4,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        crossAxisSpacing: AppSizes.p12,
        mainAxisSpacing: AppSizes.p12,
        childAspectRatio: isMobile ? 1.6 : 1.5,
        children: [
          _buildStatCard(theme, 'Total Sales', formatIndianRupees(totalSalesAmount), Colors.teal),
          _buildStatCard(theme, 'Number of Sales', '$salesCount', Colors.blue),
          _buildStatCard(theme, 'Average Value', formatIndianRupees(avgSaleValue), Colors.purple),
          _buildStatCard(theme, 'Highest / Lowest', '${formatIndianRupees(highestSale)} / ${formatIndianRupees(lowestSale)}', Colors.amber),
        ],
      );

      final Widget graphWidget = Card(
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: theme.dividerColor.withAlpha(40)),
        ),
        child: Padding(
          padding: const EdgeInsets.all(AppSizes.p16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Sales Trend Graph',
                style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              SizedBox(
                height: 180,
                child: LineChart(
                  LineChartData(
                    gridData: const FlGridData(show: false),
                    titlesData: FlTitlesData(
                      leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                      topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                      rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                      bottomTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          getTitlesWidget: (value, meta) {
                            if (dateFilter == 'This Week') {
                              const days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
                              final idx = value.toInt() - 1;
                              if (idx >= 0 && idx < 7) {
                                return SideTitleWidget(
                                  axisSide: meta.axisSide,
                                  child: Text(days[idx], style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w500)),
                                );
                              }
                            } else if (dateFilter == 'This Month') {
                              if (value.toInt() % 5 == 0 || value.toInt() == 1) {
                                return SideTitleWidget(
                                  axisSide: meta.axisSide,
                                  child: Text('${value.toInt()}', style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w500)),
                                );
                              }
                            } else if (dateFilter == 'Today') {
                              if (value.toInt() % 4 == 0) {
                                return SideTitleWidget(
                                  axisSide: meta.axisSide,
                                  child: Text('${value.toInt()}:00', style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w500)),
                                );
                              }
                            }
                            return const SizedBox.shrink();
                          },
                        ),
                      ),
                    ),
                    borderData: FlBorderData(show: false),
                    lineBarsData: [
                      LineChartBarData(
                        spots: spots,
                        isCurved: true,
                        barWidth: 3,
                        color: theme.colorScheme.primary,
                        dotData: const FlDotData(show: false),
                        belowBarData: BarAreaData(
                          show: true,
                          color: theme.colorScheme.primary.withOpacity(0.1),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      );

      final Widget monthlyComparisonWidget = Card(
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: theme.dividerColor.withAlpha(40)),
        ),
        child: Padding(
          padding: const EdgeInsets.all(AppSizes.p16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Monthly Comparison',
                style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              if (!hasPreviousMonthData)
                Text(
                  'No previous-period data available.',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.textTheme.bodyMedium?.color?.withOpacity(0.5),
                    fontStyle: FontStyle.italic,
                  ),
                )
              else ...[
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('This Month', style: TextStyle(color: theme.textTheme.bodySmall?.color)),
                    Text(formatIndianRupees(currentMonthSum), style: const TextStyle(fontWeight: FontWeight.bold)),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Previous Month', style: TextStyle(color: theme.textTheme.bodySmall?.color)),
                    Text(formatIndianRupees(previousMonthSum), style: const TextStyle(fontWeight: FontWeight.bold)),
                  ],
                ),
                const Divider(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Difference', style: TextStyle(color: theme.textTheme.bodySmall?.color)),
                    Text(
                      '${diffSum >= 0 ? '+' : ''}${formatIndianRupees(diffSum)}',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: diffSum >= 0 ? Colors.green : Colors.red,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Percentage Change', style: TextStyle(color: theme.textTheme.bodySmall?.color)),
                    Text(
                      '${percentChange >= 0 ? '+' : ''}${percentChange.toStringAsFixed(2)}%',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: percentChange >= 0 ? Colors.green : Colors.red,
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      );

      final Widget breakdownWidget = Card(
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: theme.dividerColor.withAlpha(40)),
        ),
        child: Padding(
          padding: const EdgeInsets.all(AppSizes.p16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Sales Breakdown List',
                style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              if (periodSales.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 24),
                  child: Center(child: Text('No matching sales recorded in this period.')),
                )
              else
                ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: periodSales.length,
                  separatorBuilder: (context, index) => Divider(height: 1, color: theme.dividerColor.withAlpha(35)),
                  itemBuilder: (context, index) {
                    final sale = periodSales[index];
                    return ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(
                        'Sale ${sale.saleNumber}',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                      ),
                      subtitle: Text(
                        'Customer: ${sale.customerName}\nDate: ${DateFormat('yyyy-MM-dd HH:mm').format(sale.saleDate)}',
                        style: const TextStyle(fontSize: 12),
                      ),
                      trailing: Text(
                        formatIndianRupees(sale.totalAmount),
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: theme.colorScheme.primary,
                          fontSize: 15,
                        ),
                      ),
                      isThreeLine: true,
                    );
                  },
                ),
            ],
          ),
        ),
      );

      return SingleChildScrollView(
        padding: EdgeInsets.symmetric(
          horizontal: isMobile ? AppSizes.p16 : AppSizes.p24,
          vertical: AppSizes.p16,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Date Filter selector
            Container(
              height: 48,
              margin: const EdgeInsets.only(bottom: AppSizes.p16),
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: dateFilters.length,
                separatorBuilder: (_, __) => const SizedBox(width: 8),
                itemBuilder: (context, index) {
                  final filter = dateFilters[index];
                  final isSelected = dateFilter == filter;
                  return ChoiceChip(
                    label: Text(
                      filter,
                      style: TextStyle(
                        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                        color: isSelected
                            ? Colors.white
                            : (isDark ? Colors.white70 : Colors.black87),
                      ),
                    ),
                    selected: isSelected,
                    selectedColor: isDark ? theme.colorScheme.primary : AppColors.primaryLight,
                    backgroundColor: isDark ? theme.colorScheme.surface : Colors.grey.shade200,
                    onSelected: (selected) async {
                      if (selected) {
                        if (filter == 'Custom Date Range') {
                          final DateTimeRange? picked = await showDateRangePicker(
                            context: context,
                            firstDate: DateTime(2020),
                            lastDate: DateTime.now(),
                            initialDateRange: customDateRange ??
                                DateTimeRange(
                                  start: DateTime.now().subtract(const Duration(days: 7)),
                                  end: DateTime.now(),
                                ),
                          );
                          if (picked != null) {
                            ref.read(salesDateFilterProvider.notifier).state = filter;
                            ref.read(salesCustomDateRangeProvider.notifier).state = picked;
                          }
                        } else {
                          ref.read(salesDateFilterProvider.notifier).state = filter;
                        }
                      }
                    },
                  );
                },
              ),
            ),

            if (dateFilter == 'Custom Date Range' && customDateRange != null)
              Card(
                margin: const EdgeInsets.only(bottom: AppSizes.p16),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Row(
                    children: [
                      const Icon(Icons.date_range_rounded, size: 16),
                      const SizedBox(width: 8),
                      Text(
                        'Range: ${DateFormat('yyyy-MM-dd').format(customDateRange.start)} to ${DateFormat('yyyy-MM-dd').format(customDateRange.end)}',
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
                      ),
                    ],
                  ),
                ),
              ),

            // Main prominence card: Total Sales
            Card(
              color: isDark ? theme.colorScheme.surface : AppColors.primaryLight,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            dateFilter == 'Today' ? "Today's Sales" : 'Period Sales Total',
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            formatIndianRupees(totalSalesAmount),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 32,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Icon(
                      Icons.trending_up_rounded,
                      color: Colors.white24,
                      size: 48,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: AppSizes.p20),

            // Responsive Layout for graph and comparison side by side
            if (isMobile) ...[
              statsWidget,
              const SizedBox(height: AppSizes.p16),
              graphWidget,
              const SizedBox(height: AppSizes.p16),
              if (dateFilter == 'This Month') ...[
                monthlyComparisonWidget,
                const SizedBox(height: AppSizes.p16),
              ],
              breakdownWidget,
            ] else ...[
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    flex: 2,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        graphWidget,
                        const SizedBox(height: AppSizes.p16),
                        breakdownWidget,
                      ],
                    ),
                  ),
                  const SizedBox(width: AppSizes.p16),
                  Expanded(
                    flex: 1,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        statsWidget,
                        const SizedBox(height: AppSizes.p16),
                        if (dateFilter == 'This Month') ...[
                          monthlyComparisonWidget,
                          const SizedBox(height: AppSizes.p16),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      );
    }

    return ResponsiveScaffold(
      appBar: AppBar(
        title: const Text('Sales Analytics'),
        elevation: 0,
        backgroundColor: theme.colorScheme.surface,
        iconTheme: IconThemeData(color: theme.colorScheme.onSurface),
      ),
      drawer: const ERPDrawer(),
      body: SafeArea(
        child: salesAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (err, _) => Center(child: Text('Error loading sales: $err')),
          data: (allSales) => buildScreenContent(allSales),
        ),
      ),
    );
  }

  Widget _buildStatCard(ThemeData theme, String label, String value, Color color) {
    return Card(
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: theme.dividerColor.withAlpha(40)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: AppSizes.p12, vertical: AppSizes.p8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: color.withOpacity(0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.show_chart_rounded, size: 16, color: color),
            ),
            const SizedBox(height: 8),
            Text(
              value,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(
                color: theme.textTheme.bodySmall?.color?.withOpacity(0.6),
                fontSize: 11,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}
