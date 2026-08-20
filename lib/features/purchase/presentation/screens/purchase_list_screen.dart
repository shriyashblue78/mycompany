import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_sizes.dart';
import '../../../../core/widgets/responsive_layout.dart';
import '../../../../core/widgets/erp_drawer.dart';
import '../../../../core/widgets/custom_card.dart';
import '../../../../core/widgets/mobile_widgets.dart';
import '../../../../core/widgets/responsive_widgets.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../../core/widgets/polish_widgets.dart';
import '../../domain/models/purchase_model.dart';
import '../providers/purchase_provider.dart';

class PurchaseListScreen extends ConsumerStatefulWidget {
  const PurchaseListScreen({super.key});

  @override
  ConsumerState<PurchaseListScreen> createState() => _PurchaseListScreenState();
}

class _PurchaseListScreenState extends ConsumerState<PurchaseListScreen> {
  @override
  Widget build(BuildContext context) {
    final purchasesAsync = ref.watch(filteredPurchasesProvider);
    final stats = ref.watch(purchaseStatsProvider);
    final authState = ref.watch(authProvider);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final role = authState.selectedRole ?? 'Employee';
    final hasEditAccess = role == 'Owner';

    final isMobile = ResponsiveLayout.isMobile(context);

    if (isMobile) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Purchases', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17)),
          elevation: 0,
          backgroundColor: theme.colorScheme.surface,
          iconTheme: IconThemeData(color: theme.colorScheme.onSurface),
          actions: [
            if (hasEditAccess)
              IconButton(
                onPressed: () => context.push('/purchase/add'),
                icon: Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primary,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.add_rounded, size: 20, color: Colors.white),
                ),
              ),
          ],
        ),
        drawer: const ERPDrawer(),
        body: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
              child: TextField(
                onChanged: (val) => ref.read(purchaseSearchQueryProvider.notifier).state = val,
                decoration: InputDecoration(
                  hintText: 'Search purchases...',
                  prefixIcon: const Icon(Icons.search_rounded, size: 20),
                  suffixIcon: ref.watch(purchaseSearchQueryProvider).isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear_rounded, size: 18),
                          onPressed: () => ref.read(purchaseSearchQueryProvider.notifier).state = '',
                        )
                      : null,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  isDense: true,
                ),
              ),
            ),
            const SizedBox(height: 10),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: MobileStatRow(
                cards: [
                  MobileStatCard(label: "Today", value: '\$${stats.todaySum.toStringAsFixed(0)}', icon: Icons.today_rounded, color: Colors.teal),
                  MobileStatCard(label: "This Month", value: '\$${stats.monthSum.toStringAsFixed(0)}', icon: Icons.calendar_month_rounded, color: Colors.blue),
                  MobileStatCard(label: "Pending", value: '${stats.pendingCount}', icon: Icons.hourglass_empty_rounded, color: Colors.amber),
                  MobileStatCard(label: "Total", value: '\$${stats.totalSum.toStringAsFixed(0)}', icon: Icons.monetization_on_rounded, color: Colors.purple),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: purchasesAsync.when(
                data: (purchases) {
                  if (purchases.isEmpty) {
                    return MobileEmptyState(
                      icon: Icons.shopping_cart_checkout_rounded,
                      title: 'No Purchases',
                      subtitle: 'Add incoming purchases to track procurement.',
                      ctaLabel: hasEditAccess ? 'Add Purchase' : null,
                      onCta: hasEditAccess ? () => context.push('/purchase/add') : null,
                    );
                  }
                  return ListView.separated(
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
                    itemCount: purchases.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 10),
                    itemBuilder: (_, i) {
                      final p = purchases[i];
                      final date = '${p.purchaseDate.day}/${p.purchaseDate.month}/${p.purchaseDate.year}';
                      return MobileListTile(
                        title: p.purchaseNumber,
                        subtitle: 'Supplier: ${p.supplierName}',
                        meta: '$date · \$${p.totalAmount.toStringAsFixed(2)}',
                        leadingIcon: Icons.receipt_long_rounded,
                        leadingColor: Colors.teal,
                        statusLabel: p.status,
                        onTap: () => context.push('/purchase/edit/${p.purchaseId}'),
                        trailing: hasEditAccess
                            ? Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  GestureDetector(
                                    onTap: () => context.push('/purchase/edit/${p.purchaseId}'),
                                    child: const Icon(Icons.edit_rounded, size: 18, color: Colors.blue),
                                  ),
                                  const SizedBox(width: 8),
                                  GestureDetector(
                                    onTap: () => _confirmDelete(context, p, authState.user?.companyId ?? ''),
                                    child: const Icon(Icons.delete_rounded, size: 18, color: AppColors.error),
                                  ),
                                ],
                              )
                            : null,
                      );
                    },
                  );
                },
                loading: () => const Padding(
                  padding: EdgeInsets.all(16),
                  child: MobileLoadingCard(),
                ),
                error: (err, _) => Center(child: Text('Error: $err')),
              ),
            ),
          ],
        ),
      );
    }

    return ResponsiveScaffold(
      appBar: AppBar(
        title: const Text('Purchase Directory'),
        elevation: 0,
        backgroundColor: theme.colorScheme.surface,
        iconTheme: IconThemeData(color: theme.colorScheme.onSurface),
        actions: [
          if (hasEditAccess)
            Padding(
              padding: const EdgeInsets.only(right: AppSizes.p16),
              child: ElevatedButton.icon(
                onPressed: () => context.push('/purchase/add'),
                icon: const Icon(Icons.add_rounded),
                label: const Text('Add Purchase'),
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
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(AppSizes.p24),
            child: Center(
              child: Container(
                constraints: const BoxConstraints(maxWidth: AppSizes.maxContentWidth),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Purchase Analytics Overview',
                      style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: AppSizes.p12),
                    _buildStatsGrid(context, stats),
                    const SizedBox(height: AppSizes.p24),
                    _buildSearchCard(theme),
                    const SizedBox(height: AppSizes.p20),
                    Text(
                      'All Purchases',
                      style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: AppSizes.p12),
                    purchasesAsync.when(
                      data: (purchases) {
                        if (purchases.isEmpty) {
                          return EmptyStateWidget(
                            icon: Icons.shopping_cart_checkout_rounded,
                            title: 'No Purchase Records',
                            description: 'Add incoming raw materials or items here to track procurement costs, supplier contact, quantities, and receipt status.',
                            ctaLabel: hasEditAccess ? 'Add Purchase' : null,
                            onCtaPressed: hasEditAccess ? () => context.push('/purchase/add') : null,
                          );
                        }
                        return _buildPurchasesList(purchases, hasEditAccess, authState.user?.companyId ?? '', theme);
                      },
                      loading: () => const CardListSkeleton(),
                      error: (err, stack) => Center(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 40.0),
                          child: Text(
                            'Error loading purchases: $err',
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
      ),
    );
  }

  Widget _buildStatsGrid(BuildContext context, PurchaseStats stats) {
    final columns = ResponsiveLayout.isMobile(context)
        ? 1
        : ResponsiveLayout.isTablet(context)
            ? 2
            : 4;

    final cards = [
      _StatItem(
        'Today\'s Purchases',
        '\$${stats.todaySum.toStringAsFixed(2)}',
        '${stats.todayCount} record(s)',
        Icons.today_rounded,
        Colors.teal,
      ),
      _StatItem(
        'This Month Purchases',
        '\$${stats.monthSum.toStringAsFixed(2)}',
        '${stats.monthCount} record(s)',
        Icons.calendar_month_rounded,
        Colors.blue,
      ),
      _StatItem(
        'Pending Purchases',
        '\$${stats.pendingSum.toStringAsFixed(2)}',
        '${stats.pendingCount} pending',
        Icons.hourglass_empty_rounded,
        Colors.amber,
      ),
      _StatItem(
        'Total Purchase Amount',
        '\$${stats.totalSum.toStringAsFixed(2)}',
        'Active amount',
        Icons.monetization_on_rounded,
        Colors.purple,
      ),
    ];

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: columns,
        crossAxisSpacing: AppSizes.p16,
        mainAxisSpacing: AppSizes.p16,
        mainAxisExtent: 96,
      ),
      itemCount: cards.length,
      itemBuilder: (context, index) {
        final card = cards[index];
        return CustomCard(
          title: card.value,
          subtitle: '${card.label}\n${card.description}',
          icon: card.icon,
          iconColor: card.color,
        );
      },
    );
  }

  Widget _buildSearchCard(ThemeData theme) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppSizes.cardRadius),
        side: BorderSide(color: theme.dividerColor.withAlpha(50)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppSizes.p16),
        child: TextField(
          onChanged: (val) => ref.read(purchaseSearchQueryProvider.notifier).state = val,
          decoration: InputDecoration(
            hintText: 'Search by Supplier Name or Item Name...',
            prefixIcon: const Icon(Icons.search_rounded),
            suffixIcon: ref.watch(purchaseSearchQueryProvider).isNotEmpty
                ? IconButton(
                    icon: const Icon(Icons.clear_rounded),
                    onPressed: () => ref.read(purchaseSearchQueryProvider.notifier).state = '',
                  )
                : null,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppSizes.inputRadius),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState(ThemeData theme) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 40.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.shopping_cart_checkout_rounded, size: 64, color: theme.colorScheme.onSurface.withAlpha(100)),
            const SizedBox(height: 16),
            Text(
              'No purchases found.',
              style: theme.textTheme.titleMedium?.copyWith(
                color: theme.colorScheme.onSurface.withAlpha(150),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPurchaseCard(PurchaseModel purchase, bool hasEditAccess, String companyId, ThemeData theme) {
    Color statusColor;
    switch (purchase.status) {
      case 'Received':
        statusColor = AppColors.success;
        break;
      case 'Cancelled':
        statusColor = AppColors.error;
        break;
      case 'Pending':
      default:
        statusColor = AppColors.warning;
        break;
    }

    final formattedDate = '${purchase.purchaseDate.day}/${purchase.purchaseDate.month}/${purchase.purchaseDate.year}';

    return Card(
      key: ValueKey(purchase.purchaseId),
      margin: EdgeInsets.zero,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppSizes.cardRadius),
        side: BorderSide(
          color: theme.dividerColor.withAlpha(50),
          width: 1,
        ),
      ),
      child: InkWell(
        onTap: () => context.push('/purchase/edit/${purchase.purchaseId}'),
        borderRadius: BorderRadius.circular(AppSizes.cardRadius),
        child: Padding(
          padding: const EdgeInsets.all(AppSizes.p16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            purchase.purchaseNumber,
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                          ),
                          if (purchase.invoiceNumber != null && purchase.invoiceNumber!.isNotEmpty) ...[
                            const SizedBox(width: 8),
                            Text(
                              '(Inv: ${purchase.invoiceNumber})',
                              style: TextStyle(color: theme.colorScheme.onSurface.withAlpha(150), fontSize: 13),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Date: $formattedDate',
                        style: theme.textTheme.bodySmall,
                      ),
                    ],
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: statusColor.withAlpha(30),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: statusColor, width: 0.5),
                    ),
                    child: Text(
                      purchase.status,
                      style: TextStyle(
                        color: statusColor,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
              const Divider(height: AppSizes.p20),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Supplier: ${purchase.supplierName}',
                          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (purchase.supplierPhone.isNotEmpty)
                          Text(
                            'Phone: ${purchase.supplierPhone}',
                            style: theme.textTheme.bodySmall,
                          ),
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        '${purchase.quantity} ${purchase.unit} x \$${purchase.pricePerUnit.toStringAsFixed(2)}',
                        style: theme.textTheme.bodyMedium,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '\$${purchase.totalAmount.toStringAsFixed(2)}',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppColors.primaryLight),
                      ),
                    ],
                  ),
                ],
              ),
              if (purchase.remarks.isNotEmpty) ...[
                const SizedBox(height: 10),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.onSurface.withAlpha(10),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    'Remarks: ${purchase.remarks}',
                    style: theme.textTheme.bodySmall?.copyWith(fontStyle: FontStyle.italic),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
              if (hasEditAccess) ...[
                const Divider(height: AppSizes.p20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton.icon(
                      onPressed: () => context.push('/purchase/edit/${purchase.purchaseId}'),
                      icon: const Icon(Icons.edit_rounded, size: 16, color: Colors.blue),
                      label: const Text('Edit', style: TextStyle(color: Colors.blue)),
                    ),
                    const SizedBox(width: AppSizes.p12),
                    TextButton.icon(
                      onPressed: () => _confirmDelete(context, purchase, companyId),
                      icon: const Icon(Icons.delete_rounded, size: 16, color: AppColors.error),
                      label: const Text('Delete', style: TextStyle(color: AppColors.error)),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPurchasesList(List<PurchaseModel> purchases, bool hasEditAccess, String companyId, ThemeData theme) {
    final isMobile = ResponsiveLayout.isMobile(context);
    final isTablet = ResponsiveLayout.isTablet(context);
    final columns = isMobile ? 1 : (isTablet ? 2 : 3);

    if (isMobile) {
      return ListView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: purchases.length,
        itemBuilder: (context, index) {
          final purchase = purchases[index];
          return Padding(
            padding: const EdgeInsets.only(bottom: AppSizes.p12),
            child: _buildPurchaseCard(purchase, hasEditAccess, companyId, theme),
          );
        },
      );
    }

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: columns,
        crossAxisSpacing: AppSizes.p16,
        mainAxisSpacing: AppSizes.p16,
        mainAxisExtent: hasEditAccess ? 260 : 210,
      ),
      itemCount: purchases.length,
      itemBuilder: (context, index) {
        final purchase = purchases[index];
        return _buildPurchaseCard(purchase, hasEditAccess, companyId, theme);
      },
    );
  }

  void _confirmDelete(BuildContext context, PurchaseModel purchase, String companyId) async {
    final confirm = await showDeleteConfirmationDialog(
      context: context,
      recordName: purchase.purchaseNumber,
    );
    if (confirm && mounted) {
      try {
        await ref.read(purchaseRepositoryProvider).deletePurchase(companyId, purchase.purchaseId);
        if (mounted) {
          showFeedbackSnackBar(
            context: context,
            message: 'Purchase "${purchase.purchaseNumber}" deleted successfully.',
          );
        }
      } catch (e) {
        if (mounted) {
          showFeedbackSnackBar(
            context: context,
            message: 'Error deleting purchase: $e',
            isError: true,
          );
        }
      }
    }
  }
}

class _StatItem {
  final String label;
  final String value;
  final String description;
  final IconData icon;
  final Color color;

  const _StatItem(this.label, this.value, this.description, this.icon, this.color);
}
