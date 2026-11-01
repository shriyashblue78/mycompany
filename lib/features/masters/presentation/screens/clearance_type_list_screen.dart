import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_sizes.dart';
import '../../../../core/widgets/erp_drawer.dart';
import '../../../../core/widgets/polish_widgets.dart';
import '../../../../core/widgets/responsive_layout.dart';
import '../../../../core/widgets/responsive_widgets.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../domain/models/clearance_type_model.dart';
import '../providers/clearance_type_provider.dart';

class ClearanceTypeListScreen extends ConsumerStatefulWidget {
  const ClearanceTypeListScreen({super.key});

  @override
  ConsumerState<ClearanceTypeListScreen> createState() => _ClearanceTypeListScreenState();
}

class _ClearanceTypeListScreenState extends ConsumerState<ClearanceTypeListScreen> {
  @override
  Widget build(BuildContext context) {
    final listAsync = ref.watch(filteredClearanceTypesProvider);
    final authState = ref.watch(authProvider);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final isMobile = ResponsiveLayout.isMobile(context);

    final role = authState.selectedRole ?? 'Employee';
    final canManage = role == 'Owner' || role == 'Accountant';
    final companyId = authState.user?.companyId ?? '';

    final appBar = AppBar(
      title: const Text(
        'Clearance Type Master',
        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
      ),
      elevation: 0,
    );

    return listAsync.when(
      data: (items) {
        final body = RefreshIndicator(
          onRefresh: () async {
            ref.invalidate(companyClearanceTypesStreamProvider);
          },
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: EdgeInsets.symmetric(
              horizontal: isMobile ? AppSizes.p12 : AppSizes.p24,
              vertical: isMobile ? AppSizes.p12 : AppSizes.p16,
            ),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1200),
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
                      count: items.length,
                    ),
                    const SizedBox(height: AppSizes.p12),
                    if (items.isEmpty)
                      EmptyStateWidget(
                        icon: Icons.verified_user_outlined,
                        title: 'No Clearance Types Found',
                        description: ref.watch(clearanceTypeSearchQueryProvider).isNotEmpty
                            ? 'No clearance types match your search. Try a different query.'
                            : 'Configure customs, domestic, and export clearance tax applicability.',
                      )
                    else
                      _buildClearanceDataTable(
                        context: context,
                        items: items,
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
                Text('Error loading Clearance Types: $err'),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: () => ref.invalidate(companyClearanceTypesStreamProvider),
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
          // Search box
          ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: isMobile ? double.infinity : 360,
              minWidth: isMobile ? double.infinity : 260,
            ),
            child: SizedBox(
              height: 40,
              child: TextField(
                onChanged: (val) => ref.read(clearanceTypeSearchQueryProvider.notifier).state = val,
                style: TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w500,
                  color: isDark ? Colors.white : const Color(0xFF111827),
                ),
                decoration: InputDecoration(
                  hintText: 'Search by Clearance Type...',
                  hintStyle: TextStyle(
                    fontSize: 13,
                    color: isDark ? Colors.white54 : const Color(0xFF6B7280),
                  ),
                  prefixIcon: Icon(
                    Icons.search_rounded,
                    size: 19,
                    color: isDark ? Colors.white70 : const Color(0xFF4B5563),
                  ),
                  suffixIcon: ref.watch(clearanceTypeSearchQueryProvider).isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear_rounded, size: 16),
                          splashRadius: 16,
                          onPressed: () => ref.read(clearanceTypeSearchQueryProvider.notifier).state = '',
                        )
                      : null,
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
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

          // Total Count badge & + New button
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
                    onPressed: () => _openClearanceDialog(context, companyId),
                    icon: const Icon(Icons.add_rounded, size: 18),
                    label: const Text(
                      'New Clearance Type',
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

  Widget _buildClearanceDataTable({
    required BuildContext context,
    required List<ClearanceTypeModel> items,
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
          // Columns: Sr. No., Clearance Type, CGST Flag, SGST Flag, IGST Flag, Cess Flag, D/E Flag, Actions
          const double minTableWidth = 860;
          final double tableWidth = constraints.maxWidth > minTableWidth
              ? constraints.maxWidth
              : minTableWidth;

          return SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: SizedBox(
              width: tableWidth,
              child: Column(
                children: [
                  // Table Header
                  Container(
                    height: 42,
                    decoration: BoxDecoration(
                      color: headerBgColor,
                      border: Border(bottom: BorderSide(color: borderColor, width: 1.5)),
                    ),
                    child: Row(
                      children: [
                        _buildHeaderCell('Sr. No.', width: 75, alignment: Alignment.center, isDark: isDark),
                        _buildHeaderCell('Clearance Type', flex: 4, minWidth: 200, isDark: isDark),
                        _buildHeaderCell('CGST Flag', width: 95, alignment: Alignment.center, isDark: isDark),
                        _buildHeaderCell('SGST Flag', width: 95, alignment: Alignment.center, isDark: isDark),
                        _buildHeaderCell('IGST Flag', width: 95, alignment: Alignment.center, isDark: isDark),
                        _buildHeaderCell('Cess Flag', width: 95, alignment: Alignment.center, isDark: isDark),
                        _buildHeaderCell('D/E Flag', width: 90, alignment: Alignment.center, isDark: isDark),
                        _buildHeaderCell('Actions', width: 115, alignment: Alignment.centerRight, isDark: isDark),
                      ],
                    ),
                  ),

                  // Table Rows
                  ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: items.length,
                    separatorBuilder: (_, __) => Divider(height: 1, thickness: 1, color: borderColor),
                    itemBuilder: (context, index) {
                      final item = items[index];

                      return Container(
                        height: 48,
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            // Sr. No.
                            SizedBox(
                              width: 75,
                              child: Center(
                                child: Text(
                                  '${index + 1}',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w600,
                                    fontSize: 13,
                                    color: isDark ? Colors.white70 : const Color(0xFF4B5563),
                                  ),
                                ),
                              ),
                            ),

                            // Clearance Type
                            Expanded(
                              flex: 4,
                              child: ConstrainedBox(
                                constraints: const BoxConstraints(minWidth: 200),
                                child: Row(
                                  children: [
                                    Container(
                                      width: 28,
                                      height: 28,
                                      decoration: BoxDecoration(
                                        color: const Color(0xFF0D9488).withOpacity(isDark ? 0.22 : 0.1),
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: const Icon(Icons.verified_user_rounded, color: Color(0xFF0D9488), size: 15),
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: Column(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            item.clearanceType,
                                            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13.5),
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                          if (item.remark != null && item.remark!.isNotEmpty)
                                            Text(
                                              item.remark!,
                                              style: TextStyle(
                                                fontSize: 11,
                                                color: isDark ? Colors.white54 : const Color(0xFF6B7280),
                                              ),
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),

                            // CGST Flag
                            SizedBox(
                              width: 95,
                              child: Center(child: _buildApplicableBadge(item.isCgstApplicable, isDark)),
                            ),

                            // SGST Flag
                            SizedBox(
                              width: 95,
                              child: Center(child: _buildApplicableBadge(item.isSgstApplicable, isDark)),
                            ),

                            // IGST Flag
                            SizedBox(
                              width: 95,
                              child: Center(child: _buildApplicableBadge(item.isIgstApplicable, isDark)),
                            ),

                            // Cess Flag
                            SizedBox(
                              width: 95,
                              child: Center(child: _buildApplicableBadge(item.isCessApplicable, isDark)),
                            ),

                            // D/E Flag
                            SizedBox(
                              width: 90,
                              child: Center(
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                  decoration: BoxDecoration(
                                    color: item.deFlag.toUpperCase() == 'E'
                                        ? (isDark ? const Color(0xFF1E3A8A).withOpacity(0.5) : const Color(0xFFDBEAFE))
                                        : (isDark ? Colors.grey.shade800 : const Color(0xFFF3F4F6)),
                                    borderRadius: BorderRadius.circular(4),
                                    border: Border.all(
                                      color: item.deFlag.toUpperCase() == 'E'
                                          ? const Color(0xFF3B82F6)
                                          : (isDark ? Colors.grey.shade700 : const Color(0xFFD1D5DB)),
                                    ),
                                  ),
                                  child: Text(
                                    item.deFlag.toUpperCase() == 'E' ? 'E (Export)' : 'D (Domestic)',
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                      color: item.deFlag.toUpperCase() == 'E'
                                          ? const Color(0xFF2563EB)
                                          : (isDark ? Colors.white70 : const Color(0xFF374151)),
                                    ),
                                  ),
                                ),
                              ),
                            ),

                            // Actions
                            SizedBox(
                              width: 115,
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.end,
                                children: [
                                  _buildSubtleActionButton(
                                    icon: Icons.visibility_outlined,
                                    tooltip: 'View Details',
                                    color: const Color(0xFF2563EB),
                                    onPressed: () => _viewClearanceDetails(context, item),
                                  ),
                                  if (canManage) ...[
                                    _buildSubtleActionButton(
                                      icon: Icons.edit_outlined,
                                      tooltip: 'Edit Clearance Type',
                                      color: const Color(0xFF059669),
                                      onPressed: () => _openClearanceDialog(context, companyId, item: item),
                                    ),
                                    _buildSubtleActionButton(
                                      icon: Icons.delete_outline_rounded,
                                      tooltip: 'Delete Clearance Type',
                                      color: const Color(0xFFDC2626),
                                      onPressed: () => _confirmDelete(context, item, companyId),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ],
                        ),
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

  Widget _buildApplicableBadge(bool isApplicable, bool isDark) {
    if (isApplicable) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
        decoration: BoxDecoration(
          color: const Color(0xFF10B981).withOpacity(0.12),
          borderRadius: BorderRadius.circular(4),
          border: Border.all(color: const Color(0xFF10B981).withOpacity(0.3)),
        ),
        child: const Text(
          'Yes',
          style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF059669)),
        ),
      );
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withOpacity(0.04) : const Color(0xFFF3F4F6),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: isDark ? Colors.white12 : const Color(0xFFE5E7EB)),
      ),
      child: Text(
        'No',
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: isDark ? Colors.white38 : const Color(0xFF9CA3AF),
        ),
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
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 12.5,
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

  Widget _buildSubtleActionButton({
    required IconData icon,
    required String tooltip,
    required Color color,
    required VoidCallback onPressed,
  }) {
    return IconButton(
      icon: Icon(icon, size: 17, color: color),
      tooltip: tooltip,
      splashRadius: 18,
      padding: const EdgeInsets.all(6),
      constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
      onPressed: onPressed,
    );
  }

  void _openClearanceDialog(BuildContext context, String companyId, {ClearanceTypeModel? item}) {
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogCtx) => _ClearanceFormDialog(
        companyId: companyId,
        existingItem: item,
      ),
    );
  }

  void _viewClearanceDetails(BuildContext context, ClearanceTypeModel item) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final dateFmt = DateFormat('dd MMM yyyy, hh:mm a');

    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFF0D9488).withOpacity(0.15),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.verified_user_rounded, color: Color(0xFF0D9488), size: 20),
            ),
            const SizedBox(width: 10),
            const Text('Clearance Type Details', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildDetailRow('Clearance Type', item.clearanceType, isDark),
              const SizedBox(height: 10),
              _buildDetailRow('C-GST Applicable', item.isCgstApplicable ? 'Yes' : 'No', isDark),
              const SizedBox(height: 10),
              _buildDetailRow('S-GST Applicable', item.isSgstApplicable ? 'Yes' : 'No', isDark),
              const SizedBox(height: 10),
              _buildDetailRow('I-GST Applicable', item.isIgstApplicable ? 'Yes' : 'No', isDark),
              const SizedBox(height: 10),
              _buildDetailRow('Cess Applicable', item.isCessApplicable ? 'Yes' : 'No', isDark),
              const SizedBox(height: 10),
              _buildDetailRow('Domestic/Export', item.deFlag == 'E' ? 'Export (E)' : 'Domestic (D)', isDark),
              const SizedBox(height: 10),
              _buildDetailRow('Remark', item.remark ?? '—', isDark),
              const SizedBox(height: 10),
              _buildDetailRow('Bond Details', item.bondDetails ?? '—', isDark),
              const SizedBox(height: 10),
              _buildDetailRow('Created At', dateFmt.format(item.createdAt), isDark),
              const SizedBox(height: 10),
              _buildDetailRow('Updated At', dateFmt.format(item.updatedAt), isDark),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value, bool isDark) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 130,
          child: Text(
            label,
            style: TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w600,
              color: isDark ? Colors.white60 : const Color(0xFF6B7280),
            ),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
          ),
        ),
      ],
    );
  }

  Future<void> _confirmDelete(BuildContext context, ClearanceTypeModel item, String companyId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        title: const Text('Delete Clearance Type', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        content: Text('Are you sure you want to delete clearance type "${item.clearanceType}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await ref.read(clearanceTypeRepositoryProvider).deleteClearanceType(companyId, item.clearanceId);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Clearance Type "${item.clearanceType}" deleted successfully.'),
              backgroundColor: AppColors.success,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to delete: $e'), backgroundColor: AppColors.error),
          );
        }
      }
    }
  }
}

