import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_sizes.dart';
import '../../../../core/widgets/responsive_widgets.dart';
import '../../../../core/utils/file_saver.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../domain/models/sale_model.dart';
import '../providers/sales_provider.dart';

class SaleDetailViewScreen extends ConsumerWidget {
  final String saleId;
  const SaleDetailViewScreen({super.key, required this.saleId});

  static Future<void> generateAndDownloadPdf(BuildContext context, SaleModel sale, String companyName) async {
    final pdf = pw.Document();
    final saleDateStr = DateFormat('dd/MM/yyyy').format(sale.saleDate);

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        build: (pw.Context pdfContext) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              // Header
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(
                        companyName.toUpperCase(),
                        style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold),
                      ),
                      pw.SizedBox(height: 4),
                      pw.Text('TAX INVOICE / SALE DOCUMENT', style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold, color: PdfColors.grey700)),
                    ],
                  ),
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.end,
                    children: [
                      pw.Text('Invoice No: ${sale.invoiceNumber ?? sale.saleNumber}', style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
                      pw.Text('Sale Ref: ${sale.saleNumber}', style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey700)),
                      pw.Text('Date: $saleDateStr', style: const pw.TextStyle(fontSize: 10)),
                      pw.Text('Status: ${sale.status}', style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold)),
                    ],
                  ),
                ],
              ),
              pw.SizedBox(height: 16),
              pw.Divider(thickness: 1),
              pw.SizedBox(height: 12),

              // Billed To / Party Section
              pw.Container(
                padding: const pw.EdgeInsets.all(10),
                decoration: pw.BoxDecoration(
                  border: pw.Border.all(color: PdfColors.grey400, width: 0.5),
                  borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
                ),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text('PARTY / CUSTOMER DETAILS', style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold)),
                    pw.SizedBox(height: 6),
                    pw.Row(
                      children: [
                        pw.Expanded(child: pw.Text('Party Name: ${sale.customerName}', style: pw.TextStyle(fontWeight: pw.FontWeight.bold))),
                        pw.Expanded(child: pw.Text('Phone: ${sale.customerPhone}')),
                      ],
                    ),
                    if (sale.partyType.isNotEmpty || sale.vendorCode.isNotEmpty) ...[
                      pw.SizedBox(height: 4),
                      pw.Row(
                        children: [
                          if (sale.partyType.isNotEmpty) pw.Expanded(child: pw.Text('Party Type: ${sale.partyType}')),
                          if (sale.vendorCode.isNotEmpty) pw.Expanded(child: pw.Text('Vendor Code: ${sale.vendorCode}')),
                        ],
                      ),
                    ],
                    if (sale.gstin.isNotEmpty || sale.state.isNotEmpty) ...[
                      pw.SizedBox(height: 4),
                      pw.Row(
                        children: [
                          if (sale.gstin.isNotEmpty) pw.Expanded(child: pw.Text('GSTIN: ${sale.gstin}', style: pw.TextStyle(fontWeight: pw.FontWeight.bold))),
                          if (sale.state.isNotEmpty) pw.Expanded(child: pw.Text('State: ${sale.state} (${sale.stateCode})')),
                        ],
                      ),
                    ],
                    if (sale.contactPersonName.isNotEmpty || sale.email.isNotEmpty) ...[
                      pw.SizedBox(height: 4),
                      pw.Row(
                        children: [
                          if (sale.contactPersonName.isNotEmpty) pw.Expanded(child: pw.Text('Contact Person: ${sale.contactPersonName}')),
                          if (sale.email.isNotEmpty) pw.Expanded(child: pw.Text('Email: ${sale.email}')),
                        ],
                      ),
                    ],
                    if (sale.address.isNotEmpty) ...[
                      pw.SizedBox(height: 4),
                      pw.Text('Address: ${sale.address}'),
                    ],
                  ],
                ),
              ),
              pw.SizedBox(height: 16),

              // Item Details Table
              pw.Text('LINE ITEM DETAILS', style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold)),
              pw.SizedBox(height: 6),
              pw.TableHelper.fromTextArray(
                context: pdfContext,
                headers: <String>['S.No', 'Item Number', 'Item Name', 'HSN Code', 'Qty / Unit', 'Rate (INR)', 'Total (INR)'],
                data: <List<String>>[
                  <String>[
                    '1',
                    sale.itemNumber.isNotEmpty ? sale.itemNumber : '-',
                    sale.itemName,
                    sale.hsnCode.isNotEmpty ? sale.hsnCode : '-',
                    '${sale.quantity} ${sale.unit}',
                    '₹${sale.pricePerUnit.toStringAsFixed(2)}',
                    '₹${sale.totalAmount.toStringAsFixed(2)}',
                  ]
                ],
                headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10),
                cellStyle: const pw.TextStyle(fontSize: 10),
                headerDecoration: const pw.BoxDecoration(color: PdfColors.grey200),
                columnWidths: {
                  0: const pw.FixedColumnWidth(35),
                  1: const pw.FixedColumnWidth(70),
                  2: const pw.FlexColumnWidth(2),
                  3: const pw.FixedColumnWidth(60),
                  4: const pw.FixedColumnWidth(65),
                  5: const pw.FixedColumnWidth(70),
                  6: const pw.FixedColumnWidth(75),
                },
              ),
              pw.SizedBox(height: 16),

              // Total Calculation Summary
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.end,
                children: [
                  pw.Container(
                    width: 200,
                    padding: const pw.EdgeInsets.all(8),
                    decoration: pw.BoxDecoration(
                      border: pw.Border.all(color: PdfColors.grey400, width: 0.5),
                      borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
                    ),
                    child: pw.Column(
                      children: [
                        pw.Row(
                          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                          children: [
                            pw.Text('Subtotal:', style: const pw.TextStyle(fontSize: 10)),
                            pw.Text('₹${sale.totalAmount.toStringAsFixed(2)}', style: const pw.TextStyle(fontSize: 10)),
                          ],
                        ),
                        pw.Divider(thickness: 0.5),
                        pw.Row(
                          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                          children: [
                            pw.Text('Grand Total:', style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold)),
                            pw.Text('₹${sale.totalAmount.toStringAsFixed(2)}', style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold)),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),

              if (sale.remarks.isNotEmpty) ...[
                pw.SizedBox(height: 16),
                pw.Text('Remarks / Terms:', style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold)),
                pw.SizedBox(height: 4),
                pw.Text(sale.remarks, style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey800)),
              ],

              pw.Spacer(),
              pw.Divider(thickness: 0.5),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text('Authorized Signatory', style: const pw.TextStyle(fontSize: 10)),
                  pw.Text('Computer Generated Invoice', style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey600)),
                ],
              ),
            ],
          );
        },
      ),
    );

    final bytes = await pdf.save();
    final fileName = 'Invoice_${sale.invoiceNumber ?? sale.saleNumber}.pdf';
    saveFile(bytes, fileName, 'application/pdf');
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('A4 Invoice PDF ($fileName) downloaded successfully.')),
      );
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final saleDetailsAsync = ref.watch(saleDetailsStreamProvider(saleId));
    final authState = ref.watch(authProvider);
    final companyName = authState.selectedCompany ?? 'Apex Industries';

    return ResponsiveScaffold(
      appBar: AppBar(
        title: const Text('Sale Record View / A4 Document'),
        elevation: 0,
        actions: [
          saleDetailsAsync.maybeWhen(
            data: (sale) {
              if (sale == null) return const SizedBox.shrink();
              return IconButton(
                icon: const Icon(Icons.print_rounded),
                tooltip: 'Download A4 Invoice PDF',
                onPressed: () => generateAndDownloadPdf(context, sale, companyName),
              );
            },
            orElse: () => const SizedBox.shrink(),
          ),
        ],
      ),
      body: saleDetailsAsync.when(
        data: (sale) {
          if (sale == null) {
            return const Center(child: Text('Sale record not found.'));
          }

          final saleDateStr = DateFormat('dd/MM/yyyy').format(sale.saleDate);

          return SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(AppSizes.p24),
              child: Center(
                child: Container(
                  constraints: const BoxConstraints(maxWidth: 800),
                  padding: const EdgeInsets.all(AppSizes.p24),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surface,
                    borderRadius: BorderRadius.circular(AppSizes.cardRadius),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.05),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                    border: Border.all(color: theme.dividerColor.withAlpha(80)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Document Header
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                companyName.toUpperCase(),
                                style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'TAX INVOICE / SALE DOCUMENT',
                                style: theme.textTheme.labelMedium?.copyWith(
                                  fontWeight: FontWeight.bold,
                                  color: theme.colorScheme.primary,
                                ),
                              ),
                            ],
                          ),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                decoration: BoxDecoration(
                                  color: theme.colorScheme.primaryContainer,
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  'Invoice No: ${sale.invoiceNumber ?? sale.saleNumber}',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14,
                                    color: theme.colorScheme.onPrimaryContainer,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text('Sale Ref: ${sale.saleNumber}', style: theme.textTheme.bodySmall),
                              Text('Date: $saleDateStr', style: theme.textTheme.bodySmall),
                              Text('Status: ${sale.status}', style: theme.textTheme.bodySmall?.copyWith(fontWeight: FontWeight.bold)),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      const Divider(),
                      const SizedBox(height: 16),

                      // Party Details
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(AppSizes.p16),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.surfaceContainerHighest.withAlpha(100),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: theme.dividerColor.withAlpha(50)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                const Icon(Icons.business_rounded, size: 18, color: Colors.blue),
                                const SizedBox(width: 8),
                                Text(
                                  'PARTY / CUSTOMER MASTER DETAILS',
                                  style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            ResponsiveFormRow(
                              children: [
                                _buildDetailItem(theme, 'Party Name', sale.customerName, isBold: true),
                                _buildDetailItem(theme, 'Contact Number', sale.customerPhone),
                              ],
                            ),
                            if (sale.partyType.isNotEmpty || sale.vendorCode.isNotEmpty) ...[
                              const SizedBox(height: 8),
                              ResponsiveFormRow(
                                children: [
                                  if (sale.partyType.isNotEmpty) _buildDetailItem(theme, 'Party Type', sale.partyType),
                                  if (sale.vendorCode.isNotEmpty) _buildDetailItem(theme, 'Vendor Code', sale.vendorCode),
                                ],
                              ),
                            ],
                            if (sale.gstin.isNotEmpty || sale.state.isNotEmpty) ...[
                              const SizedBox(height: 8),
                              ResponsiveFormRow(
                                children: [
                                  if (sale.gstin.isNotEmpty) _buildDetailItem(theme, 'GSTIN', sale.gstin, isBold: true),
                                  if (sale.state.isNotEmpty) _buildDetailItem(theme, 'State', '${sale.state} (${sale.stateCode})'),
                                ],
                              ),
                            ],
                            if (sale.contactPersonName.isNotEmpty || sale.email.isNotEmpty) ...[
                              const SizedBox(height: 8),
                              ResponsiveFormRow(
                                children: [
                                  if (sale.contactPersonName.isNotEmpty) _buildDetailItem(theme, 'Contact Person', sale.contactPersonName),
                                  if (sale.email.isNotEmpty) _buildDetailItem(theme, 'Email', sale.email),
                                ],
                              ),
                            ],
                            if (sale.address.isNotEmpty) ...[
                              const SizedBox(height: 8),
                              _buildDetailItem(theme, 'Address', sale.address),
                            ],
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),

                      // Item Details Table
                      Text(
                        'SALE ITEM SPECIFICATIONS',
                        style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 10),
                      Table(
                        border: TableBorder.all(color: theme.dividerColor.withAlpha(100), width: 1),
                        columnWidths: const {
                          0: FlexColumnWidth(1),
                          1: FlexColumnWidth(2),
                          2: FlexColumnWidth(1),
                          3: FlexColumnWidth(1),
                          4: FlexColumnWidth(1.2),
                          5: FlexColumnWidth(1.2),
                        },
                        children: [
                          TableRow(
                            decoration: BoxDecoration(color: theme.colorScheme.surfaceContainerHighest),
                            children: const [
                              Padding(padding: EdgeInsets.all(8), child: Text('Item #', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
                              Padding(padding: EdgeInsets.all(8), child: Text('Item Name', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
                              Padding(padding: EdgeInsets.all(8), child: Text('HSN Code', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
                              Padding(padding: EdgeInsets.all(8), child: Text('Quantity', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
                              Padding(padding: EdgeInsets.all(8), child: Text('Price / Unit', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
                              Padding(padding: EdgeInsets.all(8), child: Text('Total', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
                            ],
                          ),
                          TableRow(
                            children: [
                              Padding(padding: const EdgeInsets.all(8), child: Text(sale.itemNumber.isNotEmpty ? sale.itemNumber : '-')),
                              Padding(padding: const EdgeInsets.all(8), child: Text(sale.itemName, style: const TextStyle(fontWeight: FontWeight.bold))),
                              Padding(padding: const EdgeInsets.all(8), child: Text(sale.hsnCode.isNotEmpty ? sale.hsnCode : '-')),
                              Padding(padding: const EdgeInsets.all(8), child: Text('${sale.quantity} ${sale.unit}')),
                              Padding(padding: const EdgeInsets.all(8), child: Text('₹${sale.pricePerUnit.toStringAsFixed(2)}')),
                              Padding(padding: const EdgeInsets.all(8), child: Text('₹${sale.totalAmount.toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.green))),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),

                      // Grand Total Card
                      Align(
                        alignment: Alignment.centerRight,
                        child: Container(
                          width: 260,
                          padding: const EdgeInsets.all(AppSizes.p16),
                          decoration: BoxDecoration(
                            color: theme.colorScheme.primaryContainer.withAlpha(80),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: theme.colorScheme.primary.withAlpha(100)),
                          ),
                          child: Column(
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  const Text('Subtotal:'),
                                  Text('₹${sale.totalAmount.toStringAsFixed(2)}'),
                                ],
                              ),
                              const Divider(),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text('Grand Total:', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                                  Text(
                                    '₹${sale.totalAmount.toStringAsFixed(2)}',
                                    style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold, color: theme.colorScheme.primary),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),

                      if (sale.remarks.isNotEmpty) ...[
                        Text('Remarks / Internal Notes:', style: theme.textTheme.labelMedium?.copyWith(fontWeight: FontWeight.bold)),
                        const SizedBox(height: 4),
                        Text(sale.remarks, style: theme.textTheme.bodyMedium),
                        const SizedBox(height: 24),
                      ],

                      // Action Buttons
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          OutlinedButton.icon(
                            onPressed: () => context.pop(),
                            icon: const Icon(Icons.arrow_back),
                            label: const Text('Back to List'),
                          ),
                          const SizedBox(width: 12),
                          ElevatedButton.icon(
                            onPressed: () => generateAndDownloadPdf(context, sale, companyName),
                            icon: const Icon(Icons.print_rounded),
                            label: const Text('Download / Print A4 Document'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
        loading: () => const ResponsiveScaffold(body: Center(child: CircularProgressIndicator())),
        error: (err, stack) => ResponsiveScaffold(body: Center(child: Text('Error loading sale details: $err'))),
      ),
    );
  }

  Widget _buildDetailItem(ThemeData theme, String label, String value, {bool isBold = false}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: theme.textTheme.bodySmall?.copyWith(color: theme.hintColor)),
        const SizedBox(height: 2),
        Text(
          value.isNotEmpty ? value : '-',
          style: theme.textTheme.bodyMedium?.copyWith(
            fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ],
    );
  }
}
