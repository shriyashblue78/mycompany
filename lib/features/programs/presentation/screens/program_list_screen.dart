import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/constants/app_sizes.dart';
import '../../../../core/widgets/erp_drawer.dart';
import '../../../../core/widgets/responsive_layout.dart';
import '../../../../core/widgets/responsive_widgets.dart';
import '../../../../core/widgets/polish_widgets.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../machines/presentation/providers/machine_provider.dart';
import '../../domain/models/program_model.dart';
import '../providers/program_provider.dart';

class ProgramListScreen extends ConsumerStatefulWidget {
  const ProgramListScreen({super.key});

  @override
  ConsumerState<ProgramListScreen> createState() => _ProgramListScreenState();
}

class _ProgramListScreenState extends ConsumerState<ProgramListScreen> {
  late TextEditingController _searchController;

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController();
    // Reset filters on init
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(programSearchQueryProvider.notifier).state = '';
      ref.read(programSelectedMachineFilterProvider.notifier).state = 'All';
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _deleteProgram(BuildContext context, ProgramModel program) async {
    final confirmed = await showDeleteConfirmationDialog(
      context: context,
      recordName: 'Program ${program.programName}',
    );

    if (!confirmed) return;

    final authState = ref.read(authProvider);
    final companyId = authState.user?.companyId;

    if (companyId == null || companyId.isEmpty) {
      if (context.mounted) {
        showFeedbackSnackBar(
          context: context,
          message: 'Error: Company context not found.',
          isError: true,
        );
      }
      return;
    }

    try {
      final repo = ref.read(programRepositoryProvider);
      await repo.deleteProgram(companyId, program.programId);

      if (context.mounted) {
        showFeedbackSnackBar(
          context: context,
          message: 'Program "${program.programName}" deleted successfully.',
        );
      }
    } catch (e) {
      if (context.mounted) {
        showFeedbackSnackBar(
          context: context,
          message: 'Failed to delete program: $e',
          isError: true,
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);
    final role = authState.selectedRole ?? 'Employee';
    final hasOwnerAccess = role == 'Owner';

    final programsAsync = ref.watch(filteredProgramsProvider);
    final machinesAsync = ref.watch(companyMachinesStreamProvider);
    final query = ref.watch(programSearchQueryProvider);

    final theme = Theme.of(context);
    final isMobile = ResponsiveLayout.isMobile(context);

    // Layout configuration
    final crossAxisCount = isMobile ? 1 : (ResponsiveLayout.isTablet(context) ? 2 : 3);
    final childAspectRatio = isMobile ? 3.2 : 1.8;

    Widget buildBodyContent() {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Search Bar & Filters
          Padding(
            padding: const EdgeInsets.only(bottom: AppSizes.p16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                PremiumSearchBar(
                  controller: _searchController,
                  hintText: 'Search programs by identifier...',
                  onChanged: (val) => ref.read(programSearchQueryProvider.notifier).state = val,
                ),
                const SizedBox(height: 12),
                _buildMachineFilterRow(),
              ],
            ),
          ),

          // Main programs list/grid
          Expanded(
            child: programsAsync.when(
              data: (programs) {
                if (programs.isEmpty) {
                  return EmptyStateWidget(
                    icon: Icons.code_rounded,
                    title: query.isNotEmpty ? 'No programs match search' : 'No CNC Programs Found',
                    description: query.isNotEmpty 
                        ? 'Try modifying your search text or selecting a different machine filter.' 
                        : 'Store and manage CNC machine programs, controller offsets, or toolpaths in one secure registry.',
                    ctaLabel: hasOwnerAccess && query.isEmpty ? 'Add Program' : null,
                    onCtaPressed: hasOwnerAccess && query.isEmpty ? () => context.push('/programs/add') : null,
                  );
                }

                if (isMobile) {
                  return ListView.separated(
                    itemCount: programs.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 12),
                    itemBuilder: (context, index) {
                      return _buildProgramMobileCard(programs[index], hasOwnerAccess, theme);
                    },
                  );
                }

                return GridView.builder(
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: crossAxisCount,
                    crossAxisSpacing: AppSizes.p16,
                    mainAxisSpacing: AppSizes.p16,
                    childAspectRatio: childAspectRatio,
                  ),
                  itemCount: programs.length,
                  itemBuilder: (context, index) {
                    return _buildProgramGridCard(programs[index], hasOwnerAccess, theme);
                  },
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (err, _) => Center(
                child: Text('Error loading programs: $err', style: TextStyle(color: theme.colorScheme.error)),
              ),
            ),
          ),
        ],
      );
    }

