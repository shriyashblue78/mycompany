import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_sizes.dart';
import '../../../../core/utils/file_saver.dart';
import '../../../../core/widgets/custom_card.dart';
import '../../../../core/widgets/erp_drawer.dart';
import '../../../../core/widgets/responsive_layout.dart';
import '../../../../core/widgets/responsive_widgets.dart';

import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../sales/presentation/providers/sales_provider.dart';
import '../../../sales/domain/models/sale_model.dart';
import '../../../purchase/presentation/providers/purchase_provider.dart';
import '../../../purchase/domain/models/purchase_model.dart';
import '../../../party/presentation/providers/party_provider.dart';
import '../../../party/domain/models/party_model.dart';

class TallyExportScreen extends ConsumerStatefulWidget {
  const TallyExportScreen({super.key});

  @override
  ConsumerState<TallyExportScreen> createState() => _TallyExportScreenState();
}

class _TallyExportScreenState extends ConsumerState<TallyExportScreen> {
  String _selectedRange = 'This Month'; // 'Today', 'Last 7 Days', 'This Month', 'All Time'
  bool _isExporting = false;

  DateTimeRange _getDateRange() {
    final now = DateTime.now();
    switch (_selectedRange) {
      case 'Today':
        final start = DateTime(now.year, now.month, now.day);
        final end = DateTime(now.year, now.month, now.day, 23, 59, 59);
        return DateTimeRange(start: start, end: end);
      case 'Last 7 Days':
        final start = now.subtract(const Duration(days: 7));
        return DateTimeRange(start: DateTime(start.year, start.month, start.day), end: now);
      case 'This Month':
        final start = DateTime(now.year, now.month, 1);
        return DateTimeRange(start: start, end: now);
      case 'All Time':
      default:
        return DateTimeRange(start: DateTime(2020, 1, 1), end: DateTime(2099, 12, 31));
    }
  }

  bool _isWithinRange(DateTime date, DateTimeRange range) {
    return (date.isAfter(range.start) || date.isAtSameMomentAs(range.start)) &&
        (date.isBefore(range.end) || date.isAtSameMomentAs(range.end));
  }

