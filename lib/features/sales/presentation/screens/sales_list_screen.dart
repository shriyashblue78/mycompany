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
import '../../domain/models/sale_model.dart';
import '../providers/sales_provider.dart';
import 'sale_detail_view_screen.dart';

final salesApprovalFilterProvider = StateProvider<String>((ref) => 'All');

class SalesListScreen extends ConsumerStatefulWidget {
  const SalesListScreen({super.key});

  @override
  ConsumerState<SalesListScreen> createState() => _SalesListScreenState();
}

class _SalesListScreenState extends ConsumerState<SalesListScreen> {
  @override
  Widget build(BuildContext context) {
    final salesAsync = ref.watch(filteredSalesProvider);
    final stats = ref.watch(salesStatsProvider);
    final authState = ref.watch(authProvider);
    final theme = Theme.of(context);
    final approvalFilter = ref.watch(salesApprovalFilterProvider);

    final role = authState.selectedRole ?? 'Employee';
    final hasEditAccess = role == 'Owner' || role == 'Accountant';
    final isOwner = role == 'Owner';

    final isMobile = ResponsiveLayout.isMobile(context);

    return salesAsync.when(
      data: (allSales) {
        final sales = allSales.where((s) {
          if (approvalFilter == 'Pending Approval') {
            return s.approvalStatus == 'Pending Approval';
          }
          if (approvalFilter == 'Approved') {
            return s.approvalStatus == 'Approved';
          }
          return true;
        }).toList();

        if (isMobile) {
          return Scaffold(
            appBar: AppBar(
              title: const Text('Sales', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17)),
              elevation: 0,
              backgroundColor: theme.colorScheme.surface,
              iconTheme: IconThemeData(color: theme.colorScheme.onSurface),
              actions: [
                if (hasEditAccess)
                  IconButton(
                    onPressed: () => context.push('/sales/add'),
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
                    onChanged: (val) => ref.read(salesSearchQueryProvider.notifier).state = val,
                    decoration: InputDecoration(
                      hintText: 'Search sales...',
                      prefixIcon: const Icon(Icons.search_rounded, size: 20),
                      suffixIcon: ref.watch(salesSearchQueryProvider).isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear_rounded, size: 18),
                              onPressed: () => ref.read(salesSearchQueryProvider.notifier).state = '',
                            )
                          : null,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      isDense: true,
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                // Approval Filter Chips
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
                      MobileStatCard(label: "Today", value: '₹${stats.todaySum.toStringAsFixed(0)}', icon: Icons.today_rounded, color: Colors.amber),
                      MobileStatCard(label: "This Month", value: '₹${stats.monthSum.toStringAsFixed(0)}', icon: Icons.calendar_month_rounded, color: Colors.blue),
                      MobileStatCard(label: "Today's Count", value: '${stats.todayCount}', icon: Icons.receipt_rounded, color: Colors.teal),
                      MobileStatCard(label: "Total Revenue", value: '₹${stats.totalSum.toStringAsFixed(0)}', icon: Icons.monetization_on_rounded, color: Colors.green),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                Expanded(
                  child: sales.isEmpty
                      ? MobileEmptyState(
                          icon: Icons.sell_outlined,
                          title: 'No Sales Found',
                          subtitle: 'Track customer orders, quantities, and revenue.',
                          ctaLabel: hasEditAccess ? 'Log Sale' : null,
                          onCta: hasEditAccess ? () => context.push('/sales/add') : null,
                        )
                      : ListView.separated(
                          padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
                          itemCount: sales.length,
                          separatorBuilder: (_, __) => const SizedBox(height: 10),
                          itemBuilder: (_, i) {
                            final s = sales[i];
                            final date = '${s.saleDate.day}/${s.saleDate.month}/${s.saleDate.year}';
                            final isPendingApproval = s.approvalStatus == 'Pending Approval';

                            final invStr = s.invoiceNumber != null && s.invoiceNumber!.isNotEmpty ? ' · Inv: ${s.invoiceNumber}' : '';
                            final itemDetails = [
                              if (s.itemNumber.isNotEmpty) 'Item #: ${s.itemNumber}',
                              'Item: ${s.itemName}',
                              if (s.hsnCode.isNotEmpty) 'HSN: ${s.hsnCode}',
                            ].join(' · ');

                            return MobileListTile(
                              title: '${s.saleNumber}$invStr ${isPendingApproval ? "(Pending Approval)" : ""}',
                              subtitle: 'Customer: ${s.customerName}\n$itemDetails',
                              meta: '$date · ₹${s.totalAmount.toStringAsFixed(2)}',
                              leadingIcon: Icons.sell_rounded,
                              leadingColor: isPendingApproval ? Colors.amber : Colors.green,
                              statusLabel: isPendingApproval ? 'Pending Approval' : s.status,
                              onTap: () => context.push('/sales/view/${s.saleId}'),
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  IconButton(
                                    icon: const Icon(Icons.remove_red_eye_rounded, size: 18, color: Colors.teal),
                                    tooltip: 'View Document',
                                    onPressed: () => context.push('/sales/view/${s.saleId}'),
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.print_rounded, size: 18, color: Colors.purple),
                                    tooltip: 'Print A4 PDF',
                                    onPressed: () => SaleDetailViewScreen.generateAndDownloadPdf(context, s, authState.selectedCompany ?? 'Apex Industries'),
                                  ),
                                  if (isOwner && isPendingApproval)
                                    IconButton(
                                      icon: const Icon(Icons.check_circle_rounded, color: Colors.green),
                                      tooltip: 'Approve Sale',
                                      onPressed: () => _approveSale(s, authState.user?.companyId ?? '', authState.user?.uid ?? '', authState.user?.name ?? ''),
                                    ),
                                  if (hasEditAccess)
                                    GestureDetector(
                                      onTap: () => context.push('/sales/edit/${s.saleId}'),
                                      child: const Icon(Icons.edit_rounded, size: 18, color: Colors.blue),
                                    ),
                                  if (isOwner) ...[
                                    const SizedBox(width: 8),
                                    GestureDetector(
                                      onTap: () => _confirmDelete(context, s, authState.user?.companyId ?? ''),
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
            title: const Text('Sales Directory'),
            elevation: 0,
            backgroundColor: theme.colorScheme.surface,
            iconTheme: IconThemeData(color: theme.colorScheme.onSurface),
            actions: [
              if (hasEditAccess)
                Padding(
                  padding: const EdgeInsets.only(right: AppSizes.p16),
                  child: ElevatedButton.icon(
                    onPressed: () => context.push('/sales/add'),
                    icon: const Icon(Icons.add_rounded),
                    label: const Text('Log Sale'),
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
                          'Sales Analytics Overview',
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
                              'All Sales',
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
                        sales.isEmpty
                            ? EmptyStateWidget(
                                icon: Icons.sell_outlined,
                                title: 'No Sales Records',
                                description: 'Track customer orders, quantities sold, unit prices, total invoice amounts, and delivery details.',
                                ctaLabel: hasEditAccess ? 'Log Sale' : null,
                                onCtaPressed: hasEditAccess ? () => context.push('/sales/add') : null,
                              )
                            : _buildSalesList(sales, hasEditAccess, isOwner, authState.user?.companyId ?? '', authState.user?.uid ?? '', authState.user?.name ?? '', theme, authState.selectedCompany ?? 'Apex Industries'),
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
          ref.read(salesApprovalFilterProvider.notifier).state = label;
        }
      },
    );
  }

  Widget _buildStatsGrid(BuildContext context, SalesStats stats) {
    final cards = [
      _StatItem('Today\'s Sales', '₹${stats.todaySum.toStringAsFixed(2)}', '${stats.todayCount} record(s)', Icons.today_rounded, Colors.teal),
      _StatItem('This Month Sales', '₹${stats.monthSum.toStringAsFixed(2)}', '${stats.monthCount} record(s)', Icons.calendar_month_rounded, Colors.blue),
      _StatItem('Pending Sales', '₹${stats.pendingSum.toStringAsFixed(2)}', '${stats.pendingCount} pending', Icons.hourglass_empty_rounded, Colors.amber),
      _StatItem('Total Revenue', '₹${stats.totalSum.toStringAsFixed(2)}', 'All recorded sales', Icons.monetization_on_rounded, Colors.green),
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
          onChanged: (val) => ref.read(salesSearchQueryProvider.notifier).state = val,
          decoration: InputDecoration(
            hintText: 'Search by Customer Name or Item Name...',
            prefixIcon: const Icon(Icons.search_rounded),
            suffixIcon: ref.watch(salesSearchQueryProvider).isNotEmpty
                ? IconButton(
                    icon: const Icon(Icons.clear_rounded),
                    onPressed: () => ref.read(salesSearchQueryProvider.notifier).state = '',
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

  Widget _buildSalesList(List<SaleModel> sales, bool hasEditAccess, bool isOwner, String companyId, String userUid, String userName, ThemeData theme, String companyName) {
    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: sales.length,
      separatorBuilder: (_, __) => const SizedBox(height: AppSizes.p12),
      itemBuilder: (context, index) {
        final sale = sales[index];
        final isPendingApproval = sale.approvalStatus == 'Pending Approval';
        return Card(
          key: ValueKey(sale.saleId),
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
                        Text(sale.saleNumber, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                        if (sale.invoiceNumber != null && sale.invoiceNumber!.isNotEmpty) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: theme.colorScheme.primaryContainer,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              sale.invoiceNumber!,
                              style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: theme.colorScheme.onPrimaryContainer),
                            ),
                          ),
                        ],
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
                        IconButton(
                          icon: const Icon(Icons.remove_red_eye_rounded, color: Colors.teal),
                          tooltip: 'View Document',
                          onPressed: () => context.push('/sales/view/${sale.saleId}'),
                        ),
                        IconButton(
                          icon: const Icon(Icons.print_rounded, color: Colors.purple),
                          tooltip: 'Print A4 PDF',
                          onPressed: () => SaleDetailViewScreen.generateAndDownloadPdf(context, sale, companyName),
                        ),
                        if (isOwner && isPendingApproval)
                          ElevatedButton.icon(
                            onPressed: () => _approveSale(sale, companyId, userUid, userName),
                            icon: const Icon(Icons.check_rounded, size: 16, color: Colors.white),
                            label: const Text('Approve', style: TextStyle(color: Colors.white)),
                            style: ElevatedButton.styleFrom(backgroundColor: Colors.green, padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8)),
                          ),
                        if (hasEditAccess) ...[
                          const SizedBox(width: 8),
                          IconButton(
                            icon: const Icon(Icons.edit_rounded, color: Colors.blue),
                            onPressed: () => context.push('/sales/edit/${sale.saleId}'),
                          ),
                        ],
                        if (isOwner)
                          IconButton(
                            icon: const Icon(Icons.delete_rounded, color: AppColors.error),
                            onPressed: () => _confirmDelete(context, sale, companyId),
                          ),
                      ],
                    ),
                  ],
                ),
                const Divider(),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Customer: ${sale.customerName}', style: const TextStyle(fontWeight: FontWeight.w500)),
                    Text('Total: ₹${sale.totalAmount.toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.green)),
                  ],
                ),
                const SizedBox(height: 4),
                Text([
                  if (sale.itemNumber.isNotEmpty) 'Item #: ${sale.itemNumber}',
                  'Item: ${sale.itemName} (${sale.quantity} ${sale.unit})',
                  if (sale.hsnCode.isNotEmpty) 'HSN: ${sale.hsnCode}',
                ].join(' · ')),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _approveSale(SaleModel sale, String companyId, String userUid, String userName) async {
    try {
      final saleRepo = ref.read(saleRepositoryProvider);
      final approvedSale = sale.copyWith(
        approvalStatus: 'Approved',
        lastModifiedByUid: userUid,
        lastModifiedByName: userName,
        lastModifiedByRole: 'Owner',
        updatedAt: DateTime.now(),
      );
      await saleRepo.updateSale(companyId, approvedSale);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Sale ${sale.saleNumber} approved!')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error approving sale: $e')),
        );
      }
    }
  }

  Future<void> _confirmDelete(BuildContext context, SaleModel sale, String companyId) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete Sale Record'),
        content: Text('Are you sure you want to delete sale ${sale.saleNumber}?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(dialogContext, true), child: const Text('Delete', style: TextStyle(color: AppColors.error))),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await ref.read(saleRepositoryProvider).deleteSale(companyId, sale.saleId);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Sale record deleted successfully.')),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error deleting sale: $e')),
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