class _ClearanceFormDialog extends ConsumerStatefulWidget {
  final String companyId;
  final ClearanceTypeModel? existingItem;

  const _ClearanceFormDialog({
    required this.companyId,
    this.existingItem,
  });

  @override
  ConsumerState<_ClearanceFormDialog> createState() => _ClearanceFormDialogState();
}

class _ClearanceFormDialogState extends ConsumerState<_ClearanceFormDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _typeController;
  late final TextEditingController _remarkController;
  late final TextEditingController _bondController;

  late bool _cgst;
  late bool _sgst;
  late bool _igst;
  late bool _cess;
  late String _deFlag;

  bool _isSaving = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    final item = widget.existingItem;
    _typeController = TextEditingController(text: item?.clearanceType ?? '');
    _remarkController = TextEditingController(text: item?.remark ?? '');
    _bondController = TextEditingController(text: item?.bondDetails ?? '');

    _cgst = item?.isCgstApplicable ?? true;
    _sgst = item?.isSgstApplicable ?? true;
    _igst = item?.isIgstApplicable ?? false;
    _cess = item?.isCessApplicable ?? false;
    _deFlag = item?.deFlag ?? 'D';
  }

  @override
  void dispose() {
    _typeController.dispose();
    _remarkController.dispose();
    _bondController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    final typeName = _typeController.text.trim();
    final remark = _remarkController.text.trim();
    final bond = _bondController.text.trim();

    setState(() {
      _isSaving = true;
      _errorMessage = null;
    });

    try {
      final repo = ref.read(clearanceTypeRepositoryProvider);
      final isDup = await repo.isDuplicate(
        widget.companyId,
        typeName,
        excludeId: widget.existingItem?.clearanceId,
      );

      if (isDup) {
        setState(() {
          _isSaving = false;
          _errorMessage = 'Clearance Type "$typeName" already exists.';
        });
        return;
      }

      if (widget.existingItem != null) {
        final updated = widget.existingItem!.copyWith(
          clearanceType: typeName,
          isCgstApplicable: _cgst,
          isSgstApplicable: _sgst,
          isIgstApplicable: _igst,
          isCessApplicable: _cess,
          remark: remark,
          deFlag: _deFlag,
          bondDetails: bond,
          updatedAt: DateTime.now(),
        );
        await repo.updateClearanceType(widget.companyId, updated);
      } else {
        final newItem = ClearanceTypeModel(
          clearanceId: '',
          companyId: widget.companyId,
          clearanceType: typeName,
          isCgstApplicable: _cgst,
          isSgstApplicable: _sgst,
          isIgstApplicable: _igst,
          isCessApplicable: _cess,
          remark: remark,
          deFlag: _deFlag,
          bondDetails: bond,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );
        await repo.createClearanceType(widget.companyId, newItem);
      }

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(widget.existingItem != null
                ? 'Clearance Type updated successfully.'
                : 'Clearance Type created successfully.'),
            backgroundColor: AppColors.success,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isSaving = false;
          _errorMessage = 'Error saving Clearance Type: $e';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isEditing = widget.existingItem != null;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 550),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppSizes.p20),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: const Color(0xFF0D9488).withOpacity(0.12),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(Icons.verified_user_rounded, color: Color(0xFF0D9488), size: 20),
                    ),
                    const SizedBox(width: 10),
                    Text(
                      isEditing ? 'Edit Clearance Type' : 'New Clearance Type',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                if (_errorMessage != null) ...[
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppColors.error.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: AppColors.error.withOpacity(0.3)),
                    ),
                    child: Text(
                      _errorMessage!,
                      style: const TextStyle(color: AppColors.error, fontSize: 12.5),
                    ),
                  ),
                  const SizedBox(height: 14),
                ],

                // Clearance Type Name
                TextFormField(
                  controller: _typeController,
                  autofocus: true,
                  textCapitalization: TextCapitalization.words,
                  style: const TextStyle(fontSize: 13.5),
                  decoration: const InputDecoration(
                    labelText: 'Clearance Type *',
                    hintText: 'e.g. Domestic Sale, Export with LUT, SEZ Zero Rated',
                    prefixIcon: Icon(Icons.description_outlined, size: 20),
                  ),
                  validator: (val) {
                    if (val == null || val.trim().isEmpty) {
                      return 'Clearance Type is required';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),

                // Domestic / Export (D/E) Radio selection
                Text(
                  'Domestic / Export (D/E)',
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                    color: isDark ? const Color(0xFFD1D5DB) : const Color(0xFF374151),
                  ),
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Expanded(
                      child: RadioListTile<String>(
                        value: 'D',
                        groupValue: _deFlag,
                        title: const Text('Domestic (D)', style: TextStyle(fontSize: 13)),
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                        onChanged: (val) {
                          if (val != null) setState(() => _deFlag = val);
                        },
                      ),
                    ),
                    Expanded(
                      child: RadioListTile<String>(
                        value: 'E',
                        groupValue: _deFlag,
                        title: const Text('Export (E)', style: TextStyle(fontSize: 13)),
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                        onChanged: (val) {
                          if (val != null) setState(() => _deFlag = val);
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // GST Applicable Flags (CGST, SGST, IGST, Cess)
                Text(
                  'Tax Applicability',
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                    color: isDark ? const Color(0xFFD1D5DB) : const Color(0xFF374151),
                  ),
                ),
                const SizedBox(height: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: isDark ? AppColors.borderDark : const Color(0xFFE5E7EB),
                    ),
                  ),
                  child: Column(
                    children: [
                      CheckboxListTile(
                        value: _cgst,
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                        title: const Text('C-GST Applicable?', style: TextStyle(fontSize: 13)),
                        onChanged: (val) => setState(() => _cgst = val ?? false),
                      ),
                      const Divider(height: 1),
                      CheckboxListTile(
                        value: _sgst,
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                        title: const Text('S-GST Applicable?', style: TextStyle(fontSize: 13)),
                        onChanged: (val) => setState(() => _sgst = val ?? false),
                      ),
                      const Divider(height: 1),
                      CheckboxListTile(
                        value: _igst,
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                        title: const Text('I-GST Applicable?', style: TextStyle(fontSize: 13)),
                        onChanged: (val) => setState(() => _igst = val ?? false),
                      ),
                      const Divider(height: 1),
                      CheckboxListTile(
                        value: _cess,
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                        title: const Text('Cess Applicable?', style: TextStyle(fontSize: 13)),
                        onChanged: (val) => setState(() => _cess = val ?? false),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),

                // Bond Details
                TextFormField(
                  controller: _bondController,
                  style: const TextStyle(fontSize: 13.5),
                  decoration: const InputDecoration(
                    labelText: 'Bond Details',
                    hintText: 'e.g. LUT / Bond No. 2026/LUT/001',
                    prefixIcon: Icon(Icons.assignment_outlined, size: 20),
                  ),
                ),
                const SizedBox(height: 14),

                // Remark
                TextFormField(
                  controller: _remarkController,
                  maxLines: 2,
                  style: const TextStyle(fontSize: 13.5),
                  decoration: const InputDecoration(
                    labelText: 'Remark',
                    hintText: 'Additional notes or statutory references',
                    prefixIcon: Icon(Icons.notes_rounded, size: 20),
                  ),
                ),
                const SizedBox(height: 20),

                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: _isSaving ? null : () => Navigator.pop(context),
                      child: const Text('Cancel'),
                    ),
                    const SizedBox(width: 10),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primaryLight,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                      ),
                      onPressed: _isSaving ? null : _submit,
                      child: _isSaving
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                            )
                          : Text(isEditing ? 'Save Changes' : 'Create Clearance Type'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
