import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_sizes.dart';
import '../../../../core/widgets/erp_drawer.dart';
import '../../../../core/widgets/responsive_layout.dart';
import '../../../../core/widgets/responsive_widgets.dart';
import '../../../../core/widgets/polish_widgets.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../domain/models/tool_model.dart';
import '../providers/tool_provider.dart';

class ToolListScreen extends ConsumerStatefulWidget {
  const ToolListScreen({super.key});

  @override
  ConsumerState<ToolListScreen> createState() => _ToolListScreenState();
}

class _ToolListScreenState extends ConsumerState<ToolListScreen> {
  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);
    final role = authState.selectedRole ?? 'Employee';
    final hasWriteAccess = role == 'Owner' || role == 'HR' || role == 'Supervisor';
    final hasDeleteAccess = role == 'Owner';

    final query = ref.watch(toolSearchQueryProvider);
    final statusFilter = ref.watch(toolStatusFilterProvider);
    final toolsAsync = ref.watch(filteredToolsProvider);

    final theme = Theme.of(context);
    final isMobile = ResponsiveLayout.isMobile(context);

    if (isMobile) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Tooling', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17)),
          elevation: 0,
          backgroundColor: theme.colorScheme.surface,
          iconTheme: IconThemeData(color: theme.colorScheme.onSurface),
          actions: [
            if (hasWriteAccess)
              IconButton(
                onPressed: () => context.push('/tooling/add'),
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
                onChanged: (val) => ref.read(toolSearchQueryProvider.notifier).state = val,
                decoration: InputDecoration(
                  hintText: 'Search tools...',
                  prefixIcon: const Icon(Icons.search_rounded, size: 20),
                  suffixIcon: query.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear_rounded, size: 18),
                          onPressed: () => ref.read(toolSearchQueryProvider.notifier).state = '',
                        )
                      : null,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  isDense: true,
                ),
              ),
            ),
            const SizedBox(height: 10),
            _buildStatusFilterRow(),
            const SizedBox(height: 10),
            Expanded(
              child: toolsAsync.when(
                data: (tools) {
                  if (tools.isEmpty) {
                    return _buildEmptyState(theme);
                  }
                  return ListView.separated(
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
                    itemCount: tools.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 12),
                    itemBuilder: (_, i) {
                      final tool = tools[i];
                      return _buildToolCard(tool, hasWriteAccess, hasDeleteAccess, authState.user?.companyId ?? '', theme);
                    },
                  );
                },
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (err, _) => Center(child: Text('Error: $err')),
              ),
            ),
          ],
        ),
      );
    }

    // Desktop layout
    return ResponsiveScaffold(
      appBar: AppBar(
        title: const Text('Tooling Directory'),
        elevation: 0,
        backgroundColor: theme.colorScheme.surface,
        iconTheme: IconThemeData(color: theme.colorScheme.onSurface),
        actions: [
          if (hasWriteAccess)
            Padding(
              padding: const EdgeInsets.only(right: AppSizes.p16),
              child: ElevatedButton.icon(
                onPressed: () => context.push('/tooling/add'),
                icon: const Icon(Icons.add_rounded),
                label: const Text('Add Tool'),
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
                    _buildDesktopSearchCard(theme),
                    const SizedBox(height: AppSizes.p20),
                    Text(
                      'All Tools',
                      style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: AppSizes.p12),
                    toolsAsync.when(
                      data: (tools) {
                        if (tools.isEmpty) {
                          return EmptyStateWidget(
                            icon: Icons.build_outlined,
                            title: 'No Tools Registered',
                            description: 'Add your company tools and equipment to track their code, category, location, and status.',
                            ctaLabel: hasWriteAccess ? 'Add Tool' : null,
                            onCtaPressed: hasWriteAccess ? () => context.push('/tooling/add') : null,
                          );
                        }
                        return _buildToolsList(tools, hasWriteAccess, hasDeleteAccess, authState.user?.companyId ?? '', theme);
                      },
                      loading: () => const Center(child: CircularProgressIndicator()),
                      error: (err, stack) => Center(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 40.0),
                          child: Text(
                            'Error loading tools: $err',
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

  Widget _buildStatusFilterRow() {
    final selectedFilter = ref.watch(toolStatusFilterProvider);
    final filters = ['All', 'Active', 'Inactive'];

    return SizedBox(
      height: 36,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: filters.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (ctx, i) {
          final filter = filters[i];
          final isSelected = filter == selectedFilter;
          return ChoiceChip(
            label: Text(filter, style: TextStyle(fontSize: 12, fontWeight: isSelected ? FontWeight.bold : FontWeight.normal)),
            selected: isSelected,
            onSelected: (val) {
              if (val) {
                ref.read(toolStatusFilterProvider.notifier).state = filter;
              }
            },
          );
        },
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
            Icon(Icons.build_outlined, size: 64, color: theme.colorScheme.onSurface.withAlpha(100)),
            const SizedBox(height: 16),
            Text(
              'No tools found.',
              style: theme.textTheme.titleMedium?.copyWith(
                color: theme.colorScheme.onSurface.withAlpha(150),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildToolCard(ToolModel tool, bool hasWriteAccess, bool hasDeleteAccess, String companyId, ThemeData theme) {
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

    return Card(
      key: ValueKey(tool.toolId),
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
        onTap: () => context.push('/tooling/${tool.toolId}'),
        borderRadius: BorderRadius.circular(AppSizes.cardRadius),
        child: Padding(
          padding: const EdgeInsets.all(AppSizes.p16),
          child: Column(
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
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          tool.toolCode,
                          style: TextStyle(
                            color: theme.colorScheme.onSurface.withAlpha(180),
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: statusColor.withAlpha(30),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: statusColor, width: 0.5),
                    ),
                    child: Text(
                      tool.status,
                      style: TextStyle(
                        color: statusColor,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Icon(Icons.category_outlined, size: 14, color: theme.colorScheme.onSurface.withAlpha(120)),
                  const SizedBox(width: 4),
                  Text(
                    tool.toolType.isNotEmpty ? tool.toolType : 'No Type',
                    style: TextStyle(fontSize: 12, color: theme.colorScheme.onSurface.withAlpha(150)),
                  ),
                  const SizedBox(width: 8),
                  Text('•', style: TextStyle(color: theme.colorScheme.onSurface.withAlpha(100))),
                  const SizedBox(width: 8),
                  Icon(Icons.location_on_outlined, size: 14, color: theme.colorScheme.onSurface.withAlpha(120)),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      tool.location.isNotEmpty ? tool.location : 'No Location',
                      style: TextStyle(fontSize: 12, color: theme.colorScheme.onSurface.withAlpha(150)),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              if (hasWriteAccess) ...[
                const Divider(height: AppSizes.p20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton.icon(
                      onPressed: () => context.push('/tooling/${tool.toolId}/edit', extra: tool),
                      icon: const Icon(Icons.edit_rounded, size: 16, color: Colors.blue),
                      label: const Text('Edit', style: TextStyle(color: Colors.blue)),
                      style: TextButton.styleFrom(minimumSize: const Size(60, 36)),
                    ),
                    if (hasDeleteAccess) ...[
                      const SizedBox(width: AppSizes.p12),
                      TextButton.icon(
                        onPressed: () => _confirmDelete(context, tool, companyId),
                        icon: const Icon(Icons.delete_rounded, size: 16, color: AppColors.error),
                        label: const Text('Delete', style: TextStyle(color: AppColors.error)),
                        style: TextButton.styleFrom(minimumSize: const Size(60, 36)),
                      ),
                    ],
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDesktopSearchCard(ThemeData theme) {
    final query = ref.watch(toolSearchQueryProvider);
    final selectedFilter = ref.watch(toolStatusFilterProvider);
    final filters = ['All', 'Active', 'Inactive'];

    return Card(
      margin: EdgeInsets.zero,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppSizes.cardRadius),
        side: BorderSide(color: theme.dividerColor.withAlpha(40)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppSizes.p16),
        child: Row(
          children: [
            Expanded(
              flex: 3,
              child: TextField(
                onChanged: (val) => ref.read(toolSearchQueryProvider.notifier).state = val,
                controller: TextEditingController(text: query)..selection = TextSelection.fromPosition(TextPosition(offset: query.length)),
                decoration: InputDecoration(
                  hintText: 'Search tool by name or code...',
                  prefixIcon: const Icon(Icons.search_rounded),
                  suffixIcon: query.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear_rounded),
                          onPressed: () => ref.read(toolSearchQueryProvider.notifier).state = '',
                        )
                      : null,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
            ),
            const SizedBox(width: AppSizes.p16),
            Expanded(
              flex: 2,
              child: DropdownButtonFormField<String>(
                value: selectedFilter,
                decoration: InputDecoration(
                  labelText: 'Status Filter',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                ),
                items: filters.map((f) {
                  return DropdownMenuItem(
                    value: f,
                    child: Text(f),
                  );
                }).toList(),
                onChanged: (val) {
                  if (val != null) {
                    ref.read(toolStatusFilterProvider.notifier).state = val;
                  }
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildToolsList(List<ToolModel> tools, bool hasWriteAccess, bool hasDeleteAccess, String companyId, ThemeData theme) {
    final isTablet = ResponsiveLayout.isTablet(context);
    final columns = isTablet ? 2 : 3;

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: columns,
        crossAxisSpacing: AppSizes.p16,
        mainAxisSpacing: AppSizes.p16,
        mainAxisExtent: hasWriteAccess ? 190 : 136,
      ),
      itemCount: tools.length,
      itemBuilder: (context, index) {
        final tool = tools[index];
        return _buildToolCard(tool, hasWriteAccess, hasDeleteAccess, companyId, theme);
      },
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
