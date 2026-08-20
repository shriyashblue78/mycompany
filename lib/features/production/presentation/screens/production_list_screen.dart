import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_sizes.dart';
import '../../../../core/widgets/responsive_layout.dart';
import '../../../../core/widgets/erp_drawer.dart';
import '../../../../core/widgets/mobile_widgets.dart';
import '../../../../core/widgets/responsive_widgets.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../employee/domain/models/employee_model.dart';
import '../../../../core/widgets/polish_widgets.dart';
import '../../domain/models/production_model.dart';
import '../providers/production_provider.dart';

class ProductionListScreen extends ConsumerWidget {
  const ProductionListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authProvider);
    final productionsAsync = ref.watch(filteredProductionsProvider);
    final statsAsync = ref.watch(productionStatsProvider);
    final employeesAsync = ref.watch(productionEmployeesProvider);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final role = authState.selectedRole ?? 'Employee';
    final isOwnerOrSupervisor = role == 'Owner' || role == 'Supervisor';
    final isOwner = role == 'Owner';
    final companyName = authState.selectedCompany ?? 'Apex Industries';

    return ResponsiveScaffold(
      appBar: AppBar(
        title: const Text('Production Ledger'),
        elevation: 0,
        backgroundColor: theme.colorScheme.surface,
        iconTheme: IconThemeData(color: theme.colorScheme.onSurface),
      ),
      drawer: const ERPDrawer(),
      floatingActionButton: isOwnerOrSupervisor
          ? FloatingActionButton(
              onPressed: () => context.push('/production/create'),
              tooltip: 'Add Production',
              backgroundColor: theme.colorScheme.primary,
              child: const Icon(Icons.add_rounded, color: Colors.white),
            )
          : null,
      body: SafeArea(
        child: Column(
          children: [
            // Stats Panel
            statsAsync.when(
              loading: () => const Padding(
                padding: EdgeInsets.all(AppSizes.p16),
                child: Center(child: CircularProgressIndicator()),
              ),
              error: (err, stack) => Padding(
                padding: const EdgeInsets.all(AppSizes.p16),
                child: Text('Error loading stats: $err', style: const TextStyle(color: Colors.red)),
              ),
              data: (stats) => _buildStatsRow(context, stats),
            ),

            // Search input by product name only
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSizes.p16, vertical: AppSizes.p8),
              child: Container(
                constraints: const BoxConstraints(maxWidth: AppSizes.maxContentWidth),
                child: TextField(
                  decoration: InputDecoration(
                    hintText: 'Search by product name...',
                    prefixIcon: const Icon(Icons.search_rounded),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(AppSizes.inputRadius),
                    ),
                    contentPadding: const EdgeInsets.symmetric(horizontal: AppSizes.p16),
                  ),
                  onChanged: (val) {
                    ref.read(productionSearchQueryProvider.notifier).state = val;
                  },
                ),
              ),
            ),

            // Production List Results
            Expanded(
              child: productionsAsync.when(
                loading: () => const CardListSkeleton(),
                error: (err, stack) => Center(child: Text('Error loading production logs: $err')),
                data: (productions) {
                  if (productions.isEmpty) {
                    return EmptyStateWidget(
                      icon: Icons.precision_manufacturing_outlined,
                      title: 'No Production Batches',
                      description: 'Track ongoing factory jobs, delegated staff members, target vs completed quantities, and status updates here.',
                      ctaLabel: isOwnerOrSupervisor ? 'Add Production' : null,
                      onCtaPressed: isOwnerOrSupervisor ? () => context.push('/production/create') : null,
                    );
                  }

                  return employeesAsync.when(
                    loading: () => const Center(child: CircularProgressIndicator()),
                    error: (err, stack) => Center(child: Text('Error loading staff directory: $err')),
                    data: (employees) {
                      final isMobile = ResponsiveLayout.isMobile(context);
                      final isTablet = ResponsiveLayout.isTablet(context);
                      final columns = isMobile ? 1 : (isTablet ? 2 : 3);

                      if (isMobile) {
                        return ListView.separated(
                          padding: const EdgeInsets.fromLTRB(16, 4, 16, 80),
                          itemCount: productions.length,
                          separatorBuilder: (_, __) => const SizedBox(height: 10),
                          itemBuilder: (ctx, i) {
                            final prod = productions[i];
                            final assignedEmp = employees.where((e) => prod.assignedEmployees.contains(e.employeeId)).toList();
                            final assignedNames = assignedEmp.isNotEmpty
                                ? assignedEmp.map((e) => e.name).join(', ')
                                : 'Unassigned';
                            return MobileListTile(
                              title: prod.productName,
                              subtitle: assignedNames,
                              meta: '${prod.completedQuantity}/${prod.quantity} units',
                              leadingIcon: Icons.precision_manufacturing_rounded,
                              leadingColor: Colors.purple,
                              statusLabel: prod.status,
                              onTap: () => context.push('/production/${prod.productionId}'),
                            );
                          },
                        );
                      }

                      return GridView.builder(
                        padding: const EdgeInsets.all(AppSizes.p16),
                        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: columns,
                          crossAxisSpacing: AppSizes.p16,
                          mainAxisSpacing: AppSizes.p16,
                          mainAxisExtent: 220,
                        ),
                        itemCount: productions.length,
                        itemBuilder: (context, index) {
                          final prod = productions[index];
                          return _buildProductionCard(context, ref, prod, employees, isOwner, isOwnerOrSupervisor);
                        },
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatsRow(BuildContext context, ProductionStats stats) {
    final isMobile = ResponsiveLayout.isMobile(context);

    if (isMobile) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(16, 10, 0, 0),
        child: MobileStatRow(
          cards: [
            MobileStatCard(label: "Today's Target", value: '${stats.todayQuantity}', icon: Icons.today_rounded, color: Colors.blue),
            MobileStatCard(label: 'Running', value: '${stats.runningCount}', icon: Icons.trending_up_rounded, color: Colors.orange),
            MobileStatCard(label: 'Completed', value: '${stats.completedCount}', icon: Icons.check_circle_rounded, color: Colors.green),
            MobileStatCard(label: 'Rejected', value: '${stats.totalRejected}', icon: Icons.cancel_rounded, color: Colors.red),
          ],
        ),
      );
    }

    final columns = 4;
    return Padding(
      padding: const EdgeInsets.all(AppSizes.p16),
      child: Center(
        child: Container(
          constraints: const BoxConstraints(maxWidth: AppSizes.maxContentWidth),
          child: GridView(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: columns,
              crossAxisSpacing: AppSizes.p12,
              mainAxisSpacing: AppSizes.p12,
              mainAxisExtent: 72,
            ),
            children: [
              _buildMiniCard(
                label: "Today's Target",
                value: "${stats.todayQuantity} units",
                icon: Icons.today_rounded,
                color: Colors.blue,
              ),
              _buildMiniCard(
                label: "Running",
                value: "${stats.runningCount} runs",
                icon: Icons.trending_up_rounded,
                color: Colors.orange,
              ),
              _buildMiniCard(
                label: "Completed",
                value: "${stats.completedCount} runs",
                icon: Icons.check_circle_rounded,
                color: Colors.green,
              ),
              _buildMiniCard(
                label: "Rejected",
                value: "${stats.totalRejected} units",
                icon: Icons.cancel_rounded,
                color: Colors.red,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMiniCard({
    required String label,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    return Card(
      elevation: 1,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppSizes.p12),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(AppSizes.p8),
              decoration: BoxDecoration(
                color: color.withAlpha(26),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: color, size: 20),
            ),
            const SizedBox(width: AppSizes.p8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    label,
                    style: const TextStyle(fontSize: 11, color: Colors.grey, fontWeight: FontWeight.bold),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    value,
                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSizes.p32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.precision_manufacturing_outlined, size: 64, color: Colors.grey),
            const SizedBox(height: AppSizes.p16),
            const Text(
              'No Production Entries Found',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: AppSizes.p8),
            Text(
              'Search for another product name or add a new production record.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey[600]),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProductionCard(
    BuildContext context,
    WidgetRef ref,
    ProductionModel prod,
    List<EmployeeModel> employees,
    bool isOwner,
    bool isOwnerOrSupervisor,
  ) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    // Lookup supervisor name
    final supervisor = employees.firstWhere(
      (e) => e.employeeId == prod.assignedSupervisor,
      orElse: () => EmployeeModel(
        employeeId: prod.assignedSupervisor,
        uid: '',
        companyId: '',
        name: prod.assignedSupervisor.isNotEmpty ? prod.assignedSupervisor : 'Unassigned',
        email: '',
        phone: '',
        role: '',
        department: '',
        designation: '',
        status: '',
        joiningDate: DateTime.now(),
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      ),
    );

    final supervisorName = supervisor.name;

    // Status styling
    Color statusColor;
    switch (prod.status) {
      case 'Completed':
        statusColor = Colors.green;
        break;
      case 'In Progress':
        statusColor = Colors.orange;
        break;
      case 'Cancelled':
        statusColor = Colors.red;
        break;
      default:
        statusColor = Colors.blueGrey;
    }

    // Progress Bar computation
    final target = prod.quantity;
    final completed = prod.completedQuantity;
    final progress = target > 0 ? (completed / target).clamp(0.0, 1.0) : 0.0;

    // Date formatting
    final formattedDate = DateFormat('dd MMM yyyy').format(prod.productionDate);

    // Remaining Quantity display calculation
    final remaining = (target - completed - prod.rejectedQuantity).clamp(0, target);

    return Card(
      elevation: 2,
      margin: const EdgeInsets.only(bottom: AppSizes.p16),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: InkWell(
        onTap: () => context.push('/production/${prod.productionId}'),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(AppSizes.p16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header Row: Product Name, status
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Text(
                      prod.productName,
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: statusColor.withAlpha(26),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: statusColor.withAlpha(128)),
                    ),
                    child: Text(
                      prod.status,
                      style: TextStyle(
                        color: statusColor,
                        fontWeight: FontWeight.bold,
                        fontSize: 11,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),

              // Details grid/row
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Supervisor', style: TextStyle(fontSize: 11, color: Colors.grey)),
                      const SizedBox(height: 2),
                      Text(supervisorName, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
                    ],
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      const Text('Date', style: TextStyle(fontSize: 11, color: Colors.grey)),
                      const SizedBox(height: 2),
                      Text(formattedDate, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
                    ],
                  ),
                ],
              ),
              const Divider(height: 16),

              // Quantities row
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _buildQtyColumn('Target', prod.quantity, Colors.blue),
                  _buildQtyColumn('Completed', prod.completedQuantity, Colors.green),
                  _buildQtyColumn('Rejected', prod.rejectedQuantity, Colors.red),
                  _buildQtyColumn('Remaining', remaining, Colors.grey),
                ],
              ),
              const SizedBox(height: 12),

              // Progress bar
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: progress,
                      backgroundColor: isDark ? Colors.grey[800] : Colors.grey[200],
                      valueColor: AlwaysStoppedAnimation<Color>(progress >= 1.0 ? Colors.green : Colors.blue),
                      minHeight: 8,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        '${(progress * 100).toStringAsFixed(0)}% Progress',
                        style: const TextStyle(fontSize: 10, color: Colors.grey, fontWeight: FontWeight.w500),
                      ),
                      if (isOwner)
                        GestureDetector(
                          onTap: () => _confirmDelete(context, ref, prod),
                          child: const Icon(Icons.delete_outline, color: Colors.redAccent, size: 18),
                        ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildQtyColumn(String label, int value, Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 10, color: Colors.grey)),
        const SizedBox(height: 2),
        Text(
          value.toString(),
          style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: color),
        ),
      ],
    );
  }

  void _confirmDelete(BuildContext context, WidgetRef ref, ProductionModel prod) async {
    final confirm = await showDeleteConfirmationDialog(
      context: context,
      recordName: prod.productName,
    );
    if (confirm) {
      try {
        final authState = ref.read(authProvider);
        final companyId = authState.user?.companyId;
        if (companyId != null) {
          await ref.read(productionRepositoryProvider).deleteProduction(companyId, prod.productionId);
          if (context.mounted) {
            showFeedbackSnackBar(
              context: context,
              message: 'Production record for "${prod.productName}" deleted successfully.',
            );
          }
        }
      } catch (e) {
        if (context.mounted) {
          showFeedbackSnackBar(
            context: context,
            message: 'Error deleting record: $e',
            isError: true,
          );
        }
      }
    }
  }
}
