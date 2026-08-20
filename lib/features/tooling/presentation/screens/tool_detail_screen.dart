import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_sizes.dart';
import '../../../../core/widgets/responsive_widgets.dart';
import '../../../../core/widgets/polish_widgets.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../domain/models/tool_model.dart';
import '../providers/tool_provider.dart';

class ToolDetailScreen extends ConsumerStatefulWidget {
  final String toolId;

  const ToolDetailScreen({
    super.key,
    required this.toolId,
  });

  @override
  ConsumerState<ToolDetailScreen> createState() => _ToolDetailScreenState();
}

class _ToolDetailScreenState extends ConsumerState<ToolDetailScreen> {
  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);
    final role = authState.selectedRole ?? 'Employee';
    final hasWriteAccess = role == 'Owner' || role == 'HR' || role == 'Supervisor';
    final hasDeleteAccess = role == 'Owner';
    final companyId = authState.user?.companyId ?? '';

    final theme = Theme.of(context);
    final toolAsync = ref.watch(toolDetailsStreamProvider(widget.toolId));

    return ResponsiveScaffold(
      appBar: AppBar(
        title: const Text('Tool Details'),
        elevation: 0,
        backgroundColor: theme.colorScheme.surface,
        iconTheme: IconThemeData(color: theme.colorScheme.onSurface),
        actions: [
          if (hasWriteAccess)
            toolAsync.maybeWhen(
              data: (tool) => tool == null
                  ? const SizedBox.shrink()
                  : IconButton(
                      onPressed: () => context.push('/tooling/${tool.toolId}/edit', extra: tool),
                      icon: const Icon(Icons.edit_rounded),
                    ),
              orElse: () => const SizedBox.shrink(),
            ),
        ],
      ),
      body: SafeArea(
        child: toolAsync.when(
          data: (tool) {
            if (tool == null) {
              return const Center(child: Text('Tool record not found.'));
            }
            return SingleChildScrollView(
              padding: const EdgeInsets.all(AppSizes.p24),
              child: Center(
                child: Container(
                  constraints: const BoxConstraints(maxWidth: AppSizes.maxContentWidth - 300),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildHeaderSection(tool, theme),
                      const SizedBox(height: AppSizes.p24),
                      _buildDetailCard(tool, theme),
                      const SizedBox(height: AppSizes.p32),
                      if (hasWriteAccess)
                        Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            ElevatedButton.icon(
                              onPressed: () => context.push('/tooling/${tool.toolId}/edit', extra: tool),
                              icon: const Icon(Icons.edit_rounded),
                              label: const Text('Edit Tool'),
                              style: ElevatedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                              ),
                            ),
                            if (hasDeleteAccess) ...[
                              const SizedBox(width: AppSizes.p16),
                              OutlinedButton.icon(
                                onPressed: () => _confirmDelete(context, tool, companyId),
                                icon: const Icon(Icons.delete_rounded, color: AppColors.error),
                                label: const Text('Delete Tool', style: TextStyle(color: AppColors.error)),
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

  Widget _buildHeaderSection(ToolModel tool, ThemeData theme) {
    Color statusColor;
    switch (tool.status) {
      case 'Active':
        statusColor = AppColors.success;
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
                    tool.toolName,
                    style: theme.textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    tool.toolCode,
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
                tool.status,
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

  Widget _buildDetailCard(ToolModel tool, ThemeData theme) {
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
            _buildDetailRow('Tool Type', tool.toolType.isNotEmpty ? tool.toolType : '—', Icons.category_outlined, theme),
            const Divider(height: 32),
            _buildDetailRow('Location', tool.location.isNotEmpty ? tool.location : '—', Icons.location_on_outlined, theme),
            const Divider(height: 32),
            _buildDetailRow('Description', tool.description.isNotEmpty ? tool.description : 'No description provided.', Icons.description_outlined, theme),
            const Divider(height: 32),
            _buildDetailRow('Created Date', formatDate(tool.createdAt), Icons.calendar_today_rounded, theme),
            const Divider(height: 32),
            _buildDetailRow('Last Updated', formatDate(tool.updatedAt), Icons.update_rounded, theme),
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

  void _confirmDelete(BuildContext context, ToolModel tool, String companyId) async {
    final confirm = await showDeleteConfirmationDialog(
      context: context,
      recordName: tool.toolName,
    );
    if (confirm && mounted) {
      try {
        await ref.read(toolRepositoryProvider).deleteTool(companyId, tool.toolId);
        if (mounted) {
          showFeedbackSnackBar(
            context: context,
            message: 'Tool "${tool.toolName}" deleted successfully.',
          );
          context.pop(); // Pop back to the list screen
        }
      } catch (e) {
        if (mounted) {
          showFeedbackSnackBar(
            context: context,
            message: 'Error deleting tool: $e',
            isError: true,
          );
        }
      }
    }
  }
}
