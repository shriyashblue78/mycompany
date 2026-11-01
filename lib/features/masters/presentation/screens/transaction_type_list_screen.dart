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
import '../../domain/models/transaction_type_model.dart';
import '../providers/transaction_type_provider.dart';

class TransactionTypeListScreen extends ConsumerStatefulWidget {
  const TransactionTypeListScreen({super.key});

  @override
  ConsumerState<TransactionTypeListScreen> createState() => _TransactionTypeListScreenState();
}

class _TransactionTypeListScreenState extends ConsumerState<TransactionTypeListScreen> {
  @override
  Widget build(BuildContext context) {
    final typesAsync = ref.watch(filteredTransactionTypesProvider);
    final authState = ref.watch(authProvider);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final isMobile = ResponsiveLayout.isMobile(context);

    final role = authState.selectedRole ?? 'Employee';
    final canManage = role == 'Owner' || role == 'Accountant';
    final companyId = authState.user?.companyId ?? '';

    final appBar = AppBar(
      title: const Text(
        'Transaction Type Master',
        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
      ),
      elevation: 0,
    );

    return typesAsync.when(
      data: (types) {
        final body = RefreshIndicator(
          onRefresh: () async {
            ref.invalidate(companyTransactionTypesStreamProvider);
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
                      count: types.length,
                    ),
                    const SizedBox(height: AppSizes.p12),
                    if (types.isEmpty)
                      EmptyStateWidget(
                        icon: Icons.swap_horiz_rounded,
                        title: 'No Transaction Types Found',
                        description: ref.watch(transactionTypeSearchQueryProvider).isNotEmpty
                            ? 'No transaction types match your search. Try a different query.'
                            : 'Configure types for inward, outward, sales dispatch, purchase receipt, and internal adjustments.',
                      )
                    else
                      _buildTypeDataTable(
                        context: context,
                        types: types,
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
                Text('Error loading transaction types: $err'),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: () => ref.invalidate(companyTransactionTypesStreamProvider),
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
              maxWidth: isMobile ? double.infinity : 400,
              minWidth: isMobile ? double.infinity : 280,
            ),
            child: SizedBox(
              height: 42,
              child: TextField(
                onChanged: (val) => ref.read(transactionTypeSearchQueryProvider.notifier).state = val,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: isDark ? Colors.white : const Color(0xFF111827),
                ),
                decoration: InputDecoration(
                  hintText: 'Search Transaction Type...',
                  hintStyle: TextStyle(
                    fontSize: 13.5,
                    color: isDark ? Colors.white54 : const Color(0xFF6B7280),
                  ),
                  prefixIcon: Icon(
                    Icons.search_rounded,
                    size: 20,
                    color: isDark ? Colors.white70 : const Color(0xFF4B5563),
                  ),
                  suffixIcon: ref.watch(transactionTypeSearchQueryProvider).isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear_rounded, size: 18),
                          splashRadius: 18,
                          onPressed: () => ref.read(transactionTypeSearchQueryProvider.notifier).state = '',
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

          // Total count badge and New Type button
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
                    onPressed: () => _openTypeDialog(context, companyId),
                    icon: const Icon(Icons.add_rounded, size: 18),
                    label: const Text(
                      'New Type',
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

  Widget _buildTypeDataTable({
    required BuildContext context,
    required List<TransactionTypeModel> types,
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
          const double minTableWidth = 680;
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
                        _buildHeaderCell('Sr. No.', width: 75, alignment: Alignment.center, isDark: isDark),
                        _buildHeaderCell('Transaction Type Name', flex: 4, minWidth: 200, isDark: isDark),
                        _buildHeaderCell('Category', flex: 2, minWidth: 130, isDark: isDark),
                        _buildHeaderCell('Actions', width: 135, alignment: Alignment.center, isDark: isDark),
                      ],
                    ),
                  ),
                  // Spreadsheet Rows
                  ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: types.length,
                    separatorBuilder: (_, __) => Divider(
                      height: 1,
                      thickness: 1,
                      color: borderColor,
                    ),
                    itemBuilder: (context, index) {
                      final type = types[index];
                      return _buildTableRow(
                        context: context,
                        index: index,
                        type: type,
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
    required TransactionTypeModel type,
    required bool canManage,
    required String companyId,
    required ThemeData theme,
    required bool isDark,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
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
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: isDark ? const Color(0xFF9CA3AF) : const Color(0xFF6B7280),
                ),
              ),
            ),
          ),

          // Transaction Type Name
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
                      color: const Color(0xFF6366F1).withOpacity(isDark ? 0.22 : 0.1),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Icon(
                      Icons.swap_horiz_rounded,
                      size: 16,
                      color: Color(0xFF6366F1),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      type.typeName,
                      style: TextStyle(
                        fontSize: 13.5,
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

          // Category
          Expanded(
            flex: 2,
            child: ConstrainedBox(
              constraints: const BoxConstraints(minWidth: 130),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: isDark ? Colors.white.withOpacity(0.06) : Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  type.category != null && type.category!.isNotEmpty ? type.category! : 'General',
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
                ),
              ),
            ),
          ),

          // Actions
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
                  onPressed: () => _viewTypeDetails(context, type),
                ),
                if (canManage) ...[
                  const SizedBox(width: 4),
                  _buildSubtleActionButton(
                    icon: Icons.edit_outlined,
                    tooltip: 'Edit Type',
                    color: const Color(0xFF059669),
                    hoverColor: const Color(0xFF059669).withOpacity(0.12),
                    onPressed: () => _openTypeDialog(context, companyId, type: type),
                  ),
                  const SizedBox(width: 4),
                  _buildSubtleActionButton(
                    icon: Icons.delete_outline_rounded,
                    tooltip: 'Delete Type',
                    color: const Color(0xFFDC2626),
                    hoverColor: const Color(0xFFDC2626).withOpacity(0.12),
                    onPressed: () => _confirmDelete(context, type, companyId),
                  ),
                ],
              ],
            ),
          ),
        ],
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

  void _viewTypeDetails(BuildContext context, TransactionTypeModel type) {
    showDialog(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFF6366F1).withOpacity(0.15),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.swap_horiz_rounded, color: Color(0xFF6366F1), size: 22),
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: Text('Transaction Type Details', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
        content: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 450),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildDetailRow('Transaction Type Name', type.typeName),
              const SizedBox(height: 10),
              _buildDetailRow('Category', type.category ?? 'General'),
              if (type.description != null && type.description!.isNotEmpty) ...[
                const SizedBox(height: 10),
                _buildDetailRow('Description', type.description!),
              ],
              const SizedBox(height: 10),
              _buildDetailRow(
                'Last Updated',
                DateFormat('dd MMM yyyy, hh:mm a').format(type.updatedAt),
              ),
            ],
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

  Widget _buildDetailRow(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey, fontWeight: FontWeight.w500)),
        const SizedBox(height: 2),
        Text(value, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
      ],
    );
  }

  Future<void> _openTypeDialog(BuildContext context, String companyId, {TransactionTypeModel? type}) async {
    final isEdit = type != null;
    final formKey = GlobalKey<FormState>();
    final nameController = TextEditingController(text: type?.typeName ?? '');
    String selectedCategory = type?.category ?? 'Inward';
    final descController = TextEditingController(text: type?.description ?? '');

    final categories = ['Inward', 'Outward', 'Internal Transfer', 'Adjustment', 'Sales Dispatch', 'Purchase Receipt'];

    await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dialogCtx) {
        bool isSaving = false;
        String? errorMessage;

        return StatefulBuilder(
          builder: (ctx, setDialogState) {
            return AlertDialog(
              title: Row(
                children: [
                  Icon(
                    isEdit ? Icons.edit_rounded : Icons.add_circle_outline_rounded,
                    color: isEdit ? Colors.blue : AppColors.primaryLight,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    isEdit ? 'Edit Transaction Type' : 'New Transaction Type',
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              content: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 450),
                child: SingleChildScrollView(
                  child: Form(
                    key: formKey,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        TextFormField(
                          controller: nameController,
                          autofocus: true,
                          decoration: InputDecoration(
                            labelText: 'Transaction Type Name *',
                            hintText: 'e.g. Raw Material Inward, Job Work Outward',
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(AppSizes.inputRadius),
                            ),
                          ),
                          validator: (val) {
                            if (val == null || val.trim().isEmpty) {
                              return 'Transaction type name is required';
                            }
                            if (val.trim().length < 2) {
                              return 'Must be at least 2 characters';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: AppSizes.p16),
                        DropdownButtonFormField<String>(
                          value: categories.contains(selectedCategory) ? selectedCategory : categories.first,
                          decoration: InputDecoration(
                            labelText: 'Category',
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(AppSizes.inputRadius),
                            ),
                          ),
                          items: categories.map((cat) {
                            return DropdownMenuItem(value: cat, child: Text(cat));
                          }).toList(),
                          onChanged: (val) {
                            if (val != null) {
                              setDialogState(() => selectedCategory = val);
                            }
                          },
                        ),
                        const SizedBox(height: AppSizes.p16),
                        TextFormField(
                          controller: descController,
                          maxLines: 2,
                          decoration: InputDecoration(
                            labelText: 'Description (Optional)',
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(AppSizes.inputRadius),
                            ),
                          ),
                        ),
                        if (errorMessage != null) ...[
                          const SizedBox(height: 12),
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: AppColors.error.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: AppColors.error.withOpacity(0.3)),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.error_outline_rounded, color: AppColors.error, size: 18),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    errorMessage!,
                                    style: const TextStyle(color: AppColors.error, fontSize: 12),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: isSaving ? null : () => Navigator.pop(dialogCtx, false),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: isSaving
                      ? null
                      : () async {
                          if (!formKey.currentState!.validate()) return;
                          final newName = nameController.text.trim();
                          final repo = ref.read(transactionTypeRepositoryProvider);

                          setDialogState(() {
                            isSaving = true;
                            errorMessage = null;
                          });

                          try {
                            final isTaken = await repo.isTypeNameTaken(
                              companyId,
                              newName,
                              excludeTypeId: isEdit ? type.typeId : null,
                            );

                            if (isTaken) {
                              setDialogState(() {
                                isSaving = false;
                                errorMessage = 'A transaction type named "$newName" already exists.';
                              });
                              return;
                            }

                            if (isEdit) {
                              final updated = type.copyWith(
                                typeName: newName,
                                category: selectedCategory,
                                description: descController.text.trim(),
                                updatedAt: DateTime.now(),
                              );
                              await repo.updateTransactionType(companyId, updated);
                            } else {
                              final newType = TransactionTypeModel(
                                typeId: '',
                                companyId: companyId,
                                typeName: newName,
                                category: selectedCategory,
                                description: descController.text.trim(),
                                createdAt: DateTime.now(),
                                updatedAt: DateTime.now(),
                              );
                              await repo.createTransactionType(companyId, newType);
                            }

                            ref.invalidate(companyTransactionTypesStreamProvider);

                            if (ctx.mounted) {
                              Navigator.pop(dialogCtx, true);
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    isEdit
                                        ? 'Transaction type updated successfully'
                                        : 'Transaction type created successfully',
                                  ),
                                  backgroundColor: AppColors.success,
                                ),
                              );
                            }
                          } catch (e) {
                            setDialogState(() {
                              isSaving = false;
                              errorMessage = 'Error saving transaction type: $e';
                            });
                          }
                        },
                  child: isSaving
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : Text(isEdit ? 'Update' : 'Create'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _confirmDelete(BuildContext context, TransactionTypeModel type, String companyId) {
    showDialog(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: AppColors.error),
            SizedBox(width: 8),
            Text('Delete Transaction Type'),
          ],
        ),
        content: Text('Are you sure you want to delete "${type.typeName}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
            onPressed: () async {
              Navigator.pop(dialogCtx);
              try {
                final repo = ref.read(transactionTypeRepositoryProvider);
                await repo.deleteTransactionType(companyId, type.typeId);
                ref.invalidate(companyTransactionTypesStreamProvider);

                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Transaction type deleted successfully'),
                      backgroundColor: AppColors.success,
                    ),
                  );
                }
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Failed to delete transaction type: $e'),
                      backgroundColor: AppColors.error,
                    ),
                  );
                }
              }
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }
}
