import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_sizes.dart';
import '../../../../core/widgets/responsive_widgets.dart';
import '../../../../core/widgets/polish_widgets.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../domain/models/machine_model.dart';
import '../providers/machine_provider.dart';

class MachineDetailScreen extends ConsumerStatefulWidget {
  final String machineId;

  const MachineDetailScreen({
    super.key,
    required this.machineId,
  });

  @override
  ConsumerState<MachineDetailScreen> createState() => _MachineDetailScreenState();
}

class _MachineDetailScreenState extends ConsumerState<MachineDetailScreen> {
  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);
    final role = authState.selectedRole ?? 'Employee';
    final hasWriteAccess = role == 'Owner' || role == 'HR' || role == 'Supervisor';
    final hasDeleteAccess = role == 'Owner';
    final companyId = authState.user?.companyId ?? '';

    final theme = Theme.of(context);
    final machineAsync = ref.watch(machineDetailsStreamProvider(widget.machineId));

    return ResponsiveScaffold(
      appBar: AppBar(
        title: const Text('Machine Details'),
        elevation: 0,
        backgroundColor: theme.colorScheme.surface,
        iconTheme: IconThemeData(color: theme.colorScheme.onSurface),
        actions: [
          if (hasWriteAccess)
            machineAsync.maybeWhen(
              data: (machine) => machine == null
                  ? const SizedBox.shrink()
                  : IconButton(
                      onPressed: () => context.push('/machines/edit/${machine.machineId}', extra: machine),
                      icon: const Icon(Icons.edit_rounded),
                    ),
              orElse: () => const SizedBox.shrink(),
            ),
        ],
      ),
      body: SafeArea(
        child: machineAsync.when(
          data: (machine) {
            if (machine == null) {
              return const Center(child: Text('Machine record not found.'));
            }
            return SingleChildScrollView(
              padding: const EdgeInsets.all(AppSizes.p24),
              child: Center(
                child: Container(
                  constraints: const BoxConstraints(maxWidth: AppSizes.maxContentWidth - 300),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildHeaderSection(machine, theme),
                      const SizedBox(height: AppSizes.p24),
                      _buildDetailCard(machine, theme),
                      const SizedBox(height: AppSizes.p32),
                      if (hasWriteAccess)
                        Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            ElevatedButton.icon(
                              onPressed: () => context.push('/machines/edit/${machine.machineId}', extra: machine),
                              icon: const Icon(Icons.edit_rounded),
                              label: const Text('Edit Machine'),
                              style: ElevatedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                              ),
                            ),
                            if (hasDeleteAccess) ...[
                              const SizedBox(width: AppSizes.p16),
                              OutlinedButton.icon(
                                onPressed: () => _confirmDelete(context, machine, companyId),
                                icon: const Icon(Icons.delete_rounded, color: AppColors.error),
                                label: const Text('Delete Machine', style: TextStyle(color: AppColors.error)),
                                style: OutlinedButton.styleFrom(
                                  side: const BorderSide(color: AppColors.error),
                                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                                ),
                              ),
                            ],
                          ],
                        ),
                    ],
                  ),
                ),
              ),
            );
          },
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (err, _) => Center(child: Text('Error: $err')),
        ),
      ),
    );
  }

  Widget _buildHeaderSection(MachineModel machine, ThemeData theme) {
    Color statusColor;
    switch (machine.status) {
      case 'Active':
        statusColor = AppColors.success;
        break;
      case 'Under Maintenance':
        statusColor = AppColors.warning;
        break;
      case 'Inactive':
      default:
        statusColor = AppColors.error;
        break;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    machine.machineName,
                    style: theme.textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    machine.machineCode,
                    style: theme.textTheme.titleMedium?.copyWith(color: theme.colorScheme.primary, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              decoration: BoxDecoration(
                color: statusColor.withAlpha(30),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: statusColor, width: 0.5),
              ),
              child: Text(
                machine.status,
                style: TextStyle(
                  color: statusColor,
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildDetailCard(MachineModel machine, ThemeData theme) {
    String formatDate(DateTime dt) {
      return '${dt.day}/${dt.month}/${dt.year} ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
    }

    return Card(
      margin: EdgeInsets.zero,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppSizes.cardRadius),
        side: BorderSide(color: theme.dividerColor.withAlpha(45)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppSizes.p24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildDetailRow('Machine Type', machine.machineType.isNotEmpty ? machine.machineType : '—', Icons.category_outlined, theme),
            const Divider(height: 32),
            _buildDetailRow('Location', machine.location.isNotEmpty ? machine.location : '—', Icons.location_on_outlined, theme),
            const Divider(height: 32),
            _buildDetailRow('Description', machine.description.isNotEmpty ? machine.description : 'No description provided.', Icons.description_outlined, theme),
            const Divider(height: 32),
            _buildDetailRow('Created Date', formatDate(machine.createdAt), Icons.calendar_today_rounded, theme),
            const Divider(height: 32),
            _buildDetailRow('Last Updated', formatDate(machine.updatedAt), Icons.update_rounded, theme),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailRow(String label, String value, IconData icon, ThemeData theme) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 22, color: theme.colorScheme.primary.withAlpha(180)),
        const SizedBox(width: AppSizes.p16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(fontSize: 12, color: theme.textTheme.bodySmall?.color?.withAlpha(180)),
              ),
              const SizedBox(height: 4),
              Text(
                value,
                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500),
              ),
            ],
          ),
        ),
      ],
    );
  }

  void _confirmDelete(BuildContext context, MachineModel machine, String companyId) async {
    final confirm = await showDeleteConfirmationDialog(
      context: context,
      recordName: machine.machineName,
    );
    if (confirm && mounted) {
      try {
        await ref.read(machineRepositoryProvider).deleteMachine(companyId, machine.machineId);
        if (mounted) {
          showFeedbackSnackBar(
            context: context,
            message: 'Machine "${machine.machineName}" deleted successfully.',
          );
          context.pop(); // Pop back to the list screen
        }
      } catch (e) {
        if (mounted) {
          showFeedbackSnackBar(
            context: context,
            message: 'Error deleting machine: $e',
            isError: true,
          );
        }
      }
    }
  }
}