  // --- XML Generator for Sales Vouchers ---
  String _generateSalesXml(List<SaleModel> sales, String companyName) {
    final buffer = StringBuffer();
    buffer.writeln('<ENVELOPE>');
    buffer.writeln('  <HEADER>');
    buffer.writeln('    <TALLYREQUEST>Import Data</TALLYREQUEST>');
    buffer.writeln('  </HEADER>');
    buffer.writeln('  <BODY>');
    buffer.writeln('    <IMPORTDATA>');
    buffer.writeln('      <REQUESTDESC>');
    buffer.writeln('        <REPORTNAME>Vouchers</REPORTNAME>');
    buffer.writeln('        <STATICVARIABLES>');
    buffer.writeln('          <SVCURRENTCOMPANY>${_escapeXml(companyName)}</SVCURRENTCOMPANY>');
    buffer.writeln('        </STATICVARIABLES>');
    buffer.writeln('      </REQUESTDESC>');
    buffer.writeln('      <REQUESTDATA>');

    for (final sale in sales) {
      final dateStr = DateFormat('yyyyMMdd').format(sale.saleDate);
      final voucherNo = sale.invoiceNumber?.isNotEmpty == true ? sale.invoiceNumber! : sale.saleNumber;
      final partyName = _escapeXml(sale.customerName.isNotEmpty ? sale.customerName : 'Cash');
      final amount = sale.totalAmount.toStringAsFixed(2);
      final subtotal = (sale.subtotal ?? (sale.totalAmount * 0.847)).toStringAsFixed(2);

      buffer.writeln('        <TALLYMESSAGE xmlns:UDF="TallyUDF">');
      buffer.writeln('          <VOUCHER VCHTYPE="Sales" ACTION="Create" OBJVIEW="Invoice Voucher View">');
      buffer.writeln('            <DATE>$dateStr</DATE>');
      buffer.writeln('            <VOUCHERTYPENAME>Sales</VOUCHERTYPENAME>');
      buffer.writeln('            <VOUCHERNUMBER>$voucherNo</VOUCHERNUMBER>');
      buffer.writeln('            <PARTYLEDGERNAME>$partyName</PARTYLEDGERNAME>');
      buffer.writeln('            <PARTYGSTIN>${_escapeXml(sale.gstin)}</PARTYGSTIN>');
      buffer.writeln('            <STATENAME>${_escapeXml(sale.state)}</STATENAME>');
      buffer.writeln('            <NARRATION>ERP Sale Ref: ${sale.saleNumber} ${sale.remarks.isNotEmpty ? '- ' + _escapeXml(sale.remarks) : ''}</NARRATION>');
      
      // Party Ledger (Debit)
      buffer.writeln('            <ALLLEDGERENTRIES.LIST>');
      buffer.writeln('              <LEDGERNAME>$partyName</LEDGERNAME>');
      buffer.writeln('              <ISDEEMEDPOSITIVE>Yes</ISDEEMEDPOSITIVE>');
      buffer.writeln('              <AMOUNT>-$amount</AMOUNT>');
      buffer.writeln('            </ALLLEDGERENTRIES.LIST>');

      // Sales Account (Credit)
      buffer.writeln('            <ALLLEDGERENTRIES.LIST>');
      buffer.writeln('              <LEDGERNAME>Sales Account</LEDGERNAME>');
      buffer.writeln('              <ISDEEMEDPOSITIVE>No</ISDEEMEDPOSITIVE>');
      buffer.writeln('              <AMOUNT>$subtotal</AMOUNT>');
      buffer.writeln('            </ALLLEDGERENTRIES.LIST>');

      // Tax Ledgers if applicable
      if ((sale.cgstAmount ?? 0) > 0) {
        buffer.writeln('            <ALLLEDGERENTRIES.LIST>');
        buffer.writeln('              <LEDGERNAME>Output CGST</LEDGERNAME>');
        buffer.writeln('              <ISDEEMEDPOSITIVE>No</ISDEEMEDPOSITIVE>');
        buffer.writeln('              <AMOUNT>${sale.cgstAmount!.toStringAsFixed(2)}</AMOUNT>');
        buffer.writeln('            </ALLLEDGERENTRIES.LIST>');
      }
      if ((sale.sgstAmount ?? 0) > 0) {
        buffer.writeln('            <ALLLEDGERENTRIES.LIST>');
        buffer.writeln('              <LEDGERNAME>Output SGST</LEDGERNAME>');
        buffer.writeln('              <ISDEEMEDPOSITIVE>No</ISDEEMEDPOSITIVE>');
        buffer.writeln('              <AMOUNT>${sale.sgstAmount!.toStringAsFixed(2)}</AMOUNT>');
        buffer.writeln('            </ALLLEDGERENTRIES.LIST>');
      }
      if ((sale.igstAmount ?? 0) > 0) {
        buffer.writeln('            <ALLLEDGERENTRIES.LIST>');
        buffer.writeln('              <LEDGERNAME>Output IGST</LEDGERNAME>');
        buffer.writeln('              <ISDEEMEDPOSITIVE>No</ISDEEMEDPOSITIVE>');
        buffer.writeln('              <AMOUNT>${sale.igstAmount!.toStringAsFixed(2)}</AMOUNT>');
        buffer.writeln('            </ALLLEDGERENTRIES.LIST>');
      }

      buffer.writeln('          </VOUCHER>');
      buffer.writeln('        </TALLYMESSAGE>');
    }

    buffer.writeln('      </REQUESTDATA>');
    buffer.writeln('    </IMPORTDATA>');
    buffer.writeln('  </BODY>');
    buffer.writeln('</ENVELOPE>');
    return buffer.toString();
  }