    if (isMobile) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('CNC Programs', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17)),
          elevation: 0,
          backgroundColor: theme.colorScheme.surface,
          iconTheme: IconThemeData(color: theme.colorScheme.onSurface),
          actions: [
            if (hasOwnerAccess)
              IconButton(
                onPressed: () => context.push('/programs/add'),
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
        body: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
          child: buildBodyContent(),
        ),
      );
    }

    return ResponsiveScaffold(
      appBar: AppBar(
        title: const Text('Programs Registry'),
        elevation: 0,
        backgroundColor: theme.colorScheme.surface,
        iconTheme: IconThemeData(color: theme.colorScheme.onSurface),
        actions: [
          if (hasOwnerAccess)
            Padding(
              padding: const EdgeInsets.only(right: AppSizes.p16),
              child: ElevatedButton.icon(
                onPressed: () => context.push('/programs/add'),
                icon: const Icon(Icons.add_rounded),
                label: const Text('Add Program'),
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
                height: MediaQuery.of(context).size.height - 180,
                child: buildBodyContent(),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMachineFilterRow() {
    final selectedFilter = ref.watch(programSelectedMachineFilterProvider);
    final machinesAsync = ref.watch(companyMachinesStreamProvider);

    return machinesAsync.when(
      data: (machines) {
        final filters = ['All', ...machines.map((m) => m.machineId)];
        
        return SizedBox(
          height: 36,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: filters.length,
            separatorBuilder: (_, __) => const SizedBox(width: 8),
            itemBuilder: (ctx, i) {
              final filterId = filters[i];
              final isSelected = filterId == selectedFilter;
              
              final label = filterId == 'All' 
                  ? 'All Machines' 
                  : machines.firstWhere((m) => m.machineId == filterId).machineName;

              return ChoiceChip(
                label: Text(label, style: TextStyle(fontSize: 12, fontWeight: isSelected ? FontWeight.bold : FontWeight.normal)),
                selected: isSelected,
                onSelected: (_) => ref.read(programSelectedMachineFilterProvider.notifier).state = filterId,
                selectedColor: Theme.of(context).colorScheme.primary.withOpacity(0.15),
                labelStyle: TextStyle(
                  color: isSelected 
                      ? Theme.of(context).colorScheme.primary 
                      : Theme.of(context).textTheme.bodyMedium?.color,
                ),
              );
            },
          ),
        );
      },
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
    );
  }

  // Grid Card Layout
  Widget _buildProgramGridCard(ProgramModel program, bool hasOwnerAccess, ThemeData theme) {
    return Card(
      elevation: 0,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: theme.dividerColor.withAlpha(30)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.primary.withAlpha(20),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.code_rounded, size: 14, color: theme.colorScheme.primary),
                          const SizedBox(width: 6),
                          Text(
                            program.programName,
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                              color: theme.colorScheme.primary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (hasOwnerAccess)
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: Icon(Icons.edit_outlined, size: 18, color: theme.colorScheme.primary),
                            onPressed: () => context.push('/programs/${program.programId}/edit', extra: program),
                            style: IconButton.styleFrom(
                              backgroundColor: theme.colorScheme.primary.withOpacity(0.05),
                            ),
                          ),
                          const SizedBox(width: 6),
                          IconButton(
                            icon: const Icon(Icons.delete_outline_rounded, size: 18, color: Colors.red),
                            onPressed: () => _deleteProgram(context, program),
                            style: IconButton.styleFrom(
                              backgroundColor: Colors.red.withOpacity(0.05),
                            ),
                          ),
                        ],
                      ),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Icon(Icons.settings_rounded, size: 16, color: theme.textTheme.bodySmall?.color?.withOpacity(0.6)),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        program.machineName,
                        style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            Text(
              'Linked to active tooling master profile.',
              style: TextStyle(
                fontSize: 11,
                color: theme.textTheme.bodySmall?.color?.withOpacity(0.5),
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Mobile List Card Layout
  Widget _buildProgramMobileCard(ProgramModel program, bool hasOwnerAccess, ThemeData theme) {
    return Card(
      elevation: 0,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: theme.dividerColor.withAlpha(20)),
      ),
      child: Container(
        height: 72,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: theme.colorScheme.primary.withAlpha(15),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.code_rounded, color: theme.colorScheme.primary, size: 20),
            ),
            const SizedBox(width: AppSizes.p16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    'Program ${program.programName}',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    program.machineName,
                    style: TextStyle(fontSize: 11, color: theme.textTheme.bodySmall?.color?.withOpacity(0.6)),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            if (hasOwnerAccess) ...[
              IconButton(
                icon: Icon(Icons.edit_outlined, color: theme.colorScheme.primary, size: 18),
                onPressed: () => context.push('/programs/${program.programId}/edit', extra: program),
              ),
              IconButton(
                icon: const Icon(Icons.delete_outline_rounded, color: Colors.red, size: 18),
                onPressed: () => _deleteProgram(context, program),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
