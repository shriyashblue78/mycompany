import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_sizes.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../domain/models/inventory_item_model.dart';
import '../providers/inventory_provider.dart';

class InventoryDetailScreen extends ConsumerStatefulWidget {
  final String itemId;
  const InventoryDetailScreen({super.key, required this.itemId});

  @override
  ConsumerState<InventoryDetailScreen> createState() => _InventoryDetailScreenState();
}

class _InventoryDetailScreenState extends ConsumerState<InventoryDetailScreen> {
  @override
  Widget build(BuildContext context) {
    final itemDetailsAsync = ref.watch(inventoryDetailsStreamProvider(widget.itemId));
    final authState = ref.watch(authProvider);
    final theme = Theme.of(context);

    final role = authState.selectedRole ?? 'Employee';
    final hasEditAccess = role == 'Owner';

    return Scaffold(
      appBar: AppBar(
        title: const Text('Inventory Item Details'),
        elevation: 0,
        backgroundColor: theme.colorScheme.surface,
        iconTheme: IconThemeData(color: theme.colorScheme.onSurface),
        actions: [
          if (hasEditAccess)
            itemDetailsAsync.maybeWhen(
              data: (item) {
                if (item == null) return const SizedBox.shrink();
                return Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.edit_rounded, color: Colors.blue),
                      onPressed: () => context.push('/inventory/edit/${item.itemId}'),
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete_rounded, color: AppColors.error),
                      onPressed: () => _confirmDelete(context, item, authState.user?.companyId ?? ''),
                    ),
                    const SizedBox(width: 8),
                  ],
                );
              },
              orElse: () => const SizedBox.shrink(),
            ),
        ],
      ),
      body: itemDetailsAsync.when(
        data: (item) {
          if (item == null) {
            return const Center(child: Text('Item not found.'));
          }
          return _buildDetailsBody(item, theme);
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, stack) => Center(
          child: Text(
            'Error loading details: $err',
            style: TextStyle(color: theme.colorScheme.error),
          ),
        ),
      ),
    );
  }

  Widget _buildDetailsBody(InventoryItemModel item, ThemeData theme) {
    final dateFormater = DateFormat('yyyy-MM-dd hh:mm a');

    return SafeArea(
      child: Center(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 700),
          padding: const EdgeInsets.all(AppSizes.p24),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Item Header
                Row(
                  children: [
                    CircleAvatar(
                      radius: 28,
                      backgroundColor: theme.colorScheme.primary.withAlpha(20),
                      child: Icon(
                        Icons.inventory_2_rounded,
                        color: theme.colorScheme.primary,
                        size: 28,
                      ),
                    ),
                    const SizedBox(width: AppSizes.p16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            item.itemName,
                            style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Category: ${item.category}',
                            style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.primary),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSizes.p24),

                // Grid Details Cards
                Card(
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppSizes.cardRadius),
                    side: BorderSide(color: theme.dividerColor.withAlpha(50)),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(AppSizes.p20),
                    child: Column(
                      children: [
                        _buildDetailRow('Date', DateFormat('yyyy-MM-dd').format(item.date), theme),
                        const Divider(),
                        _buildDetailRow('Document Number', item.documentNumber, theme),
                        const Divider(),
                        _buildDetailRow('Part Number', item.partNumber, theme),
                        const Divider(),
                        _buildDetailRow('Which Process?', item.process, theme),
                        const Divider(),
                        _buildDetailRow('With Material?', item.withMaterial ? 'Yes' : 'No', theme),
                        const Divider(),
                        _buildDetailRow('Current Stock', '${item.currentStock} ${item.unit}', theme, isValueBold: true),
                        const Divider(),
                        _buildDetailRow('Unit of Measurement', item.unit, theme),
                        const Divider(),
                        _buildDetailRow('Supplier Name', item.supplierName ?? 'N/A', theme),
                        const Divider(),
                        _buildDetailRow('Created At', dateFormater.format(item.createdAt), theme),
                        const Divider(),
                        _buildDetailRow('Last Updated', dateFormater.format(item.updatedAt), theme),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDetailRow(String label, String value, ThemeData theme, {bool isValueBold = false, Color? valueColor}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurface.withAlpha(150))),
          Text(
            value,
            style: theme.textTheme.bodyMedium?.copyWith(
              fontWeight: isValueBold ? FontWeight.bold : FontWeight.normal,
              color: valueColor ?? theme.colorScheme.onSurface,
            ),
          ),
        ],
      ),
    );
  }

  void _confirmDelete(BuildContext context, InventoryItemModel item, String companyId) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Delete Inventory Item'),
          content: Text('Are you sure you want to delete "${item.itemName}"? This action cannot be undone.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () async {
                Navigator.pop(context);
                try {
                  await ref.read(inventoryRepositoryProvider).deleteItem(companyId, item.itemId);
                  if (mounted) {
                    ScaffoldMessenger.of(this.context).showSnackBar(
                      SnackBar(content: Text('"${item.itemName}" deleted successfully.')),
                    );
                    context.pop(); // Go back to inventory list
                  }
                } catch (e) {
                  if (mounted) {
                    ScaffoldMessenger.of(this.context).showSnackBar(
                      SnackBar(content: Text('Error deleting item: $e')),
                    );
                  }
                }
              },
              child: const Text('Delete', style: TextStyle(color: AppColors.error)),
            ),
          ],
        );
      },
    );
  }
}