  // --- XML Generator for Purchase Vouchers ---
  String _generatePurchasesXml(List<PurchaseModel> purchases, String companyName) {
    final buffer = StringBuffer();
    buffer.writeln('<ENVELOPE>');
    buffer.writeln('  <HEADER>');
    buffer.writeln('    <TALLYREQUEST>Import Data</TALLYREQUEST>');
    buffer.writeln('  </HEADER>');
    buffer.writeln('  <BODY>');
    buffer.writeln('    <IMPORTDATA>');
    buffer.writeln('      <REQUESTDESC>');
    buffer.writeln('        <REPORTNAME>Vouchers</REPORTNAME>');
    buffer.writeln('        <STATICVARIABLES>');
    buffer.writeln('          <SVCURRENTCOMPANY>${_escapeXml(companyName)}</SVCURRENTCOMPANY>');
    buffer.writeln('        </STATICVARIABLES>');
    buffer.writeln('      </REQUESTDESC>');
    buffer.writeln('      <REQUESTDATA>');

    for (final pur in purchases) {
      final dateStr = DateFormat('yyyyMMdd').format(pur.purchaseDate);
      final voucherNo = pur.invoiceNumber?.isNotEmpty == true ? pur.invoiceNumber! : pur.purchaseNumber;
      final supplierName = _escapeXml(pur.supplierName.isNotEmpty ? pur.supplierName : 'Cash Supplier');
      final amount = pur.totalAmount.toStringAsFixed(2);

      buffer.writeln('        <TALLYMESSAGE xmlns:UDF="TallyUDF">');
      buffer.writeln('          <VOUCHER VCHTYPE="Purchase" ACTION="Create" OBJVIEW="Invoice Voucher View">');
      buffer.writeln('            <DATE>$dateStr</DATE>');
      buffer.writeln('            <VOUCHERTYPENAME>Purchase</VOUCHERTYPENAME>');
      buffer.writeln('            <VOUCHERNUMBER>$voucherNo</VOUCHERNUMBER>');
      buffer.writeln('            <PARTYLEDGERNAME>$supplierName</PARTYLEDGERNAME>');
      buffer.writeln('            <NARRATION>Item: ${_escapeXml(pur.itemName)} Qty: ${pur.quantity} ${pur.unit}</NARRATION>');
      
      // Purchase Account (Debit)
      buffer.writeln('            <ALLLEDGERENTRIES.LIST>');
      buffer.writeln('              <LEDGERNAME>Purchase Account</LEDGERNAME>');
      buffer.writeln('              <ISDEEMEDPOSITIVE>Yes</ISDEEMEDPOSITIVE>');
      buffer.writeln('              <AMOUNT>-$amount</AMOUNT>');
      buffer.writeln('            </ALLLEDGERENTRIES.LIST>');

      // Supplier Ledger (Credit)
      buffer.writeln('            <ALLLEDGERENTRIES.LIST>');
      buffer.writeln('              <LEDGERNAME>$supplierName</LEDGERNAME>');
      buffer.writeln('              <ISDEEMEDPOSITIVE>No</ISDEEMEDPOSITIVE>');
      buffer.writeln('              <AMOUNT>$amount</AMOUNT>');
      buffer.writeln('            </ALLLEDGERENTRIES.LIST>');

      buffer.writeln('          </VOUCHER>');
      buffer.writeln('        </TALLYMESSAGE>');
    }

    buffer.writeln('      </REQUESTDATA>');
    buffer.writeln('    </IMPORTDATA>');
    buffer.writeln('  </BODY>');
    buffer.writeln('</ENVELOPE>');
    return buffer.toString();
  }

