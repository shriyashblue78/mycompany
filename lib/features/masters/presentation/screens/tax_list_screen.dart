import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_sizes.dart';
import '../../../../core/widgets/erp_drawer.dart';
import '../../../../core/widgets/polish_widgets.dart';
import '../../../../core/widgets/responsive_layout.dart';
import '../../../../core/widgets/responsive_widgets.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../domain/models/tax_model.dart';
import '../providers/tax_provider.dart';

class TaxListScreen extends ConsumerStatefulWidget {
  const TaxListScreen({super.key});

  @override
  ConsumerState<TaxListScreen> createState() => _TaxListScreenState();
}

class _TaxListScreenState extends ConsumerState<TaxListScreen> {
  @override
  Widget build(BuildContext context) {
    final taxesAsync = ref.watch(filteredTaxesProvider);
    final authState = ref.watch(authProvider);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final isMobile = ResponsiveLayout.isMobile(context);

    final role = authState.selectedRole ?? 'Employee';
    final canManage = role == 'Owner' || role == 'Accountant';
    final companyId = authState.user?.companyId ?? '';

    final appBar = AppBar(
      title: const Text(
        'Tax Master',
        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
      ),
      elevation: 0,
    );

    return taxesAsync.when(
      data: (taxes) {
        final body = RefreshIndicator(
          onRefresh: () async {
            ref.invalidate(companyTaxesStreamProvider);
          },
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: EdgeInsets.symmetric(
              horizontal: isMobile ? AppSizes.p12 : AppSizes.p24,
              vertical: isMobile ? AppSizes.p12 : AppSizes.p16,
            ),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1300),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _buildHeaderBar(
                      context: context,
                      companyId: companyId,
                      canManage: canManage,
                      theme: theme,
                      isDark: isDark,
                      isMobile: isMobile,
                      count: taxes.length,
                    ),
                    const SizedBox(height: AppSizes.p12),
                    if (taxes.isEmpty)
                      EmptyStateWidget(
                        icon: Icons.account_balance_outlined,
                        title: 'No Tax Slabs Configured',
                        description: ref.watch(taxSearchQueryProvider).isNotEmpty
                            ? 'No tax records match your search query.'
                            : 'Configure GST slabs, CGST, SGST, IGST, and cess percentage rules.',
                      )
                    else
                      _buildTaxDataTable(
                        context: context,
                        taxes: taxes,
                        canManage: canManage,
                        companyId: companyId,
                        theme: theme,
                        isDark: isDark,
                        isMobile: isMobile,
                      ),
                  ],
                ),
              ),
            ),
          ),
        );

        return ResponsiveScaffold(
          appBar: appBar,
          drawer: const ERPDrawer(),
          body: body,
        );
      },
      loading: () => ResponsiveScaffold(
        appBar: appBar,
        drawer: const ERPDrawer(),
        body: const Center(child: CardListSkeleton()),
      ),
      error: (err, _) => ResponsiveScaffold(
        appBar: appBar,
        drawer: const ERPDrawer(),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(AppSizes.p24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.error_outline_rounded, color: AppColors.error, size: 48),
                const SizedBox(height: 12),
                Text('Error loading taxes: $err'),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: () => ref.invalidate(companyTaxesStreamProvider),
                  child: const Text('Retry'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeaderBar({
    required BuildContext context,
    required String companyId,
    required bool canManage,
    required ThemeData theme,
    required bool isDark,
    required bool isMobile,
    required int count,
  }) {
    final borderColor = isDark ? AppColors.borderDark : AppColors.borderLight;
    final surfaceColor = isDark ? AppColors.surfaceDark : AppColors.surfaceLight;

    return Container(
      padding: EdgeInsets.symmetric(horizontal: isMobile ? 12 : 16, vertical: 10),
      decoration: BoxDecoration(
        color: surfaceColor,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: borderColor),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 4,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Wrap(
        alignment: WrapAlignment.spaceBetween,
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: 12,
        runSpacing: 10,
        children: [
          // Search input box
          ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: isMobile ? double.infinity : 400,
              minWidth: isMobile ? double.infinity : 280,
            ),
            child: SizedBox(
              height: 42,
              child: TextField(
                onChanged: (val) => ref.read(taxSearchQueryProvider.notifier).state = val,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: isDark ? Colors.white : const Color(0xFF111827),
                ),
                decoration: InputDecoration(
                  hintText: 'Search Tax Category, Short Name...',
                  hintStyle: TextStyle(
                    fontSize: 13.5,
                    color: isDark ? Colors.white54 : const Color(0xFF6B7280),
                  ),
                  prefixIcon: Icon(
                    Icons.search_rounded,
                    size: 20,
                    color: isDark ? Colors.white70 : const Color(0xFF4B5563),
                  ),
                  suffixIcon: ref.watch(taxSearchQueryProvider).isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear_rounded, size: 18),
                          splashRadius: 18,
                          onPressed: () => ref.read(taxSearchQueryProvider.notifier).state = '',
                        )
                      : null,
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  filled: true,
                  fillColor: isDark ? Colors.grey.shade900 : const Color(0xFFF9FAFB),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(6),
                    borderSide: BorderSide(color: borderColor),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(6),
                    borderSide: BorderSide(color: borderColor),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(6),
                    borderSide: BorderSide(
                      color: isDark ? AppColors.accentDark : AppColors.primaryLight,
                      width: 1.3,
                    ),
                  ),
                ),
              ),
            ),
          ),

          // Total count badge and New Tax action button
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                decoration: BoxDecoration(
                  color: isDark ? Colors.grey.shade800 : const Color(0xFFF3F4F6),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: borderColor),
                ),
                child: Text(
                  'Total: $count',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: isDark ? Colors.white : const Color(0xFF1F2937),
                  ),
                ),
              ),
              if (canManage) ...[
                const SizedBox(width: 10),
                SizedBox(
                  height: 40,
                  child: ElevatedButton.icon(
                    onPressed: () => context.push('/masters/taxes/add'),
                    icon: const Icon(Icons.add_rounded, size: 18),
                    label: const Text(
                      'New Tax',
                      style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: isDark ? AppColors.primaryDark : AppColors.primaryLight,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(6),
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTaxDataTable({
    required BuildContext context,
    required List<TaxModel> taxes,
    required bool canManage,
    required String companyId,
    required ThemeData theme,
    required bool isDark,
    required bool isMobile,
  }) {
    final borderColor = isDark ? AppColors.borderDark : const Color(0xFFE5E7EB);
    final headerBgColor = isDark ? const Color(0xFF161F2E) : const Color(0xFFF8FAFC);
    final cardBgColor = isDark ? AppColors.surfaceDark : Colors.white;

    return Container(
      decoration: BoxDecoration(
        color: cardBgColor,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: borderColor),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: LayoutBuilder(
        builder: (context, constraints) {
          const double minTableWidth = 980;
          final double tableWidth = constraints.maxWidth > minTableWidth ? constraints.maxWidth : minTableWidth;

          return SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: SizedBox(
              width: tableWidth,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Spreadsheet Column Headers
                  Container(
                    height: 46,
                    decoration: BoxDecoration(
                      color: headerBgColor,
                      border: Border(
                        bottom: BorderSide(color: borderColor, width: 1.5),
                      ),
                    ),
                    child: Row(
                      children: [
                        _buildHeaderCell('Sr.', width: 65, alignment: Alignment.center, isDark: isDark),
                        _buildHeaderCell('Tax Category / Name', flex: 4, minWidth: 200, isDark: isDark),
                        _buildHeaderCell('Short Name', flex: 2, minWidth: 110, isDark: isDark),
                        _buildHeaderCell('CGST %', width: 85, alignment: Alignment.centerRight, isDark: isDark),
                        _buildHeaderCell('SGST %', width: 85, alignment: Alignment.centerRight, isDark: isDark),
                        _buildHeaderCell('IGST %', width: 85, alignment: Alignment.centerRight, isDark: isDark),
                        _buildHeaderCell('Cess %', width: 80, alignment: Alignment.centerRight, isDark: isDark),
                        _buildHeaderCell('Remark on Invoice', flex: 3, minWidth: 150, isDark: isDark),
                        _buildHeaderCell('Actions', width: 135, alignment: Alignment.center, isDark: isDark),
                      ],
                    ),
                  ),
                  // Spreadsheet Rows
                  ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: taxes.length,
                    separatorBuilder: (_, __) => Divider(
                      height: 1,
                      thickness: 1,
                      color: borderColor,
                    ),
                    itemBuilder: (context, index) {
                      final tax = taxes[index];
                      return _buildTableRow(
                        context: context,
                        index: index,
                        tax: tax,
                        canManage: canManage,
                        companyId: companyId,
                        theme: theme,
                        isDark: isDark,
                      );
                    },
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildHeaderCell(
    String label, {
    double? width,
    int? flex,
    double? minWidth,
    Alignment alignment = Alignment.centerLeft,
    required bool isDark,
  }) {
    final cell = Container(
      alignment: alignment,
      padding: const EdgeInsets.symmetric(horizontal: 14),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w700,
          color: isDark ? const Color(0xFFD1D5DB) : const Color(0xFF1F2937),
          letterSpacing: 0.2,
        ),
      ),
    );

    if (width != null) {
      return SizedBox(width: width, child: cell);
    }
    return Expanded(
      flex: flex ?? 1,
      child: minWidth != null
          ? ConstrainedBox(
              constraints: BoxConstraints(minWidth: minWidth),
              child: cell,
            )
          : cell,
    );
  }

  Widget _buildTableRow({
    required BuildContext context,
    required int index,
    required TaxModel tax,
    required bool canManage,
    required String companyId,
    required ThemeData theme,
    required bool isDark,
  }) {
    final zebraColor = index.isOdd
        ? (isDark ? Colors.white.withOpacity(0.02) : const Color(0xFFF9FAFB))
        : Colors.transparent;

    return Material(
      color: zebraColor,
      child: InkWell(
        hoverColor: isDark ? Colors.white.withOpacity(0.04) : const Color(0xFFF1F5F9),
        onTap: () => _viewTaxDetails(context, tax),
        child: Container(
          constraints: const BoxConstraints(minHeight: 52),
          child: Row(
            children: [
              // Sr. No.
              SizedBox(
                width: 65,
                child: Center(
                  child: Text(
                    '${index + 1}',
                    style: TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w600,
                      color: isDark ? Colors.white70 : const Color(0xFF4B5563),
                    ),
                  ),
                ),
              ),

              // Tax Category / Name
              Expanded(
                flex: 4,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  child: Row(
                    children: [
                      Container(
                        width: 28,
                        height: 28,
                        decoration: BoxDecoration(
                          color: const Color(0xFFEC4899).withOpacity(isDark ? 0.22 : 0.12),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Icon(
                          Icons.percent_rounded,
                          size: 16,
                          color: Color(0xFFEC4899),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          tax.taxCategory,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: isDark ? Colors.white : const Color(0xFF111827),
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // Short Name
              Expanded(
                flex: 2,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: isDark ? Colors.grey.shade800 : const Color(0xFFF3F4F6),
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(
                          color: isDark ? Colors.grey.shade700 : const Color(0xFFD1D5DB),
                        ),
                      ),
                      child: Text(
                        tax.shortName,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: isDark ? const Color(0xFFE5E7EB) : const Color(0xFF1F2937),
                        ),
                      ),
                    ),
                  ),
                ),
              ),

              // CGST %
              SizedBox(
                width: 85,
                child: Padding(
                  padding: const EdgeInsets.only(right: 14),
                  child: Text(
                    '${tax.cgstRate.toStringAsFixed(1)}%',
                    textAlign: TextAlign.end,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: isDark ? Colors.white : const Color(0xFF1F2937),
                    ),
                  ),
                ),
              ),

              // SGST %
              SizedBox(
                width: 85,
                child: Padding(
                  padding: const EdgeInsets.only(right: 14),
                  child: Text(
                    '${tax.sgstRate.toStringAsFixed(1)}%',
                    textAlign: TextAlign.end,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: isDark ? Colors.white : const Color(0xFF1F2937),
                    ),
                  ),
                ),
              ),

              // IGST %
              SizedBox(
                width: 85,
                child: Padding(
                  padding: const EdgeInsets.only(right: 14),
                  child: Text(
                    '${tax.igstRate.toStringAsFixed(1)}%',
                    textAlign: TextAlign.end,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: isDark ? Colors.white : const Color(0xFF1F2937),
                    ),
                  ),
                ),
              ),

              // Cess %
              SizedBox(
                width: 80,
                child: Padding(
                  padding: const EdgeInsets.only(right: 14),
                  child: Text(
                    tax.cessRate > 0 ? '${tax.cessRate.toStringAsFixed(1)}%' : '—',
                    textAlign: TextAlign.end,
                    style: TextStyle(
                      fontSize: 13,
                      color: tax.cessRate > 0
                          ? (isDark ? Colors.white : const Color(0xFF1F2937))
                          : (isDark ? Colors.white38 : const Color(0xFF9CA3AF)),
                    ),
                  ),
                ),
              ),

              // Remark
              Expanded(
                flex: 3,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  child: Text(
                    tax.remarkOnInvoice.isNotEmpty ? tax.remarkOnInvoice : '—',
                    style: TextStyle(
                      fontSize: 13,
                      color: tax.remarkOnInvoice.isNotEmpty
                          ? (isDark ? Colors.white70 : const Color(0xFF4B5563))
                          : (isDark ? Colors.white38 : const Color(0xFF9CA3AF)),
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),

              // Actions (View, Edit, Delete)
              SizedBox(
                width: 135,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _buildSubtleActionButton(
                      icon: Icons.visibility_outlined,
                      tooltip: 'View Details',
                      color: const Color(0xFF2563EB),
                      hoverColor: const Color(0xFF2563EB).withOpacity(0.12),
                      onPressed: () => _viewTaxDetails(context, tax),
                    ),
                    if (canManage) ...[
                      const SizedBox(width: 4),
                      _buildSubtleActionButton(
                        icon: Icons.edit_outlined,
                        tooltip: 'Edit Tax',
                        color: const Color(0xFF059669),
                        hoverColor: const Color(0xFF059669).withOpacity(0.12),
                        onPressed: () => context.push('/masters/taxes/edit/${tax.taxId}'),
                      ),
                      const SizedBox(width: 4),
                      _buildSubtleActionButton(
                        icon: Icons.delete_outline_rounded,
                        tooltip: 'Delete Tax',
                        color: const Color(0xFFDC2626),
                        hoverColor: const Color(0xFFDC2626).withOpacity(0.12),
                        onPressed: () => _confirmDelete(context, tax, companyId),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSubtleActionButton({
    required IconData icon,
    required String tooltip,
    required Color color,
    required Color hoverColor,
    required VoidCallback onPressed,
  }) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          hoverColor: hoverColor,
          onTap: onPressed,
          child: Padding(
            padding: const EdgeInsets.all(7),
            child: Icon(icon, size: 18, color: color),
          ),
        ),
      ),
    );
  }

  void _viewTaxDetails(BuildContext context, TaxModel tax) {
    showDialog(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFFEC4899).withOpacity(0.15),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.account_balance_rounded, color: Color(0xFFEC4899), size: 22),
            ),
            const SizedBox(width: 12),
            const Text('Tax Master Details'),
          ],
        ),
        content: SizedBox(
          width: 520,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildDetailRow('Tax Category', tax.taxCategory, isBold: true),
                _buildDetailRow('Short Name', tax.shortName, isBold: true),
                _buildDetailRow('C-GST Rate', '${tax.cgstRate.toStringAsFixed(2)} %'),
                _buildDetailRow('S-GST Rate', '${tax.sgstRate.toStringAsFixed(2)} %'),
                _buildDetailRow('I-GST Rate', '${tax.igstRate.toStringAsFixed(2)} %'),
                _buildDetailRow('Cess Rate', '${tax.cessRate.toStringAsFixed(2)} %'),
                _buildDetailRow('Total Intra-state GST', '${tax.totalGstRate.toStringAsFixed(2)} %'),
                _buildDetailRow('Remark on Invoice', tax.remarkOnInvoice.isNotEmpty ? tax.remarkOnInvoice : '-'),
                const Divider(height: 20),
                const Text('Ledger & Accounting Maps', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                const SizedBox(height: 6),
                _buildDetailRow('Sales A/C', tax.salesAccount ?? '-'),
                _buildDetailRow('Sales A/C OMS', tax.salesAccountOms ?? '-'),
                _buildDetailRow('Mould Amort.', tax.mouldAmortization ?? '-'),
                _buildDetailRow('C-GST A/C', tax.cgstAccount ?? '-'),
                _buildDetailRow('S-GST A/C', tax.sgstAccount ?? '-'),
                _buildDetailRow('I-GST A/C', tax.igstAccount ?? '-'),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value, {bool isBold = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 170,
            child: Text(
              label,
              style: const TextStyle(fontSize: 12, color: Colors.grey, fontWeight: FontWeight.w500),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontSize: 13,
                fontWeight: isBold ? FontWeight.bold : FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmDelete(BuildContext context, TaxModel tax, String companyId) async {
    final repo = ref.read(taxRepositoryProvider);

    final isReferenced = await repo.isTaxReferenced(companyId, tax.taxId, tax.taxCategory);
    if (!mounted) return;

    if (isReferenced) {
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.warning_amber_rounded, color: AppColors.warning),
              SizedBox(width: 8),
              Text('Cannot Delete Tax Master'),
            ],
          ),
          content: Text(
            'The tax record "${tax.taxCategory}" is currently in use by active items or transactions. Reassign or archive the associated transactions before deleting.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('OK'),
            ),
          ],
        ),
      );
      return;
    }

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Tax Record'),
        content: Text('Are you sure you want to delete "${tax.taxCategory}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete', style: TextStyle(color: AppColors.error)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await repo.deleteTax(companyId, tax.taxId);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Tax record deleted successfully'),
              backgroundColor: AppColors.success,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error deleting tax: $e')),
          );
        }
      }
    }
  }
}
