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
import '../../domain/models/category_model.dart';
import '../../domain/models/item_model.dart';
import '../providers/category_provider.dart';
import '../providers/item_provider.dart';

class ItemListScreen extends ConsumerStatefulWidget {
  const ItemListScreen({super.key});

  @override
  ConsumerState<ItemListScreen> createState() => _ItemListScreenState();
}

class _ItemListScreenState extends ConsumerState<ItemListScreen> {
  @override
  Widget build(BuildContext context) {
    final itemsAsync = ref.watch(filteredItemsProvider);
    final categoriesAsync = ref.watch(companyCategoriesStreamProvider);
    final authState = ref.watch(authProvider);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final isMobile = ResponsiveLayout.isMobile(context);

    final role = authState.selectedRole ?? 'Employee';
    final canManage = role == 'Owner' || role == 'Accountant';
    final companyId = authState.user?.companyId ?? '';

    final categories = categoriesAsync.valueOrNull ?? [];
    final selectedCategory = ref.watch(itemCategoryFilterProvider);

    final appBar = AppBar(
      title: const Text(
        'Item Master',
        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
      ),
      elevation: 0,
    );

    return itemsAsync.when(
      data: (items) {
        final body = RefreshIndicator(
          onRefresh: () async {
            ref.invalidate(companyItemsStreamProvider);
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
                      categories: categories,
                      selectedCategory: selectedCategory,
                      canManage: canManage,
                      theme: theme,
                      isDark: isDark,
                      isMobile: isMobile,
                      count: items.length,
                    ),
                    const SizedBox(height: AppSizes.p12),
                    if (items.isEmpty)
                      EmptyStateWidget(
                        icon: Icons.inventory_2_outlined,
                        title: 'No Items Found',
                        description: ref.watch(itemSearchQueryProvider).isNotEmpty
                            ? 'No items match your search or filter. Try another keyword.'
                            : 'Create and organize parts, raw materials, and finished catalog items.',
                      )
                    else
                      _buildItemDataTable(
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
                Text('Error loading items: $err'),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: () => ref.invalidate(companyItemsStreamProvider),
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
    required List<CategoryModel> categories,
    required String selectedCategory,
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Wrap(
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
                    onChanged: (val) => ref.read(itemSearchQueryProvider.notifier).state = val,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: isDark ? Colors.white : const Color(0xFF111827),
                    ),
                    decoration: InputDecoration(
                      hintText: 'Search Item, Part No., Category, Group...',
                      hintStyle: TextStyle(
                        fontSize: 13.5,
                        color: isDark ? Colors.white54 : const Color(0xFF6B7280),
                      ),
                      prefixIcon: Icon(
                        Icons.search_rounded,
                        size: 20,
                        color: isDark ? Colors.white70 : const Color(0xFF4B5563),
                      ),
                      suffixIcon: ref.watch(itemSearchQueryProvider).isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear_rounded, size: 18),
                              splashRadius: 18,
                              onPressed: () => ref.read(itemSearchQueryProvider.notifier).state = '',
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

              // Total count badge and New Item button
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
                        onPressed: () => context.push('/masters/items/add'),
                        icon: const Icon(Icons.add_rounded, size: 18),
                        label: const Text(
                          'New Item',
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

          // Category Filter Chips
          if (categories.isNotEmpty) ...[
            const SizedBox(height: 10),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _buildCategoryChip('All', selectedCategory, isDark),
                  const SizedBox(width: 6),
                  ...categories.map((cat) => Padding(
                        padding: const EdgeInsets.only(right: 6),
                        child: _buildCategoryChip(cat.categoryName, selectedCategory, isDark),
                      )),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildCategoryChip(String label, String current, bool isDark) {
    final isSelected = current == label;
    return InkWell(
      borderRadius: BorderRadius.circular(6),
      onTap: () => ref.read(itemCategoryFilterProvider.notifier).state = label,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: isSelected
              ? (isDark ? AppColors.primaryDark : AppColors.primaryLight)
              : (isDark ? Colors.grey.shade800 : const Color(0xFFF3F4F6)),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
            color: isSelected
                ? (isDark ? AppColors.primaryDark : AppColors.primaryLight)
                : (isDark ? AppColors.borderDark : const Color(0xFFD1D5DB)),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
            color: isSelected ? Colors.white : (isDark ? Colors.white70 : const Color(0xFF374151)),
          ),
        ),
      ),
    );
  }

  Widget _buildItemDataTable({
    required BuildContext context,
    required List<ItemModel> items,
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
          const double minTableWidth = 960;
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
                        _buildHeaderCell('Item Name / Description', flex: 4, minWidth: 220, isDark: isDark),
                        _buildHeaderCell('Part No.', flex: 2, minWidth: 120, isDark: isDark),
                        _buildHeaderCell('Category', flex: 2, minWidth: 120, isDark: isDark),
                        _buildHeaderCell('Group', flex: 2, minWidth: 120, isDark: isDark),
                        _buildHeaderCell('Unit', width: 85, alignment: Alignment.center, isDark: isDark),
                        _buildHeaderCell('Unit Rate', width: 100, alignment: Alignment.centerRight, isDark: isDark),
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
    required ItemModel item,
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
        onTap: () => _viewItemDetails(context, item),
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

              // Item Description + finished badge
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
                          color: const Color(0xFFF59E0B).withOpacity(isDark ? 0.22 : 0.12),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Icon(
                          Icons.inventory_2_rounded,
                          size: 16,
                          color: Color(0xFFF59E0B),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              item.itemDescription.isNotEmpty ? item.itemDescription : item.itemNo,
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: isDark ? Colors.white : const Color(0xFF111827),
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                            if (item.isFinishedItem)
                              Text(
                                'Finished Product',
                                style: TextStyle(
                                  fontSize: 10.5,
                                  fontWeight: FontWeight.w700,
                                  color: isDark ? const Color(0xFF34D399) : const Color(0xFF059669),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // Part No.
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
                        item.itemNo,
                        style: TextStyle(
                          fontSize: 12,
                          fontFamily: 'monospace',
                          fontWeight: FontWeight.w700,
                          color: isDark ? const Color(0xFFE5E7EB) : const Color(0xFF1F2937),
                        ),
                      ),
                    ),
                  ),
                ),
              ),

              // Category
              Expanded(
                flex: 2,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  child: Text(
                    item.category.isNotEmpty ? item.category : '—',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: isDark ? Colors.white70 : const Color(0xFF4B5563),
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),

              // Group
              Expanded(
                flex: 2,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  child: Text(
                    item.underGroup != null && item.underGroup!.isNotEmpty ? item.underGroup! : '—',
                    style: TextStyle(
                      fontSize: 13,
                      color: item.underGroup != null && item.underGroup!.isNotEmpty
                          ? (isDark ? Colors.white70 : const Color(0xFF4B5563))
                          : (isDark ? Colors.white38 : const Color(0xFF9CA3AF)),
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),

              // Stock Unit
              SizedBox(
                width: 85,
                child: Center(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: isDark ? Colors.white.withOpacity(0.05) : const Color(0xFFF3F4F6),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      item.stockUnit,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: isDark ? Colors.white70 : const Color(0xFF374151),
                      ),
                    ),
                  ),
                ),
              ),

              // Unit Rate
              SizedBox(
                width: 100,
                child: Padding(
                  padding: const EdgeInsets.only(right: 14),
                  child: Text(
                    item.unitRate > 0 ? '₹${item.unitRate.toStringAsFixed(2)}' : '—',
                    textAlign: TextAlign.end,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: isDark ? Colors.white : const Color(0xFF111827),
                    ),
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
                      onPressed: () => _viewItemDetails(context, item),
                    ),
                    if (canManage) ...[
                      const SizedBox(width: 4),
                      _buildSubtleActionButton(
                        icon: Icons.edit_outlined,
                        tooltip: 'Edit Item',
                        color: const Color(0xFF059669),
                        hoverColor: const Color(0xFF059669).withOpacity(0.12),
                        onPressed: () => context.push('/masters/items/edit/${item.itemId}'),
                      ),
                      const SizedBox(width: 4),
                      _buildSubtleActionButton(
                        icon: Icons.delete_outline_rounded,
                        tooltip: 'Delete Item',
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

  void _viewItemDetails(BuildContext context, ItemModel item) {
    showDialog(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFFF59E0B).withOpacity(0.15),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.inventory_2_rounded, color: Color(0xFFF59E0B), size: 22),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                item.itemDescription.isNotEmpty ? item.itemDescription : item.itemNo,
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _detailRow('Part / Item No.', item.itemNo),
              _detailRow('Description', item.itemDescription.isNotEmpty ? item.itemDescription : '—'),
              _detailRow('Category', item.category),
              if (item.underGroup != null && item.underGroup!.isNotEmpty)
                _detailRow('Under Group', item.underGroup!),
              _detailRow('Stock Unit', item.stockUnit),
              _detailRow('Unit Rate', item.unitRate > 0 ? '₹${item.unitRate.toStringAsFixed(2)}' : 'Not configured'),
              _detailRow('Finished Item?', item.isFinishedItem ? 'Yes' : 'No'),
              if (item.drawingNo != null && item.drawingNo!.isNotEmpty)
                _detailRow('Drawing No.', item.drawingNo!),
              if (item.materialSpecification != null && item.materialSpecification!.isNotEmpty)
                _detailRow('Material Spec', item.materialSpecification!),
              if (item.storeLocation != null && item.storeLocation!.isNotEmpty)
                _detailRow('Store Location', item.storeLocation!),
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

  Widget _detailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(fontSize: 11.5, color: Colors.grey, fontWeight: FontWeight.w600)),
          const SizedBox(height: 2),
          Text(value, style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }

  Future<void> _confirmDelete(BuildContext context, ItemModel item, String companyId) async {
    final repo = ref.read(itemRepositoryProvider);
    final isReferenced = await repo.isItemReferenced(companyId, item.itemId, item.itemNo);
    if (!mounted) return;

    if (isReferenced) {
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.warning_amber_rounded, color: AppColors.warning),
              SizedBox(width: 8),
              Text('Cannot Delete Item'),
            ],
          ),
          content: Text(
            'The item "${item.itemNo}" (${item.itemDescription}) is linked to existing transactions (purchase, sale, inward/outward, or production records). To preserve historical records and accounting integrity, this item cannot be deleted.',
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
        title: const Text('Delete Item'),
        content: Text('Are you sure you want to permanently delete item "${item.itemNo}"?'),
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
        await repo.deleteItem(companyId, item.itemId);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Item deleted successfully'),
              backgroundColor: AppColors.success,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error deleting item: $e')),
          );
        }
      }
    }
  }
}
