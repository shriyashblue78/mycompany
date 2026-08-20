import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_sizes.dart';
import '../../../../core/widgets/responsive_layout.dart';
import '../../../../core/widgets/erp_drawer.dart';
import '../../../../core/widgets/mobile_widgets.dart';
import '../../../../core/widgets/responsive_widgets.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../../core/widgets/polish_widgets.dart';
import '../../domain/models/inventory_item_model.dart';
import '../providers/inventory_provider.dart';

class InventoryListScreen extends ConsumerStatefulWidget {
  const InventoryListScreen({super.key});

  @override
  ConsumerState<InventoryListScreen> createState() => _InventoryListScreenState();
}

class _InventoryListScreenState extends ConsumerState<InventoryListScreen> {
  @override
  Widget build(BuildContext context) {
    final inventoryAsync = ref.watch(filteredInventoryProvider);
    final authState = ref.watch(authProvider);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final role = authState.selectedRole ?? 'Employee';
    final hasEditAccess = role == 'Owner';

    return ResponsiveScaffold(
      appBar: AppBar(
        title: const Text('Inventory Directory'),
        elevation: 0,
        backgroundColor: theme.colorScheme.surface,
        iconTheme: IconThemeData(color: theme.colorScheme.onSurface),
        actions: [
          if (hasEditAccess)
            Padding(
              padding: const EdgeInsets.only(right: AppSizes.p16),
              child: ElevatedButton.icon(
                onPressed: () => context.push('/inventory/add'),
                icon: const Icon(Icons.add_rounded),
                label: const Text('Add Item'),
                style: ElevatedButton.styleFrom(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppSizes.buttonRadius),
                  ),
                ),
              ),
            ),
        ],
      ),
      drawer: const ERPDrawer(),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppSizes.p24),
          child: Center(
            child: Container(
              constraints: const BoxConstraints(maxWidth: AppSizes.maxContentWidth),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Search & Filters Row
                  _buildSearchAndFilters(theme),
                  const SizedBox(height: AppSizes.p20),

                  // Inventory Items List
                  Expanded(
                    child: inventoryAsync.when(
                      data: (items) {
                        if (items.isEmpty) {
                          return EmptyStateWidget(
                            icon: Icons.inventory_2_outlined,
                            title: 'No Inventory Items',
                            description: 'Register items, raw materials, or products here to track stock availability, categories, unit metrics, and supplier details.',
                            ctaLabel: hasEditAccess ? 'Add Inventory Item' : null,
                            onCtaPressed: hasEditAccess ? () => context.push('/inventory/add') : null,
                          );
                        }
                        return _buildItemsList(items, hasEditAccess, authState.user?.companyId ?? '', theme);
                      },
                      loading: () => const CardListSkeleton(),
                      error: (err, stack) => Center(
                        child: Text(
                          'Error loading inventory: $err',
                          style: TextStyle(color: theme.colorScheme.error),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSearchAndFilters(ThemeData theme) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppSizes.cardRadius),
        side: BorderSide(color: theme.dividerColor.withAlpha(50)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppSizes.p16),
        child: Column(
          children: [
            // Search Input
            TextField(
              onChanged: (val) => ref.read(inventorySearchQueryProvider.notifier).state = val,
              decoration: InputDecoration(
                hintText: 'Search by Item Name...',
                prefixIcon: const Icon(Icons.search_rounded),
                suffixIcon: ref.watch(inventorySearchQueryProvider).isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear_rounded),
                        onPressed: () => ref.read(inventorySearchQueryProvider.notifier).state = '',
                      )
                    : null,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppSizes.inputRadius),
                ),
              ),
            ),
            const SizedBox(height: AppSizes.p12),

            // Dropdown Filters
            _buildCategoryDropdown(theme),
          ],
        ),
      ),
    );
  }

  Widget _buildCategoryDropdown(ThemeData theme) {
    return DropdownButtonFormField<String>(
      value: ref.watch(inventoryCategoryFilterProvider),
      decoration: InputDecoration(
        labelText: 'Category',
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppSizes.inputRadius),
        ),
      ),
      items: [
        const DropdownMenuItem(value: null, child: Text('All Categories')),
        ...kInventoryCategories.map(
          (cat) => DropdownMenuItem(value: cat, child: Text(cat)),
        ),
      ],
      onChanged: (val) => ref.read(inventoryCategoryFilterProvider.notifier).state = val,
    );
  }



  Widget _buildEmptyState(ThemeData theme) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.inventory_2_outlined, size: 64, color: theme.colorScheme.onSurface.withAlpha(100)),
          const SizedBox(height: 16),
          Text(
            'No inventory items found.',
            style: theme.textTheme.titleMedium?.copyWith(
              color: theme.colorScheme.onSurface.withAlpha(150),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildItemCard(InventoryItemModel item, bool hasEditAccess, String companyId, ThemeData theme) {
    return Card(
      key: ValueKey(item.itemId),
      margin: EdgeInsets.zero,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppSizes.cardRadius),
        side: BorderSide(
          color: theme.dividerColor.withAlpha(50),
          width: 1,
        ),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        onTap: () => context.push('/inventory/details/${item.itemId}'),
        title: Row(
          children: [
            Expanded(
              child: Text(
                item.itemName,
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),

          ],
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primary.withAlpha(20),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    item.category,
                    style: TextStyle(color: theme.colorScheme.primary, fontSize: 10),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  'Unit: ${item.unit}',
                  style: theme.textTheme.bodySmall?.copyWith(fontSize: 10),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              'Stock: ${item.currentStock} ${item.unit} | Part No: ${item.partNumber}',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 12,
                color: theme.colorScheme.onSurface,
              ),
            ),
            if (item.supplierName != null && item.supplierName!.isNotEmpty) ...[
              const SizedBox(height: 2),
              Text(
                'Supplier: ${item.supplierName}',
                style: theme.textTheme.bodySmall?.copyWith(fontSize: 10),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ],
        ),
        trailing: hasEditAccess
            ? Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon: const Icon(Icons.edit_rounded, color: Colors.blue, size: 20),
                    onPressed: () => context.push('/inventory/edit/${item.itemId}'),
                  ),
                  IconButton(
                    icon: const Icon(Icons.delete_rounded, color: AppColors.error, size: 20),
                    onPressed: () => _confirmDelete(context, item, companyId),
                  ),
                ],
              )
            : const Icon(Icons.chevron_right_rounded),
      ),
    );
  }

  Widget _buildItemsList(List<InventoryItemModel> items, bool hasEditAccess, String companyId, ThemeData theme) {
    final isMobile = ResponsiveLayout.isMobile(context);
    final isTablet = ResponsiveLayout.isTablet(context);
    final columns = isMobile ? 1 : (isTablet ? 2 : 3);

    if (isMobile) {
      return ListView.separated(
        itemCount: items.length,
        separatorBuilder: (_, __) => const SizedBox(height: 10),
        itemBuilder: (_, i) {
          final item = items[i];
          return MobileListTile(
            title: item.itemName,
            subtitle: '${item.category} · ${item.unit} | Part No: ${item.partNumber}',
            meta: 'Stock: ${item.currentStock}',
            leadingIcon: Icons.inventory_2_rounded,
            leadingColor: Colors.teal,
            onTap: () => context.push('/inventory/details/${item.itemId}'),
            trailing: hasEditAccess
                ? Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      GestureDetector(
                        onTap: () => context.push('/inventory/edit/${item.itemId}'),
                        child: const Icon(Icons.edit_rounded, size: 18, color: Colors.blue),
                      ),
                      const SizedBox(width: 10),
                      GestureDetector(
                        onTap: () => _confirmDelete(context, item, companyId),
                        child: const Icon(Icons.delete_rounded, size: 18, color: AppColors.error),
                      ),
                    ],
                  )
                : null,
          );
        },
      );
    }

    return GridView.builder(
      shrinkWrap: true,
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: columns,
        crossAxisSpacing: AppSizes.p16,
        mainAxisSpacing: AppSizes.p16,
        mainAxisExtent: 144,
      ),
      itemCount: items.length,
      itemBuilder: (context, index) {
        final item = items[index];
        return _buildItemCard(item, hasEditAccess, companyId, theme);
      },
    );
  }

  void _confirmDelete(BuildContext context, InventoryItemModel item, String companyId) async {
    final confirm = await showDeleteConfirmationDialog(
      context: context,
      recordName: item.itemName,
    );
    if (confirm && mounted) {
      try {
        await ref.read(inventoryRepositoryProvider).deleteItem(companyId, item.itemId);
        if (mounted) {
          showFeedbackSnackBar(
            context: context,
            message: '"${item.itemName}" deleted successfully.',
          );
        }
      } catch (e) {
        if (mounted) {
          showFeedbackSnackBar(
            context: context,
            message: 'Error deleting item: $e',
            isError: true,
          );
        }
      }
    }
  }
}
