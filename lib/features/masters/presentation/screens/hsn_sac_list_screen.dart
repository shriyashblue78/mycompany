import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_sizes.dart';
import '../../../../core/widgets/erp_drawer.dart';
import '../../../../core/widgets/polish_widgets.dart';
import '../../../../core/widgets/responsive_layout.dart';
import '../../../../core/widgets/responsive_widgets.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../domain/models/hsn_sac_model.dart';
import '../providers/hsn_sac_provider.dart';
import '../providers/tax_provider.dart';

class HsnSacListScreen extends ConsumerStatefulWidget {
  const HsnSacListScreen({super.key});

  @override
  ConsumerState<HsnSacListScreen> createState() => _HsnSacListScreenState();
}

class _HsnSacListScreenState extends ConsumerState<HsnSacListScreen> {
  @override
  Widget build(BuildContext context) {
    final listAsync = ref.watch(filteredHsnSacProvider);
    final taxesAsync = ref.watch(companyTaxesStreamProvider);
    final authState = ref.watch(authProvider);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final isMobile = ResponsiveLayout.isMobile(context);

    final role = authState.selectedRole ?? 'Employee';
    final canManage = role == 'Owner' || role == 'Accountant';
    final companyId = authState.user?.companyId ?? '';
    final taxes = taxesAsync.valueOrNull ?? [];

    final appBar = AppBar(
      title: const Text(
        'HSN/SAC Master',
        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
      ),
      elevation: 0,
    );

    return listAsync.when(
      data: (items) {
        final body = RefreshIndicator(
          onRefresh: () async {
            ref.invalidate(companyHsnSacStreamProvider);
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
                      taxes: taxes,
                      canManage: canManage,
                      theme: theme,
                      isDark: isDark,
                      isMobile: isMobile,
                      count: items.length,
                    ),
                    const SizedBox(height: AppSizes.p12),
                    if (items.isEmpty)
                      EmptyStateWidget(
                        icon: Icons.tag_rounded,
                        title: 'No HSN/SAC Codes Found',
                        description: ref.watch(hsnSacSearchQueryProvider).isNotEmpty
                            ? 'No codes match your search query.'
                            : 'Maintain Harmonized System of Nomenclature and Service Accounting Codes with GST tax categories.',
                      )
                    else
                      _buildHsnSacDataTable(
                        context: context,
                        items: items,
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
                Text('Error loading HSN/SAC: $err'),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: () => ref.invalidate(companyHsnSacStreamProvider),
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
    required List<dynamic> taxes,
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
                onChanged: (val) => ref.read(hsnSacSearchQueryProvider.notifier).state = val,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: isDark ? Colors.white : const Color(0xFF111827),
                ),
                decoration: InputDecoration(
                  hintText: 'Search by Code, Description, or GST Category...',
                  hintStyle: TextStyle(
                    fontSize: 13.5,
                    color: isDark ? Colors.white54 : const Color(0xFF6B7280),
                  ),
                  prefixIcon: Icon(
                    Icons.search_rounded,
                    size: 20,
                    color: isDark ? Colors.white70 : const Color(0xFF4B5563),
                  ),
                  suffixIcon: ref.watch(hsnSacSearchQueryProvider).isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear_rounded, size: 18),
                          splashRadius: 18,
                          onPressed: () => ref.read(hsnSacSearchQueryProvider.notifier).state = '',
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

          // Total count badge and New HSN/SAC button
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
                    onPressed: () => _openHsnSacDialog(context, companyId, taxes: taxes),
                    icon: const Icon(Icons.add_rounded, size: 18),
                    label: const Text(
                      'New HSN/SAC',
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

  Widget _buildHsnSacDataTable({
    required BuildContext context,
    required List<HsnSacModel> items,
    required List<dynamic> taxes,
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
          const double minTableWidth = 780;
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
                        _buildHeaderCell('HSN / SAC Code', flex: 2, minWidth: 140, isDark: isDark),
                        _buildHeaderCell('Type', width: 100, alignment: Alignment.center, isDark: isDark),
                        _buildHeaderCell('Description', flex: 4, minWidth: 240, isDark: isDark),
                        _buildHeaderCell('GST Category', flex: 2, minWidth: 140, isDark: isDark),
                        _buildHeaderCell('Actions', width: 135, alignment: Alignment.center, isDark: isDark),
                      ],
                    ),
                  ),
                  // Spreadsheet Rows
                  ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: items.length,
                    separatorBuilder: (_, __) => Divider(
                      height: 1,
                      thickness: 1,
                      color: borderColor,
                    ),
                    itemBuilder: (context, index) {
                      final item = items[index];
                      return _buildTableRow(
                        context: context,
                        index: index,
                        item: item,
                        taxes: taxes,
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
    required HsnSacModel item,
    required List<dynamic> taxes,
    required bool canManage,
    required String companyId,
    required ThemeData theme,
    required bool isDark,
  }) {
    final zebraColor = index.isOdd
        ? (isDark ? Colors.white.withOpacity(0.02) : const Color(0xFFF9FAFB))
        : Colors.transparent;
    final isGoods = item.type == 'Goods';

    return Material(
      color: zebraColor,
      child: InkWell(
        hoverColor: isDark ? Colors.white.withOpacity(0.04) : const Color(0xFFF1F5F9),
        onTap: () => _viewHsnSacDetails(context, item),
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

              // Code tag
              Expanded(
                flex: 2,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3.5),
                      decoration: BoxDecoration(
                        color: isDark ? Colors.grey.shade800 : const Color(0xFFF3F4F6),
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(
                          color: isDark ? Colors.grey.shade700 : const Color(0xFFD1D5DB),
                        ),
                      ),
                      child: Text(
                        item.code,
                        style: TextStyle(
                          fontSize: 12.5,
                          fontFamily: 'monospace',
                          fontWeight: FontWeight.w700,
                          color: isDark ? const Color(0xFFE5E7EB) : const Color(0xFF1F2937),
                        ),
                      ),
                    ),
                  ),
                ),
              ),

              // Type badge
              SizedBox(
                width: 100,
                child: Center(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: isGoods
                          ? (isDark ? const Color(0xFF1E3A8A).withOpacity(0.5) : const Color(0xFFEFF6FF))
                          : (isDark ? const Color(0xFF581C87).withOpacity(0.5) : const Color(0xFFFAF5FF)),
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(
                        color: isGoods
                            ? (isDark ? const Color(0xFF3B82F6) : const Color(0xFFBFDBFE))
                            : (isDark ? const Color(0xFFA855F7) : const Color(0xFFE9D5FF)),
                      ),
                    ),
                    child: Text(
                      isGoods ? 'Goods' : 'Services',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: isGoods
                            ? (isDark ? const Color(0xFF93C5FD) : const Color(0xFF1D4ED8))
                            : (isDark ? const Color(0xFFD8B4FE) : const Color(0xFF7E22CE)),
                      ),
                    ),
                  ),
                ),
              ),

