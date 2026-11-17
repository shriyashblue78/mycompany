import 'package:flutter/material.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/utils/file_saver.dart';
import '../../domain/models/chat_message.dart';
import '../utils/business_report_exporter.dart';

class VisualReportCard extends StatelessWidget {
  final BusinessReportActionData report;
  final bool isDark;

  const VisualReportCard({
    super.key,
    required this.report,
    required this.isDark,
  });

  Future<void> _exportPdf(BuildContext context) async {
    try {
      final bytes = await BusinessReportExporter.generatePdf(
        title: report.title,
        subtitle: report.subtitle,
        reportType: report.reportType,
        data: report.data,
      );
      final filename = '${report.reportType}_${DateTime.now().millisecondsSinceEpoch}.pdf';
      await saveFile(bytes, filename, 'application/pdf');
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Report exported to PDF ($filename)')),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to export PDF: $e')),
        );
      }
    }
  }

  Future<void> _exportCsv(BuildContext context) async {
    try {
      final bytes = BusinessReportExporter.generateCsv(
        title: report.title,
        reportType: report.reportType,
        data: report.data,
      );
      final filename = '${report.reportType}_${DateTime.now().millisecondsSinceEpoch}.csv';
      await saveFile(bytes, filename, 'text/csv');
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Report exported to CSV/Excel ($filename)')),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to export CSV: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Row with Title & Export Actions
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: isDark ? AppColors.primaryDark.withOpacity(0.2) : AppColors.primaryLight.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  Icons.analytics_rounded,
                  size: 18,
                  color: isDark ? AppColors.primaryDark : AppColors.primaryLight,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      report.title,
                      style: TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.bold,
                        color: isDark ? Colors.white : const Color(0xFF0F172A),
                      ),
                    ),
                    if (report.subtitle.isNotEmpty)
                      Text(
                        report.subtitle,
                        style: TextStyle(
                          fontSize: 11,
                          color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                        ),
                      ),
                  ],
                ),
              ),
              // Export buttons
              Wrap(
                spacing: 4,
                children: [
                  IconButton(
                    icon: const Icon(Icons.picture_as_pdf_outlined, size: 18),
                    tooltip: 'Export PDF',
                    constraints: const BoxConstraints(minWidth: 30, minHeight: 30),
                    padding: const EdgeInsets.all(4),
                    color: isDark ? Colors.redAccent : Colors.red[700],
                    onPressed: () => _exportPdf(context),
                  ),
                  IconButton(
                    icon: const Icon(Icons.table_chart_outlined, size: 18),
                    tooltip: 'Export Excel/CSV',
                    constraints: const BoxConstraints(minWidth: 30, minHeight: 30),
                    padding: const EdgeInsets.all(4),
                    color: isDark ? Colors.greenAccent : Colors.green[700],
                    onPressed: () => _exportCsv(context),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 10),
          const Divider(height: 1, thickness: 1),
          const SizedBox(height: 10),

          // Content body based on report type
          if (report.reportType.contains('comparison'))
            _buildComparisonBody()
          else if (report.reportType == 'party_insights')
            _buildPartyInsightsBody()
          else if (report.reportType == 'inventory_insights')
            _buildInventoryInsightsBody()
          else
            _buildSummaryBody(),
        ],
      ),
    );
  }

  Widget _buildSummaryBody() {
    final total = report.data['total_amount'] ?? 0.0;
    final count = report.data['transaction_count'] ?? 0;
    final pending = report.data['pending_count'] ?? 0;
    final completed = report.data['completed_count'] ?? 0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(child: _buildMetricTile('Total Amount', '₹${total.toString()}', isPrimary: true)),
            const SizedBox(width: 8),
            Expanded(child: _buildMetricTile('Transactions', '$count')),
            const SizedBox(width: 8),
            Expanded(child: _buildMetricTile('Pending', '$pending')),
            const SizedBox(width: 8),
            Expanded(child: _buildMetricTile('Completed', '$completed')),
          ],
        ),
      ],
    );
  }

  Widget _buildComparisonBody() {
    final p1 = report.data['period_1'] as Map<String, dynamic>? ?? {};
    final p2 = report.data['period_2'] as Map<String, dynamic>? ?? {};
    final diff = report.data['difference_amount'] ?? 0.0;
    final pct = report.data['percentage_change'];
    final trend = report.data['trend']?.toString() ?? 'flat';

    final isUp = trend == 'up';
    final isDown = trend == 'down';
    final trendColor = isUp ? Colors.green : (isDown ? Colors.red : Colors.grey);

    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _buildMetricTile(
                p1['label'] ?? 'Period 1',
                '₹${p1['total_amount'] ?? 0}\n(${p1['transaction_count'] ?? 0} tx)',
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _buildMetricTile(
                p2['label'] ?? 'Period 2',
                '₹${p2['total_amount'] ?? 0}\n(${p2['transaction_count'] ?? 0} tx)',
                isPrimary: true,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: trendColor.withOpacity(0.1),
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: trendColor.withOpacity(0.3)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                isUp ? Icons.trending_up_rounded : (isDown ? Icons.trending_down_rounded : Icons.trending_flat_rounded),
                size: 16,
                color: trendColor,
              ),
              const SizedBox(width: 6),
              Text(
                'Change: ₹$diff ${pct != null ? "($pct%)" : ""}',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: trendColor,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildPartyInsightsBody() {
    final parties = report.data['parties'] as List<dynamic>? ?? [];
    if (parties.isEmpty) {
      return const Text('No party transaction data recorded.');
    }

    return Column(
      children: parties.take(4).map((item) {
        final m = item as Map<String, dynamic>;
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 3.0),
          child: Row(
            children: [
              Expanded(
                flex: 2,
                child: Text(
                  m['party_name']?.toString() ?? '',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: isDark ? Colors.white : const Color(0xFF1E293B),
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Text(
                '${m['transaction_count'] ?? 0} orders',
                style: TextStyle(
                  fontSize: 11,
                  color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                ),
              ),
              const SizedBox(width: 12),
              Text(
                '₹${m['total_amount'] ?? 0}',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: isDark ? AppColors.primaryDark : AppColors.primaryLight,
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _buildInventoryInsightsBody() {
    final total = report.data['total_items'] ?? 0;
    final lowCount = report.data['low_stock_count'] ?? 0;
    final lowStock = report.data['low_stock_items'] as List<dynamic>? ?? [];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(child: _buildMetricTile('Total Items', '$total')),
            const SizedBox(width: 8),
            Expanded(
              child: _buildMetricTile(
                'Low Stock Shortage',
                '$lowCount items',
                isAlert: lowCount > 0,
              ),
            ),
          ],
        ),
        if (lowStock.isNotEmpty) ...[
          const SizedBox(height: 8),
          Text(
            'Critical Shortages:',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color: isDark ? const Color(0xFFFCA5A5) : Colors.red[800],
            ),
          ),
          const SizedBox(height: 4),
          ...lowStock.take(3).map((it) {
            final m = it as Map<String, dynamic>;
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 2.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      '${m['item_name']} (${m['item_number']})',
                      style: TextStyle(
                        fontSize: 11.5,
                        color: isDark ? Colors.white70 : const Color(0xFF334155),
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Text(
                    '${m['current_stock']} / min ${m['minimum_level']} ${m['stock_unit']}',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: isDark ? const Color(0xFFF87171) : Colors.red[700],
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ],
    );
  }

  Widget _buildMetricTile(String label, String value, {bool isPrimary = false, bool isAlert = false}) {
    Color bg = isDark ? const Color(0xFF0F172A) : Colors.white;
    Color border = isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0);
    Color textColor = isDark ? Colors.white : const Color(0xFF0F172A);

    if (isAlert) {
      bg = isDark ? const Color(0xFF451A1A) : const Color(0xFFFEF2F2);
      border = isDark ? Colors.red[900]! : Colors.red[200]!;
      textColor = isDark ? const Color(0xFFFCA5A5) : Colors.red[800]!;
    } else if (isPrimary) {
      textColor = isDark ? AppColors.primaryDark : AppColors.primaryLight;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: textColor,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}