  // --- XML Generator for Party Masters / Ledgers ---
  String _generatePartiesXml(List<PartyModel> parties, String companyName) {
    final buffer = StringBuffer();
    buffer.writeln('<ENVELOPE>');
    buffer.writeln('  <HEADER>');
    buffer.writeln('    <TALLYREQUEST>Import Data</TALLYREQUEST>');
    buffer.writeln('  </HEADER>');
    buffer.writeln('  <BODY>');
    buffer.writeln('    <IMPORTDATA>');
    buffer.writeln('      <REQUESTDESC>');
    buffer.writeln('        <REPORTNAME>All Masters</REPORTNAME>');
    buffer.writeln('        <STATICVARIABLES>');
    buffer.writeln('          <SVCURRENTCOMPANY>${_escapeXml(companyName)}</SVCURRENTCOMPANY>');
    buffer.writeln('        </STATICVARIABLES>');
    buffer.writeln('      </REQUESTDESC>');
    buffer.writeln('      <REQUESTDATA>');

    for (final party in parties) {
      final name = _escapeXml(party.partyName);
      final isCustomer = party.partyType.toLowerCase().contains('customer');
      final parentGroup = isCustomer ? 'Sundry Debtors' : 'Sundry Creditors';

      buffer.writeln('        <TALLYMESSAGE xmlns:UDF="TallyUDF">');
      buffer.writeln('          <LEDGER NAME="$name" ACTION="Create">');
      buffer.writeln('            <NAME>$name</NAME>');
      buffer.writeln('            <PARENT>$parentGroup</PARENT>');
      buffer.writeln('            <MAILINGNAME>$name</MAILINGNAME>');
      buffer.writeln('            <ADDRESS.LIST>');
      buffer.writeln('              <ADDRESS>${_escapeXml(party.address)}</ADDRESS>');
      buffer.writeln('            </ADDRESS.LIST>');
      buffer.writeln('            <LEDSTATENAME>${_escapeXml(party.state)}</LEDSTATENAME>');
      buffer.writeln('            <PARTYGSTIN>${_escapeXml(party.gstin)}</PARTYGSTIN>');
      buffer.writeln('            <LEDGERPHONE>${_escapeXml(party.contactNumber)}</LEDGERPHONE>');
      buffer.writeln('          </LEDGER>');
      buffer.writeln('        </TALLYMESSAGE>');
    }

    buffer.writeln('      </REQUESTDATA>');
    buffer.writeln('    </IMPORTDATA>');
    buffer.writeln('  </BODY>');
    buffer.writeln('</ENVELOPE>');
    return buffer.toString();
  }

  // --- CSV Export for Sales & Purchase ---
  String _generateCombinedCsv(List<SaleModel> sales, List<PurchaseModel> purchases) {
    final buffer = StringBuffer();
    buffer.writeln('Date,Voucher Type,Voucher Number,Party Name,GSTIN,State,Item Details,Subtotal,Tax Amount,Total Amount,Status');

    for (final s in sales) {
      final dateStr = DateFormat('yyyy-MM-dd').format(s.saleDate);
      final vNo = s.invoiceNumber?.isNotEmpty == true ? s.invoiceNumber! : s.saleNumber;
      final party = '"${s.customerName.replaceAll('"', '""')}"';
      final itemDesc = '"${s.itemName.replaceAll('"', '""')} (${s.quantity} ${s.unit})"';
      final tax = ((s.cgstAmount ?? 0) + (s.sgstAmount ?? 0) + (s.igstAmount ?? 0)).toStringAsFixed(2);
      final sub = (s.subtotal ?? (s.totalAmount - double.parse(tax))).toStringAsFixed(2);
      buffer.writeln('$dateStr,Sales,$vNo,$party,${s.gstin},${s.state},$itemDesc,$sub,$tax,${s.totalAmount.toStringAsFixed(2)},${s.status}');
    }

    for (final p in purchases) {
      final dateStr = DateFormat('yyyy-MM-dd').format(p.purchaseDate);
      final vNo = p.invoiceNumber?.isNotEmpty == true ? p.invoiceNumber! : p.purchaseNumber;
      final party = '"${p.supplierName.replaceAll('"', '""')}"';
      final itemDesc = '"${p.itemName.replaceAll('"', '""')} (${p.quantity} ${p.unit})"';
      buffer.writeln('$dateStr,Purchase,$vNo,$party,,,${itemDesc},${p.totalAmount.toStringAsFixed(2)},0.00,${p.totalAmount.toStringAsFixed(2)},${p.status}');
    }

    return buffer.toString();
  }