              // Description
              Expanded(
                flex: 4,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  child: Text(
                    item.description,
                    style: TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w500,
                      color: isDark ? Colors.white : const Color(0xFF111827),
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),

              // GST Category
              Expanded(
                flex: 2,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  child: Text(
                    (item.gstCategory != null && item.gstCategory!.isNotEmpty)
                        ? item.gstCategory!
                        : '—',
                    style: TextStyle(
                      fontSize: 13,
                      color: (item.gstCategory != null && item.gstCategory!.isNotEmpty)
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
                      onPressed: () => _viewHsnSacDetails(context, item),
                    ),
                    if (canManage) ...[
                      const SizedBox(width: 4),
                      _buildSubtleActionButton(
                        icon: Icons.edit_outlined,
                        tooltip: 'Edit HSN/SAC',
                        color: const Color(0xFF059669),
                        hoverColor: const Color(0xFF059669).withOpacity(0.12),
                        onPressed: () => _openHsnSacDialog(context, companyId, item: item, taxes: taxes),
                      ),
                      const SizedBox(width: 4),
                      _buildSubtleActionButton(
                        icon: Icons.delete_outline_rounded,
                        tooltip: 'Delete HSN/SAC',
                        color: const Color(0xFFDC2626),
                        hoverColor: const Color(0xFFDC2626).withOpacity(0.12),
                        onPressed: () => _confirmDelete(context, item, companyId),
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

  void _viewHsnSacDetails(BuildContext context, HsnSacModel item) {
    showDialog(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFF06B6D4).withOpacity(0.15),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.tag_rounded, color: Color(0xFF06B6D4), size: 22),
            ),
            const SizedBox(width: 12),
            const Text('HSN/SAC Details'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('HSN/SAC Code', style: TextStyle(fontSize: 12, color: Colors.grey, fontWeight: FontWeight.w500)),
            const SizedBox(height: 4),
            Text(item.code, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            const Text('Description', style: TextStyle(fontSize: 12, color: Colors.grey, fontWeight: FontWeight.w500)),
            const SizedBox(height: 4),
            Text(item.description, style: const TextStyle(fontSize: 14)),
            const SizedBox(height: 12),
            const Text('Classification', style: TextStyle(fontSize: 12, color: Colors.grey, fontWeight: FontWeight.w500)),
            const SizedBox(height: 4),
            Text(item.type, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
            const SizedBox(height: 12),
            const Text('GST Category', style: TextStyle(fontSize: 12, color: Colors.grey, fontWeight: FontWeight.w500)),
            const SizedBox(height: 4),
            Text(item.gstCategory ?? 'None assigned', style: const TextStyle(fontSize: 14)),
          ],
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

  Future<void> _openHsnSacDialog(
    BuildContext context,
    String companyId, {
    HsnSacModel? item,
    required List<dynamic> taxes,
  }) async {
    final isEdit = item != null;
    final formKey = GlobalKey<FormState>();
    final codeController = TextEditingController(text: item?.code ?? '');
    final descController = TextEditingController(text: item?.description ?? '');

    String selectedType = item?.type ?? 'Goods';
    String? selectedGst = item?.gstCategory;

    // Build tax options from existing Tax Master
    final taxOptions = taxes.map((t) => t.taxCategory as String).toSet().toList();
    if (selectedGst != null && !taxOptions.contains(selectedGst)) {
      taxOptions.add(selectedGst);
    }

    final result = await showDialog<bool>(
      context: context,
      builder: (dialogCtx) {
        bool isSaving = false;
        String? errorMessage;

        return StatefulBuilder(
          builder: (ctx, setDialogState) {
            return AlertDialog(
              title: Text(isEdit ? 'Edit HSN/SAC Code' : 'New HSN/SAC Code'),
              content: SizedBox(
                width: 440,
                child: Form(
                  key: formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextFormField(
                        controller: codeController,
                        autofocus: true,
                        decoration: InputDecoration(
                          labelText: 'HSN/SAC Code *',
                          hintText: 'e.g. 7318, 8471, 9987',
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(AppSizes.inputRadius)),
                        ),
                        validator: (val) {
                          if (val == null || val.trim().isEmpty) return 'Code is required';
                          return null;
                        },
                      ),
                      const SizedBox(height: AppSizes.p16),
                      TextFormField(
                        controller: descController,
                        decoration: InputDecoration(
                          labelText: 'Description *',
                          hintText: 'e.g. Screws, bolts, nuts, washers',
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(AppSizes.inputRadius)),
                        ),
                        validator: (val) {
                          if (val == null || val.trim().isEmpty) return 'Description is required';
                          return null;
                        },
                      ),
                      const SizedBox(height: AppSizes.p16),
                      DropdownButtonFormField<String>(
                        value: selectedType,
                        decoration: InputDecoration(
                          labelText: 'Goods / Services *',
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(AppSizes.inputRadius)),
                        ),
                        items: const [
                          DropdownMenuItem(value: 'Goods', child: Text('Goods (HSN)')),
                          DropdownMenuItem(value: 'Services', child: Text('Services (SAC)')),
                        ],
                        onChanged: (val) {
                          if (val != null) {
                            setDialogState(() => selectedType = val);
                          }
                        },
                      ),
                      const SizedBox(height: AppSizes.p16),
                      DropdownButtonFormField<String?>(
                        value: selectedGst,
                        isExpanded: true,
                        decoration: InputDecoration(
                          labelText: 'GST Category',
                          helperText: 'Select from configured Tax Master records',
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(AppSizes.inputRadius)),
                        ),
                        items: [
                          const DropdownMenuItem<String?>(value: null, child: Text('None (Default)')),
                          ...taxOptions.map((t) => DropdownMenuItem<String?>(value: t, child: Text(t))),
                        ],
                        onChanged: (val) {
                          setDialogState(() => selectedGst = val);
                        },
                      ),
                      if (errorMessage != null) ...[
                        const SizedBox(height: 12),
                        Text(errorMessage!, style: const TextStyle(color: AppColors.error, fontSize: 12)),
                      ],
                    ],
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
                          setDialogState(() {
                            isSaving = true;
                            errorMessage = null;
                          });
                          try {
                            final repo = ref.read(hsnSacRepositoryProvider);
                            final code = codeController.text.trim();
                            final desc = descController.text.trim();

                            if (isEdit) {
                              final updated = item.copyWith(
                                code: code,
                                description: desc,
                                type: selectedType,
                                gstCategory: selectedGst,
                              );
                              await repo.updateHsnSac(companyId, updated);
                            } else {
                              final newModel = HsnSacModel(
                                hsnSacId: '',
                                companyId: companyId,
                                code: code,
                                description: desc,
                                type: selectedType,
                                gstCategory: selectedGst,
                                createdAt: DateTime.now(),
                                updatedAt: DateTime.now(),
                              );
                              await repo.createHsnSac(companyId, newModel);
                            }
                            if (ctx.mounted) {
                              Navigator.pop(dialogCtx, true);
                            }
                          } catch (e) {
                            setDialogState(() {
                              isSaving = false;
                              errorMessage = 'Error saving code: $e';
                            });
                          }
                        },
                  child: isSaving
                      ? const SizedBox(
                          width: 16,
                          height: 16,
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

    if (result == true && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(isEdit ? 'HSN/SAC updated successfully' : 'HSN/SAC created successfully'),
          backgroundColor: AppColors.success,
        ),
      );
    }
  }

  Future<void> _confirmDelete(BuildContext context, HsnSacModel item, String companyId) async {
    final repo = ref.read(hsnSacRepositoryProvider);
    final isReferenced = await repo.isHsnSacReferenced(companyId, item.code);

    if (!mounted) return;

    if (isReferenced) {
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.warning_amber_rounded, color: AppColors.warning),
              SizedBox(width: 8),
              Text('Cannot Delete HSN/SAC'),
            ],
          ),
          content: Text(
            'The HSN/SAC code "${item.code}" is currently referenced by active inventory items or processes. Please update those records before deleting.',
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
        title: const Text('Delete HSN/SAC'),
        content: Text('Are you sure you want to permanently delete code "${item.code}"?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete', style: TextStyle(color: AppColors.error)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await repo.deleteHsnSac(companyId, item.hsnSacId);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('HSN/SAC deleted successfully'), backgroundColor: AppColors.success),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error deleting HSN/SAC: $e')),
          );
        }
      }
    }
  }
}
