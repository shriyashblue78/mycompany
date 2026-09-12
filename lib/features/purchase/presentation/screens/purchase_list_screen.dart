import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_sizes.dart';
import '../../../../core/widgets/responsive_layout.dart';
import '../../../../core/widgets/erp_drawer.dart';
import '../../../../core/widgets/mobile_widgets.dart';
import '../../../../core/widgets/responsive_widgets.dart';
import '../../../../core/widgets/polish_widgets.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../domain/models/purchase_model.dart';
import '../providers/purchase_provider.dart';

final purchaseApprovalFilterProvider = StateProvider<String>((ref) => 'All');

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
    final approvalFilter = ref.watch(purchaseApprovalFilterProvider);

    final role = authState.selectedRole ?? 'Employee';
    final hasEditAccess = role == 'Owner' || role == 'Accountant';
    final isOwner = role == 'Owner';

    final isMobile = ResponsiveLayout.isMobile(context);

    return purchasesAsync.when(
      data: (allPurchases) {
        final purchases = allPurchases.where((p) {
          if (approvalFilter == 'Pending Approval') {
            return p.approvalStatus == 'Pending Approval';
          }
          if (approvalFilter == 'Approved') {
            return p.approvalStatus == 'Approved';
          }
          return true;
        }).toList();

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
                // Filter Chips
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Row(
                    children: [
                      _buildFilterChip('All', approvalFilter),
                      const SizedBox(width: 8),
                      _buildFilterChip('Pending Approval', approvalFilter),
                      const SizedBox(width: 8),
                      _buildFilterChip('Approved', approvalFilter),
                    ],
                  ),
                ),
                const SizedBox(height: 10),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: MobileStatRow(
                    cards: [
                      MobileStatCard(label: "Today", value: '\$${stats.todaySum.toStringAsFixed(0)}', icon: Icons.today_rounded, color: Colors.teal),
                      MobileStatCard(label: "This Month", value: '\$${stats.monthSum.toStringAsFixed(0)}', icon: Icons.calendar_month_rounded, color: Colors.blue),
                      MobileStatCard(label: "Today's Count", value: '${stats.todayCount}', icon: Icons.receipt_rounded, color: Colors.indigo),
                      MobileStatCard(label: "Total Spent", value: '\$${stats.totalSum.toStringAsFixed(0)}', icon: Icons.monetization_on_rounded, color: Colors.purple),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                Expanded(
                  child: purchases.isEmpty
                      ? MobileEmptyState(
                          icon: Icons.shopping_cart_outlined,
                          title: 'No Purchases Found',
                          subtitle: 'Track purchase orders, suppliers, and procurement expenses.',
                          ctaLabel: hasEditAccess ? 'Log Purchase' : null,
                          onCta: hasEditAccess ? () => context.push('/purchase/add') : null,
                        )
                      : ListView.separated(
                          padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
                          itemCount: purchases.length,
                          separatorBuilder: (_, __) => const SizedBox(height: 10),
                          itemBuilder: (_, i) {
                            final p = purchases[i];
                            final date = '${p.purchaseDate.day}/${p.purchaseDate.month}/${p.purchaseDate.year}';
                            final isPendingApproval = p.approvalStatus == 'Pending Approval';

                            return MobileListTile(
                              title: '${p.purchaseNumber} ${isPendingApproval ? "(Pending Approval)" : ""}',
                              subtitle: 'Supplier: ${p.supplierName} · Item: ${p.itemName}',
                              meta: '$date · \$${p.totalAmount.toStringAsFixed(2)}',
                              leadingIcon: Icons.shopping_cart_rounded,
                              leadingColor: isPendingApproval ? Colors.amber : Colors.teal,
                              statusLabel: isPendingApproval ? 'Pending Approval' : p.status,
                              onTap: () => context.push('/purchase/edit/${p.purchaseId}'),
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  if (isOwner && isPendingApproval)
                                    IconButton(
                                      icon: const Icon(Icons.check_circle_rounded, color: Colors.green),
                                      tooltip: 'Approve Purchase',
                                      onPressed: () => _approvePurchase(p, authState.user?.companyId ?? '', authState.user?.uid ?? '', authState.user?.name ?? ''),
                                    ),
                                  if (hasEditAccess)
                                    GestureDetector(
                                      onTap: () => context.push('/purchase/edit/${p.purchaseId}'),
                                      child: const Icon(Icons.edit_rounded, size: 18, color: Colors.blue),
                                    ),
                                  if (isOwner) ...[
                                    const SizedBox(width: 8),
                                    GestureDetector(
                                      onTap: () => _confirmDelete(context, p, authState.user?.companyId ?? ''),
                                      child: const Icon(Icons.delete_rounded, size: 18, color: AppColors.error),
                                    ),
                                  ],
                                ],
                              ),
                            );
                          },
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
                    label: const Text('Log Purchase'),
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
                          'Purchase Expenses Overview',
                          style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: AppSizes.p12),
                        _buildStatsGrid(context, stats),
                        const SizedBox(height: AppSizes.p24),
                        _buildSearchCard(theme),
                        const SizedBox(height: AppSizes.p20),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'All Purchases',
                              style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                            ),
                            Row(
                              children: [
                                _buildFilterChip('All', approvalFilter),
                                const SizedBox(width: 8),
                                _buildFilterChip('Pending Approval', approvalFilter),
                                const SizedBox(width: 8),
                                _buildFilterChip('Approved', approvalFilter),
                              ],
                            ),
                          ],
                        ),
                        const SizedBox(height: AppSizes.p12),
                        purchases.isEmpty
                            ? EmptyStateWidget(
                                icon: Icons.shopping_cart_outlined,
                                title: 'No Purchase Records',
                                description: 'Track purchase orders, suppliers, items, cost per unit, and procurement status.',
                                ctaLabel: hasEditAccess ? 'Log Purchase' : null,
                                onCtaPressed: hasEditAccess ? () => context.push('/purchase/add') : null,
                              )
                            : _buildPurchaseList(purchases, hasEditAccess, isOwner, authState.user?.companyId ?? '', authState.user?.uid ?? '', authState.user?.name ?? '', theme),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
      loading: () => const ResponsiveScaffold(body: Center(child: CircularProgressIndicator())),
      error: (err, stack) => ResponsiveScaffold(body: Center(child: Text('Error: $err'))),
    );
  }

  Widget _buildFilterChip(String label, String currentFilter) {
    final isSelected = currentFilter == label;
    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (selected) {
        if (selected) {
          ref.read(purchaseApprovalFilterProvider.notifier).state = label;
        }
      },
    );
  }

  Widget _buildStatsGrid(BuildContext context, PurchaseStats stats) {
    final cards = [
      _StatItem('Today\'s Purchases', '\$${stats.todaySum.toStringAsFixed(2)}', '${stats.todayCount} record(s)', Icons.today_rounded, Colors.teal),
      _StatItem('This Month Purchases', '\$${stats.monthSum.toStringAsFixed(2)}', '${stats.monthCount} record(s)', Icons.calendar_month_rounded, Colors.blue),
      _StatItem('Pending Orders', '\$${stats.pendingSum.toStringAsFixed(2)}', '${stats.pendingCount} pending', Icons.hourglass_empty_rounded, Colors.amber),
      _StatItem('Total Spent', '\$${stats.totalSum.toStringAsFixed(2)}', 'All recorded purchases', Icons.monetization_on_rounded, Colors.purple),
    ];

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 300,
        mainAxisExtent: 110,
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
      ),
      itemCount: cards.length,
      itemBuilder: (_, i) => cards[i],
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

  Widget _buildPurchaseList(List<PurchaseModel> purchases, bool hasEditAccess, bool isOwner, String companyId, String userUid, String userName, ThemeData theme) {
    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: purchases.length,
      separatorBuilder: (_, __) => const SizedBox(height: AppSizes.p12),
      itemBuilder: (context, index) {
        final p = purchases[index];
        final isPendingApproval = p.approvalStatus == 'Pending Approval';
        return Card(
          key: ValueKey(p.purchaseId),
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppSizes.cardRadius),
            side: BorderSide(color: isPendingApproval ? Colors.amber : theme.dividerColor.withAlpha(50), width: isPendingApproval ? 1.5 : 1),
          ),
          child: Padding(
            padding: const EdgeInsets.all(AppSizes.p16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Text(p.purchaseNumber, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                        const SizedBox(width: 8),
                        if (isPendingApproval)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.amber.shade100,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: Colors.amber.shade700),
                            ),
                            child: Text('Pending Approval', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.amber.shade900)),
                          ),
                      ],
                    ),
                    Row(
                      children: [
                        if (isOwner && isPendingApproval)
                          ElevatedButton.icon(
                            onPressed: () => _approvePurchase(p, companyId, userUid, userName),
                            icon: const Icon(Icons.check_rounded, size: 16, color: Colors.white),
                            label: const Text('Approve', style: TextStyle(color: Colors.white)),
                            style: ElevatedButton.styleFrom(backgroundColor: Colors.green, padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8)),
                          ),
                        if (hasEditAccess) ...[
                          const SizedBox(width: 8),
                          IconButton(
                            icon: const Icon(Icons.edit_rounded, color: Colors.blue),
                            onPressed: () => context.push('/purchase/edit/${p.purchaseId}'),
                          ),
                        ],
                        if (isOwner)
                          IconButton(
                            icon: const Icon(Icons.delete_rounded, color: AppColors.error),
                            onPressed: () => _confirmDelete(context, p, companyId),
                          ),
                      ],
                    ),
                  ],
                ),
                const Divider(),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Supplier: ${p.supplierName}', style: const TextStyle(fontWeight: FontWeight.w500)),
                    Text('Total: \$${p.totalAmount.toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.purple)),
                  ],
                ),
                const SizedBox(height: 4),
                Text('Item: ${p.itemName} (${p.quantity} ${p.unit})'),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _approvePurchase(PurchaseModel purchase, String companyId, String userUid, String userName) async {
    try {
      final purchaseRepo = ref.read(purchaseRepositoryProvider);
      final approvedPurchase = purchase.copyWith(
        approvalStatus: 'Approved',
        lastModifiedByUid: userUid,
        lastModifiedByName: userName,
        lastModifiedByRole: 'Owner',
        updatedAt: DateTime.now(),
      );
      await purchaseRepo.updatePurchase(companyId, approvedPurchase);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Purchase ${purchase.purchaseNumber} approved!')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error approving purchase: $e')),
        );
      }
    }
  }

  Future<void> _confirmDelete(BuildContext context, PurchaseModel purchase, String companyId) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete Purchase Record'),
        content: Text('Are you sure you want to delete purchase ${purchase.purchaseNumber}?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(dialogContext, true), child: const Text('Delete', style: TextStyle(color: AppColors.error))),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await ref.read(purchaseRepositoryProvider).deletePurchase(companyId, purchase.purchaseId);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Purchase record deleted successfully.')),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error deleting purchase: $e')),
          );
        }
      }
    }
  }
}

class _StatItem extends StatelessWidget {
  final String title;
  final String value;
  final String subtitle;
  final IconData icon;
  final Color color;

  const _StatItem(this.title, this.value, this.subtitle, this.icon, this.color);

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppSizes.cardRadius),
        side: BorderSide(color: Theme.of(context).dividerColor.withAlpha(50)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Row(
              children: [
                Icon(icon, color: color, size: 20),
                const SizedBox(width: 8),
                Text(title, style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 12)),
              ],
            ),
            const SizedBox(height: 4),
            Text(value, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            Text(subtitle, style: const TextStyle(fontSize: 11, color: Colors.grey)),
          ],
        ),
      ),
    );
  }
}
