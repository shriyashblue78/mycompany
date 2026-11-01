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
import '../../domain/models/pdi_master_model.dart';
import '../providers/pdi_master_provider.dart';

class PdiMasterListScreen extends ConsumerStatefulWidget {
  const PdiMasterListScreen({super.key});

  @override
  ConsumerState<PdiMasterListScreen> createState() => _PdiMasterListScreenState();
}

class _PdiMasterListScreenState extends ConsumerState<PdiMasterListScreen> {
  @override
  Widget build(BuildContext context) {
    final pdiAsync = ref.watch(filteredPdiMasterProvider);
    final authState = ref.watch(authProvider);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final isMobile = ResponsiveLayout.isMobile(context);

    final role = authState.selectedRole ?? 'Employee';
    final canManage = role == 'Owner' || role == 'Accountant';
    final companyId = authState.user?.companyId ?? '';

    final appBar = AppBar(
      title: const Text(
        'PDI Master',
        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
      ),
      elevation: 0,
    );

    return pdiAsync.when(
      data: (items) {
        final body = RefreshIndicator(
          onRefresh: () async {
            ref.invalidate(companyPdiMasterStreamProvider);
          },
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: EdgeInsets.symmetric(
              horizontal: isMobile ? AppSizes.p12 : AppSizes.p24,
              vertical: isMobile ? AppSizes.p12 : AppSizes.p16,
            ),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1100),
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
                        icon: Icons.fact_check_outlined,
                        title: 'No PDI Records Found',
                        description: ref.watch(pdiMasterSearchQueryProvider).isNotEmpty
                            ? 'No PDI items match your search. Try a different query.'
                            : 'Configure Pre-Delivery Inspection (PDI) items and part numbers.',
                      )
                    else
                      _buildPdiDataTable(
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
                Text('Error loading PDI Master: $err'),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: () => ref.invalidate(companyPdiMasterStreamProvider),
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
          // Search input
          ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: isMobile ? double.infinity : 360,
              minWidth: isMobile ? double.infinity : 260,
            ),
            child: SizedBox(
              height: 40,
              child: TextField(
                onChanged: (val) => ref.read(pdiMasterSearchQueryProvider.notifier).state = val,
                style: TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w500,
                  color: isDark ? Colors.white : const Color(0xFF111827),
                ),
                decoration: InputDecoration(
                  hintText: 'Search by Item Name or Part No...',
                  hintStyle: TextStyle(
                    fontSize: 13,
                    color: isDark ? Colors.white54 : const Color(0xFF6B7280),
                  ),
                  prefixIcon: Icon(
                    Icons.search_rounded,
                    size: 19,
                    color: isDark ? Colors.white70 : const Color(0xFF4B5563),
                  ),
                  suffixIcon: ref.watch(pdiMasterSearchQueryProvider).isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear_rounded, size: 16),
                          splashRadius: 16,
                          onPressed: () => ref.read(pdiMasterSearchQueryProvider.notifier).state = '',
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

          // Total Count & + New Button
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
                    onPressed: () => _openPdiDialog(context, companyId),
                    icon: const Icon(Icons.add_rounded, size: 18),
                    label: const Text(
                      'New PDI Item',
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

  Widget _buildPdiDataTable({
    required BuildContext context,
    required List<PdiMasterModel> items,
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
          const double minTableWidth = 650;
          final double tableWidth = constraints.maxWidth > minTableWidth
              ? constraints.maxWidth
              : minTableWidth;

          return SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: SizedBox(
              width: tableWidth,
              child: Column(
                children: [
                  // Table Header: Sr. No. | Item Name | Part No. | Actions
                  Container(
                    height: 42,
                    decoration: BoxDecoration(
                      color: headerBgColor,
                      border: Border(bottom: BorderSide(color: borderColor, width: 1.5)),
                    ),
                    child: Row(
                      children: [
                        _buildHeaderCell('Sr. No.', width: 80, alignment: Alignment.center, isDark: isDark),
                        _buildHeaderCell('Item Name', flex: 5, minWidth: 220, isDark: isDark),
                        _buildHeaderCell('Part No.', flex: 4, minWidth: 160, isDark: isDark),
                        _buildHeaderCell('Actions', width: 120, alignment: Alignment.centerRight, isDark: isDark),
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
                        padding: const EdgeInsets.symmetric(horizontal: 14),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            // Sr. No.
                            SizedBox(
                              width: 80,
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

                            // Item Name
                            Expanded(
                              flex: 5,
                              child: ConstrainedBox(
                                constraints: const BoxConstraints(minWidth: 220),
                                child: Row(
                                  children: [
                                    Container(
                                      width: 28,
                                      height: 28,
                                      decoration: BoxDecoration(
                                        color: const Color(0xFF6366F1).withOpacity(isDark ? 0.22 : 0.1),
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: const Icon(Icons.fact_check_rounded, color: Color(0xFF6366F1), size: 15),
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: Text(
                                        item.itemName,
                                        style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13.5),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),

                            // Part No.
                            Expanded(
                              flex: 4,
                              child: ConstrainedBox(
                                constraints: const BoxConstraints(minWidth: 160),
                                child: Text(
                                  item.partNo,
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontFamily: 'monospace',
                                    fontWeight: FontWeight.w600,
                                    color: isDark ? const Color(0xFFA5B4FC) : const Color(0xFF4338CA),
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ),

                            // Actions
                            SizedBox(
                              width: 120,
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.end,
                                children: [
                                  _buildSubtleActionButton(
                                    icon: Icons.visibility_outlined,
                                    tooltip: 'View Details',
                                    color: const Color(0xFF2563EB),
                                    onPressed: () => _viewPdiDetails(context, item),
                                  ),
                                  if (canManage) ...[
                                    _buildSubtleActionButton(
                                      icon: Icons.edit_outlined,
                                      tooltip: 'Edit PDI Item',
                                      color: const Color(0xFF059669),
                                      onPressed: () => _openPdiDialog(context, companyId, item: item),
                                    ),
                                    _buildSubtleActionButton(
                                      icon: Icons.delete_outline_rounded,
                                      tooltip: 'Delete PDI Item',
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

  void _openPdiDialog(BuildContext context, String companyId, {PdiMasterModel? item}) {
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogCtx) => _PdiFormDialog(
        companyId: companyId,
        existingItem: item,
      ),
    );
  }

  void _viewPdiDetails(BuildContext context, PdiMasterModel item) {
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
                color: const Color(0xFF6366F1).withOpacity(0.15),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.fact_check_rounded, color: Color(0xFF6366F1), size: 20),
            ),
            const SizedBox(width: 10),
            const Text('PDI Master Details', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildDetailRow('Item Name', item.itemName, isDark),
            const SizedBox(height: 10),
            _buildDetailRow('Part No.', item.partNo, isDark),
            const SizedBox(height: 10),
            _buildDetailRow('Created At', dateFmt.format(item.createdAt), isDark),
            const SizedBox(height: 10),
            _buildDetailRow('Updated At', dateFmt.format(item.updatedAt), isDark),
          ],
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
          width: 100,
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

  Future<void> _confirmDelete(BuildContext context, PdiMasterModel item, String companyId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        title: const Text('Delete PDI Item', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        content: Text('Are you sure you want to delete PDI item "${item.itemName}" (${item.partNo})?'),
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
        await ref.read(pdiMasterRepositoryProvider).deletePdi(companyId, item.pdiId);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('PDI Item "${item.itemName}" deleted successfully.'),
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

class _PdiFormDialog extends ConsumerStatefulWidget {
  final String companyId;
  final PdiMasterModel? existingItem;

  const _PdiFormDialog({
    required this.companyId,
    this.existingItem,
  });

  @override
  ConsumerState<_PdiFormDialog> createState() => _PdiFormDialogState();
}

class _PdiFormDialogState extends ConsumerState<_PdiFormDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _partNoController;
  bool _isSaving = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.existingItem?.itemName ?? '');
    _partNoController = TextEditingController(text: widget.existingItem?.partNo ?? '');
  }

  @override
  void dispose() {
    _nameController.dispose();
    _partNoController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    final itemName = _nameController.text.trim();
    final partNo = _partNoController.text.trim();

    setState(() {
      _isSaving = true;
      _errorMessage = null;
    });

    try {
      final repo = ref.read(pdiMasterRepositoryProvider);
      final isDup = await repo.isDuplicate(
        widget.companyId,
        itemName,
        partNo,
        excludePdiId: widget.existingItem?.pdiId,
      );

      if (isDup) {
        setState(() {
          _isSaving = false;
          _errorMessage = 'A PDI record with Item Name "$itemName" and Part No. "$partNo" already exists.';
        });
        return;
      }

      if (widget.existingItem != null) {
        final updated = widget.existingItem!.copyWith(
          itemName: itemName,
          partNo: partNo,
          updatedAt: DateTime.now(),
        );
        await repo.updatePdi(widget.companyId, updated);
      } else {
        final newItem = PdiMasterModel(
          pdiId: '',
          companyId: widget.companyId,
          itemName: itemName,
          partNo: partNo,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );
        await repo.createPdi(widget.companyId, newItem);
      }

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(widget.existingItem != null
                ? 'PDI Item updated successfully.'
                : 'PDI Item added successfully.'),
            backgroundColor: AppColors.success,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isSaving = false;
          _errorMessage = 'Error saving PDI Item: $e';
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
        constraints: const BoxConstraints(maxWidth: 480),
        child: Padding(
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
                        color: const Color(0xFF6366F1).withOpacity(0.12),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(Icons.fact_check_rounded, color: Color(0xFF6366F1), size: 20),
                    ),
                    const SizedBox(width: 10),
                    Text(
                      isEditing ? 'Edit PDI Item' : 'New PDI Item',
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

                // Item Name
                TextFormField(
                  controller: _nameController,
                  autofocus: true,
                  textCapitalization: TextCapitalization.words,
                  style: const TextStyle(fontSize: 13.5),
                  decoration: const InputDecoration(
                    labelText: 'Item Name *',
                    hintText: 'e.g. Flange Adapter, Connecting Rod',
                    prefixIcon: Icon(Icons.inventory_2_outlined, size: 20),
                  ),
                  validator: (val) {
                    if (val == null || val.trim().isEmpty) {
                      return 'Item Name is required';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 14),

                // Part No.
                TextFormField(
                  controller: _partNoController,
                  textCapitalization: TextCapitalization.characters,
                  style: const TextStyle(fontSize: 13.5),
                  decoration: const InputDecoration(
                    labelText: 'Part No. *',
                    hintText: 'e.g. PRT-1002, FLG-09',
                    prefixIcon: Icon(Icons.tag_rounded, size: 20),
                  ),
                  validator: (val) {
                    if (val == null || val.trim().isEmpty) {
                      return 'Part No. is required';
                    }
                    return null;
                  },
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
                          : Text(isEditing ? 'Save Changes' : 'Create Item'),
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
