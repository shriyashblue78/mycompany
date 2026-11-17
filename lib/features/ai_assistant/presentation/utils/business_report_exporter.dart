import 'dart:convert';
import 'dart:typed_data';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

class BusinessReportExporter {
  /// Generates a standardized PDF document for any AI Business Report
  static Future<Uint8List> generatePdf({
    required String title,
    required String subtitle,
    required String reportType,
    required Map<String, dynamic> data,
  }) async {
    final pdf = pw.Document();

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        build: (pw.Context context) {
          final List<pw.Widget> content = [];

          // Header
          content.add(
            pw.Container(
              padding: const pw.EdgeInsets.only(bottom: 12),
              decoration: const pw.BoxDecoration(
                border: pw.Border(
                  bottom: pw.BorderSide(color: PdfColors.grey400, width: 1.5),
                ),
              ),
              child: pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(
                        'PRIMOT ERP - BUSINESS REPORT',
                        style: pw.TextStyle(
                          fontSize: 16,
                          fontWeight: pw.FontWeight.bold,
                          color: PdfColors.blueGrey800,
                        ),
                      ),
                      pw.SizedBox(height: 4),
                      pw.Text(
                        title,
                        style: pw.TextStyle(
                          fontSize: 14,
                          fontWeight: pw.FontWeight.bold,
                        ),
                      ),
                      if (subtitle.isNotEmpty) ...[
                        pw.SizedBox(height: 2),
                        pw.Text(
                          subtitle,
                          style: const pw.TextStyle(
                            fontSize: 10,
                            color: PdfColors.grey700,
                          ),
                        ),
                      ],
                    ],
                  ),
                  pw.Text(
                    DateTime.now().toString().split('.')[0],
                    style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey600),
                  ),
                ],
              ),
            ),
          );

          content.add(pw.SizedBox(height: 16));

          // Body depending on report type
          if (reportType.contains('comparison')) {
            _buildComparisonSection(content, data);
          } else if (reportType == 'party_insights') {
            _buildPartyInsightsSection(content, data);
          } else if (reportType == 'inventory_insights') {
            _buildInventoryInsightsSection(content, data);
          } else {
            _buildSummarySection(content, data);
          }

          return content;
        },
      ),
    );

    return pdf.save();
  }

  static void _buildSummarySection(List<pw.Widget> content, Map<String, dynamic> data) {
    final totalAmount = (data['total_amount'] ?? 0.0).toString();
    final count = (data['transaction_count'] ?? 0).toString();
    final pending = (data['pending_count'] ?? 0).toString();
    final completed = (data['completed_count'] ?? 0).toString();

    content.add(
      pw.Row(
        children: [
          _buildPdfKpiCard('Total Amount', 'Rs. $totalAmount'),
          pw.SizedBox(width: 8),
          _buildPdfKpiCard('Transactions', count),
          pw.SizedBox(width: 8),
          _buildPdfKpiCard('Pending', pending),
          pw.SizedBox(width: 8),
          _buildPdfKpiCard('Completed', completed),
        ],
      ),
    );

    content.add(pw.SizedBox(height: 16));

    final rawTx = data['transactions'] as List<dynamic>? ?? [];
    if (rawTx.isNotEmpty) {
      content.add(
        pw.Text(
          'Transactions List',
          style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold),
        ),
      );
      content.add(pw.SizedBox(height: 8));

      final headers = ['Ref #', 'Date', 'Party', 'Status', 'Amount'];
      final rows = rawTx.map((t) {
        final map = t as Map<String, dynamic>;
        return [
          map['reference_number']?.toString() ?? '',
          map['date']?.toString() ?? '',
          map['party_name']?.toString() ?? '',
          map['status']?.toString() ?? '',
          'Rs. ${map['total_amount'] ?? 0}',
        ];
      }).toList();

      content.add(
        pw.TableHelper.fromTextArray(
          headers: headers,
          data: rows,
          headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9),
          cellStyle: const pw.TextStyle(fontSize: 8.5),
          headerDecoration: const pw.BoxDecoration(color: PdfColors.grey200),
          cellAlignment: pw.Alignment.centerLeft,
        ),
      );
    }
  }

  static void _buildComparisonSection(List<pw.Widget> content, Map<String, dynamic> data) {
    final p1 = data['period_1'] as Map<String, dynamic>? ?? {};
    final p2 = data['period_2'] as Map<String, dynamic>? ?? {};
    final diff = (data['difference_amount'] ?? 0.0).toString();
    final pct = data['percentage_change'] != null ? '${data['percentage_change']}%' : 'N/A';
    final trend = data['trend']?.toString().toUpperCase() ?? 'FLAT';

    content.add(
      pw.Row(
        children: [
          _buildPdfKpiCard(p1['label'] ?? 'Period 1', 'Rs. ${p1['total_amount'] ?? 0} (${p1['transaction_count'] ?? 0} tx)'),
          pw.SizedBox(width: 12),
          _buildPdfKpiCard(p2['label'] ?? 'Period 2', 'Rs. ${p2['total_amount'] ?? 0} (${p2['transaction_count'] ?? 0} tx)'),
          pw.SizedBox(width: 12),
          _buildPdfKpiCard('Difference / Growth', 'Rs. $diff ($pct) [$trend]'),
        ],
      ),
    );
  }

  static void _buildPartyInsightsSection(List<pw.Widget> content, Map<String, dynamic> data) {
    final parties = data['parties'] as List<dynamic>? ?? [];
    content.add(
      pw.Text(
        'Top Parties Ranking',
        style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold),
      ),
    );
    content.add(pw.SizedBox(height: 8));

    final headers = ['Rank', 'Party Name', 'Type', 'Orders', 'Total Volume'];
    final rows = <List<String>>[];
    for (int i = 0; i < parties.length; i++) {
      final p = parties[i] as Map<String, dynamic>;
      rows.add([
        '#${i + 1}',
        p['party_name']?.toString() ?? '',
        p['party_type']?.toString() ?? 'Customer',
        (p['transaction_count'] ?? 0).toString(),
        'Rs. ${p['total_amount'] ?? 0}',
      ]);
    }

    content.add(
      pw.TableHelper.fromTextArray(
        headers: headers,
        data: rows,
        headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9),
        cellStyle: const pw.TextStyle(fontSize: 8.5),
        headerDecoration: const pw.BoxDecoration(color: PdfColors.grey200),
      ),
    );
  }

  static void _buildInventoryInsightsSection(List<pw.Widget> content, Map<String, dynamic> data) {
    final total = (data['total_items'] ?? 0).toString();
    final lowCount = (data['low_stock_count'] ?? 0).toString();

    content.add(
      pw.Row(
        children: [
          _buildPdfKpiCard('Total Tracked Items', total),
          pw.SizedBox(width: 12),
          _buildPdfKpiCard('Low Stock Shortages', lowCount),
        ],
      ),
    );

    content.add(pw.SizedBox(height: 14));

    final lowStock = data['low_stock_items'] as List<dynamic>? ?? [];
    if (lowStock.isNotEmpty) {
      content.add(
        pw.Text(
          'Low Stock Items (Below Minimum Level)',
          style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold, color: PdfColors.red800),
        ),
      );
      content.add(pw.SizedBox(height: 6));

      final headers = ['Item No', 'Item Name', 'Category', 'Current', 'Min', 'Shortage'];
      final rows = lowStock.map((it) {
        final m = it as Map<String, dynamic>;
        return [
          m['item_number']?.toString() ?? '',
          m['item_name']?.toString() ?? '',
          m['category']?.toString() ?? '',
          '${m['current_stock']} ${m['stock_unit']}',
          '${m['minimum_level']}',
          '${m['shortage']}',
        ];
      }).toList();

      content.add(
        pw.TableHelper.fromTextArray(
          headers: headers,
          data: rows,
          headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 8.5),
          cellStyle: const pw.TextStyle(fontSize: 8),
          headerDecoration: const pw.BoxDecoration(color: PdfColors.red50),
        ),
      );
    }
  }

  static pw.Widget _buildPdfKpiCard(String label, String value) {
    return pw.Expanded(
      child: pw.Container(
        padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: pw.BoxDecoration(
          border: pw.Border.all(color: PdfColors.grey300),
          borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6)),
          color: PdfColors.grey50,
        ),
        child: pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text(label, style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey700)),
            pw.SizedBox(height: 4),
            pw.Text(value, style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold)),
          ],
        ),
      ),
    );
  }

  /// Generates clean CSV content for Excel export
  static Uint8List generateCsv({
    required String title,
    required String reportType,
    required Map<String, dynamic> data,
  }) {
    final buffer = StringBuffer();
    buffer.writeln('PRIMOT ERP - $title');
    buffer.writeln('Export Date: ${DateTime.now().toIsoformat()}');
    buffer.writeln();

    if (reportType.contains('comparison')) {
      final p1 = data['period_1'] as Map<String, dynamic>? ?? {};
      final p2 = data['period_2'] as Map<String, dynamic>? ?? {};
      buffer.writeln('Period,Total Amount (INR),Transaction Count');
      buffer.writeln('"${p1['label']}",${p1['total_amount']},${p1['transaction_count']}');
      buffer.writeln('"${p2['label']}",${p2['total_amount']},${p2['transaction_count']}');
      buffer.writeln('Difference,${data['difference_amount']},Growth: ${data['percentage_change']}%');
    } else if (reportType == 'party_insights') {
      final parties = data['parties'] as List<dynamic>? ?? [];
      buffer.writeln('Rank,Party Name,Type,Orders Count,Total Amount (INR)');
      for (int i = 0; i < parties.length; i++) {
        final p = parties[i] as Map<String, dynamic>;
        buffer.writeln('${i + 1},"${p['party_name']}","${p['party_type']}",${p['transaction_count']},${p['total_amount']}');
      }
    } else if (reportType == 'inventory_insights') {
      buffer.writeln('Total Items: ${data['total_items']}, Low Stock Count: ${data['low_stock_count']}');
      buffer.writeln('Item Number,Item Name,Category,Current Stock,Minimum Level,Shortage,Unit');
      final items = data['low_stock_items'] as List<dynamic>? ?? [];
      for (final it in items) {
        final m = it as Map<String, dynamic>;
        buffer.writeln('"${m['item_number']}","${m['item_name']}","${m['category']}",${m['current_stock']},${m['minimum_level']},${m['shortage']},"${m['stock_unit']}"');
      }
    } else {
      buffer.writeln('Metric,Value');
      buffer.writeln('Total Amount (INR),${data['total_amount']}');
      buffer.writeln('Transaction Count,${data['transaction_count']}');
      buffer.writeln('Pending Count,${data['pending_count']}');
      buffer.writeln('Completed Count,${data['completed_count']}');
      buffer.writeln();

      final rawTx = data['transactions'] as List<dynamic>? ?? [];
      if (rawTx.isNotEmpty) {
        buffer.writeln('Reference Number,Date,Party Name,Status,Amount (INR)');
        for (final t in rawTx) {
          final m = t as Map<String, dynamic>;
          buffer.writeln('"${m['reference_number']}","${m['date']}","${m['party_name']}","${m['status']}",${m['total_amount']}');
        }
      }
    }

    return Uint8List.fromList(utf8.encode(buffer.toString()));
  }
}

extension on DateTime {
  String toIsoformat() {
    return '${year.toString().padLeft(4, '0')}-${month.toString().padLeft(2, '0')}-${day.toString().padLeft(2, '0')} '
        '${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}';
  }
}