  String _escapeXml(String text) {
    return text
        .replaceAll('&', '&amp;')
        .replaceAll('<', '&lt;')
        .replaceAll('>', '&gt;')
        .replaceAll('"', '&quot;')
        .replaceAll("'", '&apos;');
  }

  Future<void> _exportFile({
    required String content,
    required String filename,
    required String mimeType,
  }) async {
    setState(() => _isExporting = true);
    try {
      final bytes = utf8.encode(content);
      saveFile(bytes, filename, mimeType);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle_rounded, color: Colors.white, size: 20),
                const SizedBox(width: 8),
                Expanded(child: Text('Downloaded: $filename')),
              ],
            ),
            backgroundColor: AppColors.success,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to export: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isExporting = false);
    }
  }

  void _showXmlPreview(BuildContext context, String title, String xmlContent) {
    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: Row(
            children: [
              const Icon(Icons.code_rounded, color: Colors.orange),
              const SizedBox(width: 8),
              Expanded(child: Text('$title Preview')),
            ],
          ),
          content: SizedBox(
            width: 600,
            height: 400,
            child: SingleChildScrollView(
              child: SelectableText(
                xmlContent,
                style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
              ),
            ),
          ),
          actions: [
            TextButton.icon(
              icon: const Icon(Icons.copy_rounded, size: 16),
              label: const Text('Copy XML'),
              onPressed: () {
                Clipboard.setData(ClipboardData(text: xmlContent));
                Navigator.of(ctx).pop();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Tally XML copied to clipboard!'),
                    backgroundColor: AppColors.success,
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              },
            ),
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Close'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final isMobile = ResponsiveLayout.isMobile(context);

    final authState = ref.watch(authProvider);
    final companyName = authState.selectedCompany ?? 'Apex Industries';

    final salesAsync = ref.watch(companySalesStreamProvider);
    final purchasesAsync = ref.watch(companyPurchasesStreamProvider);
    final partiesAsync = ref.watch(companyPartiesStreamProvider);

    return ResponsiveScaffold(
      appBar: AppBar(
        title: const Text('Tally Integration & Export'),
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.help_outline_rounded),
            tooltip: 'Tally Import Guide',
            onPressed: () => _showImportGuideDialog(context),
          ),
        ],
      ),
      drawer: const ERPDrawer(),
      body: salesAsync.when(
        data: (allSales) {
          return purchasesAsync.when(
            data: (allPurchases) {
              return partiesAsync.when(
                data: (allParties) {
                  final range = _getDateRange();
                  final filteredSales = allSales.where((s) => _isWithinRange(s.saleDate, range)).toList();
                  final filteredPurchases = allPurchases.where((p) => _isWithinRange(p.purchaseDate, range)).toList();

                  final totalSalesVal = filteredSales.fold<double>(0.0, (acc, s) => acc + s.totalAmount);
                  final totalPurchasesVal = filteredPurchases.fold<double>(0.0, (acc, p) => acc + p.totalAmount);

                  final dateSuffix = DateFormat('yyyyMMdd').format(DateTime.now());

                  return SingleChildScrollView(
                    padding: const EdgeInsets.all(AppSizes.p24),
                    child: Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 1100),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Header Banner
                            _buildHeroBanner(theme, isDark, companyName),
                            const SizedBox(height: AppSizes.p20),

                            // Filter Bar
                            _buildFilterBar(theme, isDark),
                            const SizedBox(height: AppSizes.p20),

                            // Statistics Cards
                            _buildStatsGrid(
                              context,
                              theme,
                              isDark,
                              salesCount: filteredSales.length,
                              salesTotal: totalSalesVal,
                              purchaseCount: filteredPurchases.length,
                              purchaseTotal: totalPurchasesVal,
                              partiesCount: allParties.length,
                            ),
                            const SizedBox(height: AppSizes.p24),

                            // Export Options Title
                            Text(
                              'Export Formats for Tally Prime / ERP 9',
                              style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: AppSizes.p12),

                            // Export Actions Grid
                            _buildExportCardsGrid(
                              context: context,
                              theme: theme,
                              isDark: isDark,
                              isMobile: isMobile,
                              onExportSalesXml: () {
                                final xml = _generateSalesXml(filteredSales, companyName);
                                _exportFile(
                                  content: xml,
                                  filename: 'Tally_Sales_$dateSuffix.xml',
                                  mimeType: 'application/xml',
                                );
                              },
                              onPreviewSalesXml: () {
                                final xml = _generateSalesXml(filteredSales, companyName);
                                _showXmlPreview(context, 'Sales Vouchers XML', xml);
                              },
                              onExportPurchasesXml: () {
                                final xml = _generatePurchasesXml(filteredPurchases, companyName);
                                _exportFile(
                                  content: xml,
                                  filename: 'Tally_Purchases_$dateSuffix.xml',
                                  mimeType: 'application/xml',
                                );
                              },
                              onPreviewPurchasesXml: () {
                                final xml = _generatePurchasesXml(filteredPurchases, companyName);
                                _showXmlPreview(context, 'Purchase Vouchers XML', xml);
                              },
                              onExportPartiesXml: () {
                                final xml = _generatePartiesXml(allParties, companyName);
                                _exportFile(
                                  content: xml,
                                  filename: 'Tally_Ledgers_$dateSuffix.xml',
                                  mimeType: 'application/xml',
                                );
                              },
                              onPreviewPartiesXml: () {
                                final xml = _generatePartiesXml(allParties, companyName);
                                _showXmlPreview(context, 'Party Masters XML', xml);
                              },
                              onExportCsv: () {
                                final csv = _generateCombinedCsv(filteredSales, filteredPurchases);
                                _exportFile(
                                  content: csv,
                                  filename: 'Tally_DayBook_$dateSuffix.csv',
                                  mimeType: 'text/csv',
                                );
                              },
                            ),

                            const SizedBox(height: AppSizes.p24),

                            // Step-by-Step Instructions Card
                            _buildInstructionCard(theme, isDark),
                          ],
                        ),
                      ),
                    ),
                  );
                },
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e, _) => Center(child: Text('Error loading parties: $e')),
              );
            },
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Center(child: Text('Error loading purchases: $e')),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error loading sales: $e')),
      ),
    );
  }

  Widget _buildHeroBanner(ThemeData theme, bool isDark, String companyName) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSizes.p20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isDark
              ? [const Color(0xFF1E2638), const Color(0xFF161C28)]
              : [const Color(0xFFFFF3E0), const Color(0xFFFFE0B2)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.orange.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.orange.withOpacity(0.2),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.receipt_long_rounded, color: Colors.orange, size: 32),
          ),
          const SizedBox(width: AppSizes.p16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Tally Prime & ERP 9 Sync Center',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Seamlessly export Sales, Purchases, GST taxes, and Customer/Supplier Ledgers from $companyName into standard Tally XML and Excel format.',
                  style: TextStyle(
                    fontSize: 13,
                    color: isDark ? Colors.white70 : Colors.black54,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterBar(ThemeData theme, bool isDark) {
    final ranges = ['Today', 'Last 7 Days', 'This Month', 'All Time'];
    return Row(
      children: [
        const Text('Filter Range:', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
        const SizedBox(width: 12),
        Wrap(
          spacing: 8,
          children: ranges.map((r) {
            final isSelected = _selectedRange == r;
            return ChoiceChip(
              label: Text(r, style: TextStyle(fontSize: 12, fontWeight: isSelected ? FontWeight.bold : FontWeight.normal)),
              selected: isSelected,
              selectedColor: Colors.orange.withOpacity(0.2),
              onSelected: (val) {
                if (val) setState(() => _selectedRange = r);
              },
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildStatsGrid(
    BuildContext context,
    ThemeData theme,
    bool isDark, {
    required int salesCount,
    required double salesTotal,
    required int purchaseCount,
    required double purchaseTotal,
    required int partiesCount,
  }) {
    final currencyFormatter = NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 2);

    return LayoutBuilder(
      builder: (context, constraints) {
        final isSmall = constraints.maxWidth < 600;
        return GridView.count(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: isSmall ? 1 : 3,
          crossAxisSpacing: AppSizes.p12,
          mainAxisSpacing: AppSizes.p12,
          childAspectRatio: isSmall ? 3.0 : 2.2,
          children: [
            _buildStatCard(
              title: 'Sales Vouchers',
              value: '$salesCount Invoices',
              subValue: currencyFormatter.format(salesTotal),
              icon: Icons.point_of_sale_rounded,
              color: Colors.amber,
              isDark: isDark,
            ),
            _buildStatCard(
              title: 'Purchase Vouchers',
              value: '$purchaseCount Bills',
              subValue: currencyFormatter.format(purchaseTotal),
              icon: Icons.shopping_cart_rounded,
              color: Colors.teal,
              isDark: isDark,
            ),
            _buildStatCard(
              title: 'Party Ledgers',
              value: '$partiesCount Parties',
              subValue: 'Customers & Suppliers',
              icon: Icons.people_alt_rounded,
              color: Colors.blue,
              isDark: isDark,
            ),
          ],
        );
      },
    );
  }

  Widget _buildStatCard({
    required String title,
    required String value,
    required String subValue,
    required IconData icon,
    required Color color,
    required bool isDark,
  }) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: color.withOpacity(0.25)),
      ),
      color: color.withOpacity(isDark ? 0.08 : 0.04),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(color: color.withOpacity(0.18), shape: BoxShape.circle),
              child: Icon(icon, color: color, size: 22),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(title, style: TextStyle(fontSize: 12, color: Colors.grey.shade500, fontWeight: FontWeight.w500)),
                  const SizedBox(height: 2),
                  Text(value, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  Text(subValue, style: TextStyle(fontSize: 11, color: color, fontWeight: FontWeight.w600)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildExportCardsGrid({
    required BuildContext context,
    required ThemeData theme,
    required bool isDark,
    required bool isMobile,
    required VoidCallback onExportSalesXml,
    required VoidCallback onPreviewSalesXml,
    required VoidCallback onExportPurchasesXml,
    required VoidCallback onPreviewPurchasesXml,
    required VoidCallback onExportPartiesXml,
    required VoidCallback onPreviewPartiesXml,
    required VoidCallback onExportCsv,
  }) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final crossAxisCount = constraints.maxWidth < 650 ? 1 : 2;
        return GridView.count(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: crossAxisCount,
          crossAxisSpacing: AppSizes.p12,
          mainAxisSpacing: AppSizes.p12,
          childAspectRatio: isMobile ? 2.0 : 2.4,
          children: [
            _buildActionCard(
              title: 'Sales Vouchers (Tally XML)',
              description: 'Generates Sales Invoices with GST breakdown (CGST, SGST, IGST) formatted for Tally Prime.',
              icon: Icons.receipt_long_rounded,
              color: Colors.amber,
              onDownload: onExportSalesXml,
              onPreview: onPreviewSalesXml,
              isDark: isDark,
            ),
            _buildActionCard(
              title: 'Purchase Vouchers (Tally XML)',
              description: 'Generates Purchase entries with supplier ledgers ready for Tally Day Book import.',
              icon: Icons.add_shopping_cart_rounded,
              color: Colors.teal,
              onDownload: onExportPurchasesXml,
              onPreview: onPreviewPurchasesXml,
              isDark: isDark,
            ),
            _buildActionCard(
              title: 'Party Masters / Ledgers (XML)',
              description: 'Export Customers & Suppliers with GSTIN, State code, and Sundry Debtors/Creditors groups.',
              icon: Icons.contact_page_rounded,
              color: Colors.blue,
              onDownload: onExportPartiesXml,
              onPreview: onPreviewPartiesXml,
              isDark: isDark,
            ),
            _buildActionCard(
              title: 'Excel / CSV Day Book Export',
              description: 'Standard columnar spreadsheet of all sales and purchases for reconciliation or third-party tools.',
              icon: Icons.table_chart_rounded,
              color: Colors.purple,
              onDownload: onExportCsv,
              isDark: isDark,
            ),
          ],
        );
      },
    );
  }

  Widget _buildActionCard({
    required String title,
    required String description,
    required IconData icon,
    required Color color,
    required VoidCallback onDownload,
    VoidCallback? onPreview,
    required bool isDark,
  }) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: themeBorderColor(isDark)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppSizes.p16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(color: color.withOpacity(0.12), borderRadius: BorderRadius.circular(10)),
                  child: Icon(icon, color: color, size: 22),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Expanded(
              child: Text(
                description,
                style: TextStyle(fontSize: 12, color: isDark ? Colors.white60 : Colors.black54),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                ElevatedButton.icon(
                  onPressed: _isExporting ? null : onDownload,
                  icon: const Icon(Icons.download_rounded, size: 16),
                  label: const Text('Export XML', style: TextStyle(fontSize: 12)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: color,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                ),
                if (onPreview != null) ...[
                  const SizedBox(width: 8),
                  OutlinedButton.icon(
                    onPressed: onPreview,
                    icon: const Icon(Icons.visibility_outlined, size: 16),
                    label: const Text('Preview', style: TextStyle(fontSize: 12)),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInstructionCard(ThemeData theme, bool isDark) {
    return Container(
      padding: const EdgeInsets.all(AppSizes.p20),
      decoration: BoxDecoration(
        color: isDark ? theme.colorScheme.surface : Colors.grey.shade50,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: themeBorderColor(isDark)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: const [
              Icon(Icons.info_outline_rounded, color: Colors.orange, size: 20),
              SizedBox(width: 8),
              Text(
                'How to Import XML into Tally Prime',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _buildStep('1', 'Open Tally Prime and select your Company.'),
          _buildStep('2', 'Click the "Import" menu at the top bar (or press shortcut Alt + O).'),
          _buildStep('3', 'Select "Transactions" (for Sales/Purchase) or "Masters" (for Parties).'),
          _buildStep('4', 'Select "File Format" as XML and choose the downloaded .xml file.'),
          _buildStep('5', 'Press Enter to import. Review the entries in your Tally Day Book (Alt + G -> Day Book).'),
        ],
      ),
    );
  }

  Widget _buildStep(String stepNumber, String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 20,
            height: 20,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: Colors.orange.withOpacity(0.15),
              shape: BoxShape.circle,
            ),
            child: Text(
              stepNumber,
              style: const TextStyle(color: Colors.orange, fontSize: 11, fontWeight: FontWeight.bold),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(fontSize: 13, height: 1.4),
            ),
          ),
        ],
      ),
    );
  }

  Color themeBorderColor(bool isDark) {
    return isDark ? Colors.white.withOpacity(0.1) : Colors.black.withOpacity(0.08);
  }

  void _showImportGuideDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Tally Prime Import Instructions'),
        content: const Text(
          '1. Export XML files from this screen.\n'
          '2. Open Tally Prime.\n'
          '3. First import Masters (Parties XML) so customer/supplier ledgers exist.\n'
          '4. Next, import Transactions (Sales or Purchase XML).\n'
          '5. If ledger names match your existing chart of accounts, Tally links them automatically.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('Got it')),
        ],
      ),
    );
  }
}
