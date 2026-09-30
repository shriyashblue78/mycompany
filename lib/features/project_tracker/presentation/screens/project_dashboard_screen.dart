import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_sizes.dart';
import '../../../../core/widgets/erp_drawer.dart';
import '../../../../core/widgets/responsive_layout.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../auth/domain/models/user_model.dart';
import '../../domain/models/project_model.dart';
import '../../domain/models/project_tracker_config.dart';
import '../providers/project_tracker_provider.dart';
import '../widgets/edit_stage_dialog.dart';
import '../../../drawings/presentation/providers/drawing_provider.dart';
import '../../../drawings/domain/models/drawing_model.dart';

class ProjectDashboardScreen extends ConsumerStatefulWidget {
  const ProjectDashboardScreen({super.key});

  @override
  ConsumerState<ProjectDashboardScreen> createState() => _ProjectDashboardScreenState();
}

class _ProjectDashboardScreenState extends ConsumerState<ProjectDashboardScreen> {
  String _selectedDepartment = 'All';
  bool _isInitialized = false;
  String? _expandedProjectId;

  String _getProjectCode(ProjectModel project) {
    if (project.projectName.toLowerCase().contains('mission beta')) {
      return 'MB-2025-001';
    }
    return 'PRJ-${project.projectId.toUpperCase().substring(0, 5)}';
  }

  String _getClientName(ProjectModel project) {
    if (project.projectName.toLowerCase().contains('mission beta')) {
      return 'John Doe';
    }
    return 'Internal';
  }

  IconData _getStageIcon(String name) {
    switch (name) {
      case 'Marketing': return Icons.link_rounded;
      case 'Design': return Icons.edit_note_rounded;
      case 'Purchase': return Icons.shopping_cart_rounded;
      case 'Machining': return Icons.settings_rounded;
      case 'Assembly': return Icons.build_rounded;
      case 'Quality': return Icons.verified_rounded;
      case 'Accounts': return Icons.receipt_long_rounded;
      default: return Icons.help_outline_rounded;
    }
  }

  Color _getStageIconColor(String name) {
    switch (name) {
      case 'Marketing': return Colors.green.shade700;
      case 'Design': return Colors.purple.shade700;
      case 'Purchase': return Colors.blue.shade700;
      case 'Machining': return Colors.orange.shade700;
      case 'Assembly': return Colors.deepPurple.shade700;
      case 'Quality': return Colors.teal.shade700;
      case 'Accounts': return Colors.indigo.shade700;
      default: return Colors.grey;
    }
  }

  Future<void> _openFileUrl(String urlString) async {
    final url = Uri.parse(urlString);
    if (await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final authState = ref.watch(authProvider);
    final role = authState.selectedRole ?? 'Employee';
    final user = authState.user;

    if (!_isInitialized && user != null) {
      final userDept = user.department;
      final userDeptMapped = ProjectTrackerConfig.getStageNameFromDepartment(userDept);
      if (userDeptMapped.isNotEmpty) {
        _selectedDepartment = userDeptMapped;
      } else {
        _selectedDepartment = 'All';
      }
      _isInitialized = true;
    }

    final projectsAsync = ref.watch(filteredProjectsProvider);
    final drawingsAsync = ref.watch(companyDrawingsStreamProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Project Tracker', style: TextStyle(fontWeight: FontWeight.bold)),
        elevation: 0,
        backgroundColor: theme.colorScheme.surface,
        iconTheme: IconThemeData(color: theme.colorScheme.onSurface),
        actions: [
          if (role == 'Owner')
            Padding(
              padding: const EdgeInsets.only(right: 16.0),
              child: ElevatedButton.icon(
                onPressed: () => context.push('/project-tracker/create'),
                icon: const Icon(Icons.add_rounded, color: Colors.white, size: 16),
                label: const Text('Add Project', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: theme.colorScheme.primary,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  elevation: 0,
                ),
              ),
            ),
        ],
      ),
      drawer: const ERPDrawer(),
      body: SafeArea(
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          child: Padding(
            padding: const EdgeInsets.all(AppSizes.p16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 1. Stats Cards Header
                _buildStatsHeader(theme, isDark),
                const SizedBox(height: AppSizes.p12),

                // 2. View Toggle Controls (Focus Area)
                _buildViewSelector(user, role, theme, isDark),
                const SizedBox(height: AppSizes.p12),

                // 3. Search & Filter controls
                _buildFilterControls(context, theme, isDark),
                const SizedBox(height: AppSizes.p12),

                // 4. Responsive List/Table
                projectsAsync.when(
                  loading: () => const Center(child: Padding(
                    padding: EdgeInsets.all(32.0),
                    child: CircularProgressIndicator(),
                  )),
                  error: (err, stack) => Center(child: Padding(
                    padding: const EdgeInsets.all(32.0),
                    child: Text('Error loading projects: $err'),
                  )),
                  data: (projects) {
                    final activeProjects = _selectedDepartment == 'All'
                        ? projects
                        : projects.where((p) => p.currentStage == _selectedDepartment && p.status != 'Completed' && p.status != 'On Hold').toList();

                    if (activeProjects.isEmpty) {
                      return Center(
                        child: Padding(
                          padding: const EdgeInsets.all(32.0),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.assignment_late_outlined, size: 64, color: Colors.grey.shade400),
                              const SizedBox(height: 12),
                              Text(
                                _selectedDepartment == 'All'
                                    ? 'No projects found'
                                    : 'No active projects currently at $_selectedDepartment stage',
                                style: theme.textTheme.titleMedium?.copyWith(color: Colors.grey.shade600),
                                textAlign: TextAlign.center,
                              ),
                            ],
                          ),
                        ),
                      );
                    }

                    final drawings = drawingsAsync.maybeWhen(
                      data: (list) => list,
                      orElse: () => <DrawingModel>[],
                    );

                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (_selectedDepartment == 'All') ...[
                          _buildWorkflowPipeline(projects, theme, isDark),
                          const SizedBox(height: AppSizes.p12),
                        ],
                        ResponsiveLayout(
                          mobile: _selectedDepartment == 'All'
                              ? _buildMobileTable(context, activeProjects, user, theme, isDark)
                              : _buildMobileDepartmentCards(context, activeProjects, drawings, user, theme, isDark),
                          tablet: _selectedDepartment == 'All'
                              ? _buildDesktopTable(context, activeProjects, user, theme, isDark)
                              : _buildDesktopDepartmentTable(context, activeProjects, drawings, user, theme, isDark),
                          desktop: _selectedDepartment == 'All'
                              ? _buildDesktopTable(context, activeProjects, user, theme, isDark)
                              : _buildDesktopDepartmentTable(context, activeProjects, drawings, user, theme, isDark),
                        ),
                        if (_selectedDepartment == 'All') ...[
                          _buildPaginationRow(activeProjects.length, theme, isDark),
                        ],
                      ],
                    );
                  },
                ),
              ],
            ),
          ),
        ),
      ),
      floatingActionButton: role == 'Owner' && ResponsiveLayout.isMobile(context)
          ? FloatingActionButton(
              onPressed: () => context.push('/project-tracker/create'),
              backgroundColor: theme.colorScheme.primary,
              child: const Icon(Icons.add_rounded, color: Colors.white),
            )
          : null,
    );
  }

  Widget _buildViewSelector(UserModel? user, String role, ThemeData theme, bool isDark) {
    final userDept = user?.department ?? '';
    final userDeptMapped = ProjectTrackerConfig.getStageNameFromDepartment(userDept);
    final isManager = role == 'Owner' || role == 'HR' || role == 'Supervisor';

    return Row(
      children: [
        const Text('Focus Area: ', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.grey)),
        const SizedBox(width: 8),
        Expanded(
          child: Container(
            height: 38,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: isDark ? Colors.grey.shade800 : Colors.grey.shade300),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: _selectedDepartment,
                isExpanded: true,
                items: [
                  const DropdownMenuItem(value: 'All', child: Text('All Pipeline (Overview)', style: TextStyle(fontSize: 13))),
                  if (isManager || userDeptMapped == 'Marketing') const DropdownMenuItem(value: 'Marketing', child: Text('Marketing', style: TextStyle(fontSize: 13))),
                  if (isManager || userDeptMapped == 'Design') const DropdownMenuItem(value: 'Design', child: Text('Design', style: TextStyle(fontSize: 13))),
                  if (isManager || userDeptMapped == 'Purchase') const DropdownMenuItem(value: 'Purchase', child: Text('Purchase', style: TextStyle(fontSize: 13))),
                  if (isManager || userDeptMapped == 'Machining') const DropdownMenuItem(value: 'Machining', child: Text('Machining', style: TextStyle(fontSize: 13))),
                  if (isManager || userDeptMapped == 'Assembly') const DropdownMenuItem(value: 'Assembly', child: Text('Assembly', style: TextStyle(fontSize: 13))),
                  if (isManager || userDeptMapped == 'Quality') const DropdownMenuItem(value: 'Quality', child: Text('Quality', style: TextStyle(fontSize: 13))),
                  if (isManager || userDeptMapped == 'Accounts') const DropdownMenuItem(value: 'Accounts', child: Text('Accounts', style: TextStyle(fontSize: 13))),
                ],
                onChanged: (val) {
                  if (val != null) {
                    setState(() {
                      _selectedDepartment = val;
                    });
                  }
                },
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildStatsHeader(ThemeData theme, bool isDark) {
    final allProjectsAsync = ref.watch(projectsStreamProvider);

    return allProjectsAsync.when(
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
      data: (projects) {
        final total = projects.length;
        final inProgress = projects.where((p) => p.status == 'In Progress').length;
        final completed = projects.where((p) => p.status == 'Completed').length;
        final planned = projects.where((p) => p.status == 'Planned').length;

        return LayoutBuilder(
          builder: (context, constraints) {
            final double width = constraints.maxWidth;
            final int crossAxisCount = width < 600 ? 2 : 4;
            return GridView.count(
              crossAxisCount: crossAxisCount,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisSpacing: AppSizes.p12,
              mainAxisSpacing: AppSizes.p12,
              childAspectRatio: crossAxisCount == 2 ? 1.4 : 3.2,
              children: [
                _buildStatCard('Total Projects', total.toString(), 'All time', Icons.folder_rounded, Colors.blue, theme, isDark),
                _buildStatCard('Planned', planned.toString(), 'Not started', Icons.pending_actions_rounded, Colors.purple, theme, isDark),
                _buildStatCard('In Progress', inProgress.toString(), 'Currently active', Icons.sync_rounded, Colors.orange, theme, isDark),
                _buildStatCard('Completed', completed.toString(), 'Successfully done', Icons.check_circle_outline_rounded, Colors.green, theme, isDark),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildStatCard(String label, String value, String subtitle, IconData icon, Color color, ThemeData theme, bool isDark) {
    return Container(
      decoration: BoxDecoration(
        color: isDark ? theme.colorScheme.surface : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: isDark ? Colors.grey.shade800 : Colors.grey.shade200),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 10.0, vertical: 10.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(7),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(9),
            ),
            child: Icon(icon, color: color, size: 18),
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, height: 1.1),
          ),
          const SizedBox(height: 3),
          Text(
            label,
            style: TextStyle(fontSize: 11, color: Colors.grey.shade600, fontWeight: FontWeight.w600),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildFilterControls(BuildContext context, ThemeData theme, bool isDark) {
    final statusFilter = ref.watch(projectStatusFilterProvider);
    final isMobile = MediaQuery.of(context).size.width < 600;

    final searchField = SizedBox(
      height: 40,
      child: TextField(
        onChanged: (val) => ref.read(projectSearchQueryProvider.notifier).state = val,
        decoration: InputDecoration(
          hintText: 'Search projects by name, code, or client...',
          prefixIcon: const Icon(Icons.search_rounded, size: 18),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 0),
        ),
        style: const TextStyle(fontSize: 13),
      ),
    );

    final statusDropdown = Container(
      height: 40,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: isDark ? Colors.grey.shade800 : Colors.grey.shade300),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.filter_alt_outlined, color: Colors.grey.shade600, size: 16),
          const SizedBox(width: 6),
          DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: statusFilter ?? 'All',
              items: <String>['All', 'Planned', 'In Progress', 'Completed', 'On Hold']
                  .map((status) => DropdownMenuItem<String>(
                        value: status,
                        child: Text(status == 'All' ? 'All Projects' : status, style: const TextStyle(fontSize: 13)),
                      ))
                  .toList(),
              onChanged: (val) {
                ref.read(projectStatusFilterProvider.notifier).state = val == 'All' ? null : val;
              },
            ),
          ),
        ],
      ),
    );

    final sortDropdown = Container(
      height: 40,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: isDark ? Colors.grey.shade800 : Colors.grey.shade300),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: 'Latest First',
          items: const [
            DropdownMenuItem(value: 'Latest First', child: Text('Sort: Latest First', style: TextStyle(fontSize: 13))),
          ],
          onChanged: (_) {},
        ),
      ),
    );

    final viewButtons = Container(
      height: 40,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: isDark ? Colors.grey.shade800 : Colors.grey.shade300),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            icon: const Icon(Icons.grid_on_rounded, size: 16, color: Colors.green),
            onPressed: () {},
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 36, minHeight: 40),
          ),
          Container(width: 1, height: 24, color: isDark ? Colors.grey.shade800 : Colors.grey.shade300),
          IconButton(
            icon: const Icon(Icons.list_rounded, size: 18, color: Colors.grey),
            onPressed: () {},
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 36, minHeight: 40),
          ),
        ],
      ),
    );

    if (isMobile) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          searchField,
          const SizedBox(height: 8),
          statusDropdown,
        ],
      );
    }

    return Row(
      children: [
        Expanded(child: searchField),
        const SizedBox(width: 12),
        statusDropdown,
        const SizedBox(width: 12),
        sortDropdown,
        const SizedBox(width: 12),
        viewButtons,
      ],
    );
  }

  Widget _buildWorkflowPipeline(List<ProjectModel> projects, ThemeData theme, bool isDark) {
    final activeProjects = projects.where((p) => p.status != 'Completed' && p.status != 'On Hold').toList();
    final stages = ProjectTrackerConfig.stages;

    final Map<String, int> counts = {for (var s in stages) s: 0};
    for (final p in activeProjects) {
      if (counts.containsKey(p.currentStage)) {
        counts[p.currentStage] = counts[p.currentStage]! + 1;
      }
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: isDark ? theme.colorScheme.surface : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: isDark ? Colors.grey.shade800 : Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Active Project Pipeline',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.grey),
          ),
          const SizedBox(height: 10),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: stages.asMap().entries.map((entry) {
                final idx = entry.key;
                final stage = entry.value;
                final count = counts[stage] ?? 0;
                final isLast = idx == stages.length - 1;
                final colColor = _getStageIconColor(stage);

                return Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 130,
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
                          decoration: BoxDecoration(
                            color: count > 0 
                                ? Colors.orange.shade50.withOpacity(isDark ? 0.15 : 0.8) 
                                : isDark ? theme.colorScheme.surface : Colors.grey.shade50,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: count > 0 ? Colors.orange.shade300 : isDark ? Colors.grey.shade800 : Colors.grey.shade200,
                              width: count > 0 ? 1.5 : 1.0,
                            ),
                          ),
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(6),
                                decoration: BoxDecoration(
                                  color: colColor.withOpacity(0.08),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Icon(_getStageIcon(stage), color: colColor, size: 18),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      stage,
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                        color: isDark ? Colors.white70 : Colors.grey.shade700,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      count.toString(),
                                      style: const TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (count > 0)
                          Icon(Icons.arrow_drop_down_rounded, color: Colors.orange.shade400, size: 16)
                        else
                          const SizedBox(height: 16),
                      ],
                    ),
                    if (!isLast)
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 6),
                        child: Icon(
                          Icons.chevron_right_rounded,
                          color: Colors.grey.shade400,
                          size: 16,
                        ),
                      ),
                  ],
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  // --- 1. GLOBAL PIPELINE VIEW - DESKTOP ---
  Widget _buildDesktopTable(BuildContext context, List<ProjectModel> projects, UserModel? user, ThemeData theme, bool isDark) {
    final Color borderColor = isDark ? Colors.grey.shade800 : Colors.grey.shade200;

    return LayoutBuilder(
      builder: (context, constraints) {
        final double width = constraints.maxWidth;
        final double baseWidth = width < 1200 ? 1200 : width;

        final double srWidth = baseWidth * 0.04;
        final double projWidth = baseWidth * 0.14;
        final double clientWidth = baseWidth * 0.10;
        final double stageWidth = baseWidth * 0.085;
        final double statusWidth = baseWidth * 0.085;
        final double actionsWidth = baseWidth * 0.045;

        return Container(
          decoration: BoxDecoration(
            color: isDark ? theme.colorScheme.surface : Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: borderColor),
          ),
          clipBehavior: Clip.antiAlias,
          child: SingleChildScrollView(
            scrollDirection: Axis.vertical,
            physics: const BouncingScrollPhysics(),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              child: IntrinsicWidth(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      color: isDark ? Colors.grey.shade900 : Colors.grey.shade50,
                      height: 52,
                      child: Row(
                        children: [
                          _buildHeaderCell('Sr No.', srWidth, Colors.grey.shade700, borderColor),
                          _buildHeaderCell('Project Name', projWidth, Colors.grey.shade700, borderColor),
                          _buildHeaderCell('Client / Code', clientWidth, Colors.grey.shade700, borderColor),
                          _buildHeaderCell('Marketing', stageWidth, _getStageIconColor('Marketing'), borderColor),
                          _buildHeaderCell('Design', stageWidth, _getStageIconColor('Design'), borderColor),
                          _buildHeaderCell('Purchase', stageWidth, _getStageIconColor('Purchase'), borderColor),
                          _buildHeaderCell('Machining', stageWidth, _getStageIconColor('Machining'), borderColor),
                          _buildHeaderCell('Assembly', stageWidth, _getStageIconColor('Assembly'), borderColor),
                          _buildHeaderCell('Quality', stageWidth, _getStageIconColor('Quality'), borderColor),
                          _buildHeaderCell('Accounts', stageWidth, _getStageIconColor('Accounts'), borderColor),
                          _buildHeaderCell('Status', statusWidth, Colors.grey.shade700, borderColor),
                          _buildHeaderCell('Actions', actionsWidth, Colors.grey.shade700, borderColor, isLast: true),
                        ],
                      ),
                    ),
                    const Divider(height: 1, thickness: 1),
                    ...projects.asMap().entries.map((entry) {
                      final idx = entry.key;
                      final project = entry.value;
                      final srNo = (idx + 1).toString().padLeft(2, '0');
                      final role = ref.read(authProvider).selectedRole;
                      final isAuthorized = role == 'Owner' || role == 'HR' || role == 'Supervisor';

                      return Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          InkWell(
                            onTap: () {
                              setState(() {
                                if (_expandedProjectId == project.projectId) {
                                  _expandedProjectId = null;
                                } else {
                                  _expandedProjectId = project.projectId;
                                }
                              });
                            },
                            hoverColor: theme.colorScheme.primary.withOpacity(0.04),
                            child: Container(
                              height: 68,
                              decoration: BoxDecoration(
                                border: Border(bottom: BorderSide(color: borderColor, width: 0.5)),
                              ),
                              child: Row(
                                children: [
                                  _buildBodyCell(Text(srNo, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)), srWidth, borderColor),
                                  _buildBodyCell(
                                    Text(
                                      project.projectName,
                                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    projWidth,
                                    borderColor,
                                    alignment: Alignment.centerLeft,
                                    horizontalPadding: 8,
                                  ),
                                  _buildBodyCell(
                                    Column(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(_getClientName(project), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                                        Text(_getProjectCode(project), style: const TextStyle(color: Colors.grey, fontSize: 11)),
                                      ],
                                    ),
                                    clientWidth,
                                    borderColor,
                                    alignment: Alignment.centerLeft,
                                    horizontalPadding: 8,
                                  ),
                                  _buildBodyCell(_buildDesktopStageCell(project.marketingStage, 'Marketing', project, theme, isDark), stageWidth, borderColor),
                                  _buildBodyCell(_buildDesktopStageCell(project.designStage, 'Design', project, theme, isDark), stageWidth, borderColor),
                                  _buildBodyCell(_buildDesktopStageCell(project.purchaseStage, 'Purchase', project, theme, isDark), stageWidth, borderColor),
                                  _buildBodyCell(_buildDesktopStageCell(project.machiningStage, 'Machining', project, theme, isDark), stageWidth, borderColor),
                                  _buildBodyCell(_buildDesktopStageCell(project.assemblyStage, 'Assembly', project, theme, isDark), stageWidth, borderColor),
                                  _buildBodyCell(_buildDesktopStageCell(project.qualityStage, 'Quality', project, theme, isDark), stageWidth, borderColor),
                                  _buildBodyCell(_buildDesktopStageCell(project.accountsStage, 'Accounts', project, theme, isDark), stageWidth, borderColor),
                                  _buildBodyCell(_buildOverallStatusBadge(project.status, _getStatusColor(project.status)), statusWidth, borderColor),
                                  _buildBodyCell(
                                    GestureDetector(
                                      onTap: () {},
                                      child: PopupMenuButton<String>(
                                        icon: const Icon(Icons.more_vert_rounded, color: Colors.grey, size: 20),
                                        padding: EdgeInsets.zero,
                                        onSelected: (val) {
                                          if (val == 'details') {
                                            context.push('/project-tracker/${project.projectId}');
                                          } else if (val == 'edit') {
                                            context.push('/project-tracker/${project.projectId}/edit', extra: project);
                                          } else if (val == 'delete') {
                                            _confirmDelete(context, project, user);
                                          }
                                        },
                                        itemBuilder: (ctx) => [
                                          const PopupMenuItem(
                                            value: 'details',
                                            child: Row(
                                              children: [
                                                Icon(Icons.unfold_more_rounded, size: 18),
                                                SizedBox(width: 8),
                                                Text('View Details'),
                                              ],
                                            ),
                                          ),
                                          if (isAuthorized) ...[
                                            const PopupMenuItem(
                                              value: 'edit',
                                              child: Row(
                                                children: [
                                                  Icon(Icons.edit_rounded, size: 18, color: Colors.blue),
                                                  SizedBox(width: 8),
                                                  Text('Edit Metadata'),
                                                ],
                                              ),
                                            ),
                                            const PopupMenuItem(
                                              value: 'delete',
                                              child: Row(
                                                children: [
                                                  Icon(Icons.delete_rounded, size: 18, color: Colors.red),
                                                  SizedBox(width: 8),
                                                  Text('Delete Project'),
                                                ],
                                              ),
                                            ),
                                          ],
                                        ],
                                      ),
                                    ),
                                    actionsWidth,
                                    borderColor,
                                    isLast: true,
                                  ),
                                ],
                              ),
                            ),
                          ),
                          AnimatedSize(
                            duration: const Duration(milliseconds: 200),
                            curve: Curves.easeInOut,
                            child: _expandedProjectId == project.projectId
                                ? _buildExpandedDetails(context, project, theme, isDark)
                                : const SizedBox.shrink(),
                          ),
                        ],
                      );
                    }),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildExpandedDetails(BuildContext context, ProjectModel project, ThemeData theme, bool isDark) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? Colors.grey.shade900.withOpacity(0.4) : Colors.grey.shade50,
        border: Border(
          bottom: BorderSide(color: isDark ? Colors.grey.shade800 : Colors.grey.shade200),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Column 1: Description and history
              Expanded(
                flex: 4,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Project Description',
                      style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold, color: theme.colorScheme.primary),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      project.description.isNotEmpty ? project.description : 'No description provided.',
                      style: const TextStyle(fontSize: 12, height: 1.4),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Stage Transition History',
                      style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold, color: theme.colorScheme.primary),
                    ),
                    const SizedBox(height: 8),
                    if (project.stageHistory.isEmpty)
                      const Text('No stage changes logged yet.', style: TextStyle(fontSize: 11, fontStyle: FontStyle.italic, color: Colors.grey))
                    else
                      Container(
                        constraints: const BoxConstraints(maxHeight: 180),
                        child: ListView.separated(
                          shrinkWrap: true,
                          itemCount: project.stageHistory.length,
                          separatorBuilder: (_, __) => const Divider(height: 10, thickness: 0.5),
                          itemBuilder: (ctx, hIdx) {
                            final log = project.stageHistory[hIdx];
                            return Row(
                              children: [
                                Icon(Icons.circle, size: 6, color: _getStageIconColor(log.department)),
                                const SizedBox(width: 8),
                                Text(
                                  '${log.department}: ',
                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: _getStatusColor(log.status == 'Pending' ? 'Planned' : log.status).withOpacity(0.08),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    log.status,
                                    style: TextStyle(
                                      color: _getStatusColor(log.status == 'Pending' ? 'Planned' : log.status),
                                      fontWeight: FontWeight.bold,
                                      fontSize: 10,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    'by ${log.responsiblePerson} — "${log.remarks}"',
                                    style: const TextStyle(fontSize: 11, color: Colors.grey),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                Text(
                                  DateFormat('MMM d, yyyy h:mm a').format(log.timestamp),
                                  style: const TextStyle(fontSize: 10, color: Colors.grey),
                                ),
                              ],
                            );
                          },
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(width: 24),
              // Column 2: Stage checklist
              Expanded(
                flex: 3,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Stage Parameters & Assignees',
                      style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold, color: theme.colorScheme.primary),
                    ),
                    const SizedBox(height: 8),
                    _buildExpandedStageParamRow('Marketing', project.marketingStage, theme),
                    _buildExpandedStageParamRow('Design', project.designStage, theme),
                    _buildExpandedStageParamRow('Purchase', project.purchaseStage, theme),
                    _buildExpandedStageParamRow('Machining', project.machiningStage, theme),
                    _buildExpandedStageParamRow('Assembly', project.assemblyStage, theme),
                    _buildExpandedStageParamRow('Quality', project.qualityStage, theme),
                    _buildExpandedStageParamRow('Accounts', project.accountsStage, theme),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildExpandedStageParamRow(String stageName, ProjectStage stage, ThemeData theme) {
    final statusColor = _getStatusColor(stage.status == 'Pending' ? 'Planned' : stage.status);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Icon(_getStageIcon(stageName), color: _getStageIconColor(stageName), size: 14),
              const SizedBox(width: 8),
              Text(stageName, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600)),
            ],
          ),
          Row(
            children: [
              Text(
                stage.assignedUser ?? 'Unassigned',
                style: const TextStyle(color: Colors.grey, fontSize: 11),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: statusColor.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  stage.status,
                  style: TextStyle(color: statusColor, fontSize: 10, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildHeaderCell(String text, double width, Color textColor, Color borderColor, {bool isLast = false}) {
    return Container(
      width: width,
      height: 52,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        border: Border(
          right: isLast ? BorderSide.none : BorderSide(color: borderColor, width: 0.5),
        ),
      ),
      child: Text(
        text,
        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: textColor),
        textAlign: TextAlign.center,
      ),
    );
  }

  Widget _buildBodyCell(Widget child, double width, Color borderColor,
      {bool isLast = false, Alignment alignment = Alignment.center, double horizontalPadding = 0}) {
    return Container(
      width: width,
      height: 68,
      padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
      alignment: alignment,
      decoration: BoxDecoration(
        border: Border(
          right: isLast ? BorderSide.none : BorderSide(color: borderColor, width: 0.5),
        ),
      ),
      child: child,
    );
  }

  Widget _buildDesktopStageCell(ProjectStage stage, String stageName, ProjectModel project, ThemeData theme, bool isDark) {
    final isCurrent = project.currentStage == stageName;
    final colColor = _getStageIconColor(stageName);

    return Container(
      width: double.infinity,
      height: double.infinity,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: isCurrent ? colColor.withOpacity(0.04) : Colors.transparent,
        border: isCurrent ? Border.all(color: colColor.withOpacity(0.4), width: 1) : null,
      ),
      child: _buildStageStatusView(stage, stageName, isDark),
    );
  }

  Widget _buildStageStatusView(ProjectStage stage, String stageName, bool isDark) {
    if (stage.status == 'Completed') {
      final dateStr = stage.completedAt != null ? DateFormat('dd/MM').format(stage.completedAt!) : '';
      return Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.check_circle_rounded, color: Colors.green, size: 16),
              const SizedBox(width: 4),
              Text(
                dateStr,
                style: const TextStyle(color: Colors.green, fontWeight: FontWeight.bold, fontSize: 12.5),
              ),
            ],
          ),
          const SizedBox(height: 2),
          Text(
            stage.assignedUser ?? 'Unassigned',
            style: const TextStyle(color: Colors.grey, fontSize: 11),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      );
    } else if (stage.status == 'In Progress') {
      return Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.access_time_filled_rounded, color: Colors.orange.shade700, size: 16),
              const SizedBox(width: 4),
              Text(
                'In Progress',
                style: TextStyle(color: Colors.orange.shade700, fontWeight: FontWeight.bold, fontSize: 12.5),
              ),
            ],
          ),
          const SizedBox(height: 2),
          Text(
            stage.assignedUser ?? '-',
            style: const TextStyle(color: Colors.grey, fontSize: 11),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      );
    } else {
      return Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: const [
              Icon(Icons.access_time_rounded, color: Colors.grey, size: 16),
              SizedBox(width: 4),
              Text(
                'Pending',
                style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold, fontSize: 12.5),
              ),
            ],
          ),
          const SizedBox(height: 2),
          const Text(
            '-',
            style: TextStyle(color: Colors.grey, fontSize: 11),
          ),
        ],
      );
    }
  }

  Widget _buildOverallStatusBadge(String status, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color, width: 1),
      ),
      child: Text(
        status,
        style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.bold),
      ),
    );
  }

  // --- 2. GLOBAL PIPELINE VIEW - MOBILE ---
  Widget _buildMobileTable(BuildContext context, List<ProjectModel> projects, UserModel? user, ThemeData theme, bool isDark) {
    final double projWidth = 60;
    final double stageWidth = 54;
    final Color borderColor = isDark ? Colors.grey.shade800 : Colors.grey.shade200;

    final List<Map<String, dynamic>> cols = [
      {'name': 'MKT', 'color': Colors.green.shade700},
      {'name': 'DES', 'color': Colors.pink.shade700},
      {'name': 'PUR', 'color': Colors.blue.shade700},
      {'name': 'MCH', 'color': Colors.orange.shade700},
      {'name': 'ASM', 'color': Colors.purple.shade700},
      {'name': 'QLT', 'color': Colors.teal.shade700},
      {'name': 'ACC', 'color': Colors.indigo.shade700},
    ];

    return Container(
      decoration: BoxDecoration(
        color: isDark ? theme.colorScheme.surface : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: borderColor),
      ),
      clipBehavior: Clip.antiAlias,
      child: SingleChildScrollView(
        scrollDirection: Axis.vertical,
        physics: const BouncingScrollPhysics(),
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          physics: const BouncingScrollPhysics(),
          child: IntrinsicWidth(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  color: isDark ? Colors.grey.shade900 : Colors.grey.shade50,
                  height: 40,
                  child: Row(
                    children: [
                      _buildHeaderCell('PJT', projWidth, Colors.black, borderColor),
                      ...cols.map((col) => _buildHeaderCell(col['name'], stageWidth, col['color'], borderColor)),
                    ],
                  ),
                ),
                const Divider(height: 1, thickness: 1),
                ...projects.map((project) {
                  final pjtName = _getProjectShortName(project.projectName);

                  return InkWell(
                    onTap: () => context.push('/project-tracker/${project.projectId}'),
                    hoverColor: theme.colorScheme.primary.withOpacity(0.04),
                    child: Container(
                      height: 52,
                      decoration: BoxDecoration(
                        border: Border(bottom: BorderSide(color: borderColor, width: 0.5)),
                      ),
                      child: Row(
                        children: [
                          _buildBodyCell(Text(pjtName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)), projWidth, borderColor),
                          _buildBodyCell(_buildMobileStageCell(project.marketingStage, 'Marketing', project, theme, isDark), stageWidth, borderColor),
                          _buildBodyCell(_buildMobileStageCell(project.designStage, 'Design', project, theme, isDark), stageWidth, borderColor),
                          _buildBodyCell(_buildMobileStageCell(project.purchaseStage, 'Purchase', project, theme, isDark), stageWidth, borderColor),
                          _buildBodyCell(_buildMobileStageCell(project.machiningStage, 'Machining', project, theme, isDark), stageWidth, borderColor),
                          _buildBodyCell(_buildMobileStageCell(project.assemblyStage, 'Assembly', project, theme, isDark), stageWidth, borderColor),
                          _buildBodyCell(_buildMobileStageCell(project.qualityStage, 'Quality', project, theme, isDark), stageWidth, borderColor),
                          _buildBodyCell(_buildMobileStageCell(project.accountsStage, 'Accounts', project, theme, isDark), stageWidth, borderColor, isLast: true),
                        ],
                      ),
                    ),
                  );
                }),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMobileStageCell(ProjectStage stage, String stageName, ProjectModel project, ThemeData theme, bool isDark) {
    final isCurrent = project.currentStage == stageName;
    final colColor = _getStageIconColor(stageName);

    return Container(
      width: double.infinity,
      height: double.infinity,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: isCurrent ? colColor.withOpacity(0.04) : Colors.transparent,
        border: isCurrent ? Border.all(color: colColor.withOpacity(0.4), width: 1) : null,
      ),
      child: _buildMobileStageStatusView(stage, stageName, isDark),
    );
  }

  Widget _buildMobileStageStatusView(ProjectStage stage, String stageName, bool isDark) {
    if (stage.status == 'Completed') {
      if (stageName == 'Accounts' && stage.completedAt != null) {
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
          decoration: BoxDecoration(
            color: Colors.green.shade50.withOpacity(isDark ? 0.15 : 0.8),
            borderRadius: BorderRadius.circular(4),
            border: Border.all(color: Colors.green.shade300, width: 0.5),
          ),
          child: const Text(
            'Completed',
            style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold, fontSize: 8),
            textAlign: TextAlign.center,
          ),
        );
      }
      return const Icon(Icons.check_rounded, color: Colors.green, size: 16);
    } else if (stage.status == 'In Progress') {
      final colColor = _getStageIconColor(stageName);
      return Container(
        width: double.infinity,
        margin: const EdgeInsets.symmetric(horizontal: 2, vertical: 4),
        padding: const EdgeInsets.symmetric(vertical: 2),
        decoration: BoxDecoration(
          color: colColor.withOpacity(0.08),
          borderRadius: BorderRadius.circular(4),
          border: Border.all(color: colColor.withOpacity(0.2), width: 0.5),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Text(
              'In Progress',
              style: TextStyle(color: colColor, fontWeight: FontWeight.bold, fontSize: 8),
              textAlign: TextAlign.center,
            ),
            if (stage.assignedUser != null && stage.assignedUser!.isNotEmpty)
              Text(
                stage.assignedUser!,
                style: TextStyle(color: colColor, fontSize: 7.5, fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
          ],
        ),
      );
    } else {
      return Icon(
        Icons.radio_button_unchecked_rounded,
        color: isDark ? Colors.grey.shade800 : Colors.grey.shade300,
        size: 14,
      );
    }
  }

  // --- 3. DEPARTMENT-LEVEL VIEW - DESKTOP ---
  Widget _buildDesktopDepartmentTable(
      BuildContext context, List<ProjectModel> projects, List<DrawingModel> drawings, UserModel? user, ThemeData theme, bool isDark) {
    final Color borderColor = isDark ? Colors.grey.shade800 : Colors.grey.shade200;

    return LayoutBuilder(
      builder: (context, constraints) {
        final double width = constraints.maxWidth;

        final double colProj = width * 0.16 > 150 ? width * 0.16 : 150;
        final double colUser = width * 0.13 > 120 ? width * 0.13 : 120;
        final double colRecv = width * 0.13 > 120 ? width * 0.13 : 120;
        final double colStatus = width * 0.10 > 90 ? width * 0.10 : 90;
        final double colProg = width * 0.09 > 80 ? width * 0.09 : 80;
        final double colRem = width * 0.18 > 160 ? width * 0.18 : 160;
        final double colDoc = width * 0.12 > 110 ? width * 0.12 : 110;
        final double colAct = width * 0.09 > 80 ? width * 0.09 : 80;

        return Container(
          decoration: BoxDecoration(
            color: isDark ? theme.colorScheme.surface : Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: borderColor),
          ),
          clipBehavior: Clip.antiAlias,
          child: SingleChildScrollView(
            scrollDirection: Axis.vertical,
            physics: const BouncingScrollPhysics(),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              child: IntrinsicWidth(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      color: isDark ? Colors.grey.shade900 : Colors.grey.shade50,
                      height: 48,
                      child: Row(
                        children: [
                          _buildHeaderCell('Project', colProj, Colors.grey.shade700, borderColor),
                          _buildHeaderCell('Responsible Person', colUser, Colors.grey.shade700, borderColor),
                          _buildHeaderCell('Received', colRecv, Colors.grey.shade700, borderColor),
                          _buildHeaderCell('Status', colStatus, Colors.grey.shade700, borderColor),
                          _buildHeaderCell('Progress', colProg, Colors.grey.shade700, borderColor),
                          _buildHeaderCell('Remarks', colRem, Colors.grey.shade700, borderColor),
                          _buildHeaderCell('Documents', colDoc, Colors.grey.shade700, borderColor),
                          _buildHeaderCell('Action', colAct, Colors.grey.shade700, borderColor, isLast: true),
                        ],
                      ),
                    ),
                    const Divider(height: 1, thickness: 1),
                    ...projects.map((project) {
                      final stage = _getProjectStageObj(_selectedDepartment, project);
                      final receivedDate = _getStageReceivedTime(_selectedDepartment, project);
                      final remarks = _getStageLatestRemarks(_selectedDepartment, project);
                      final completedCount = _getCompletedStagesCount(project);
                      final hasPerm = _canUserEditStageAtThisMoment(_selectedDepartment, project, user);

                      final linkedDrawings = drawings.where((d) =>
                        d.drawingName.toLowerCase().contains(project.projectName.toLowerCase()) ||
                        project.projectName.toLowerCase().contains(d.drawingName.toLowerCase())
                      ).toList();

                      return InkWell(
                        onTap: () => context.push('/project-tracker/${project.projectId}'),
                        hoverColor: theme.colorScheme.primary.withOpacity(0.04),
                        child: Container(
                          height: 52,
                          decoration: BoxDecoration(
                            border: Border(bottom: BorderSide(color: borderColor, width: 0.5)),
                          ),
                          child: Row(
                            children: [
                              _buildBodyCell(
                                Text(project.projectName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                                colProj,
                                borderColor,
                                alignment: Alignment.centerLeft,
                                horizontalPadding: 8,
                              ),
                              _buildBodyCell(
                                Text(stage.assignedUser ?? 'Unassigned', style: const TextStyle(fontSize: 12)),
                                colUser,
                                borderColor,
                              ),
                              _buildBodyCell(
                                Text(DateFormat('MMM d, h:mm a').format(receivedDate), style: const TextStyle(fontSize: 11, color: Colors.grey), textAlign: TextAlign.center),
                                colRecv,
                                borderColor,
                              ),
                              _buildBodyCell(
                                _buildStatusBadge(stage.status, _getStatusColor(stage.status == 'Pending' ? 'Planned' : stage.status)),
                                colStatus,
                                borderColor,
                              ),
                              _buildBodyCell(
                                Text('$completedCount/7 Stages', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                                colProg,
                                borderColor,
                              ),
                              _buildBodyCell(
                                Text(remarks.isNotEmpty ? remarks : 'No remarks logged.', style: const TextStyle(fontSize: 11, fontStyle: FontStyle.italic), maxLines: 1, overflow: TextOverflow.ellipsis),
                                colRem,
                                borderColor,
                                alignment: Alignment.centerLeft,
                                horizontalPadding: 8,
                              ),
                              _buildBodyCell(
                                linkedDrawings.isEmpty
                                    ? const Text('None', style: TextStyle(fontSize: 11, color: Colors.grey))
                                    : Row(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        children: linkedDrawings.map((doc) => Tooltip(
                                              message: 'Open ${doc.drawingName}',
                                              child: IconButton(
                                                icon: const Icon(Icons.description_rounded, color: Colors.blue, size: 20),
                                                padding: EdgeInsets.zero,
                                                constraints: const BoxConstraints(),
                                                onPressed: () => _openFileUrl(doc.fileUrl),
                                              ),
                                            )).toList(),
                                      ),
                                colDoc,
                                borderColor,
                              ),
                              _buildBodyCell(
                                hasPerm
                                    ? ElevatedButton(
                                        onPressed: () => _openEditStageDialog(context, project, _selectedDepartment, stage),
                                        style: ElevatedButton.styleFrom(
                                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                          backgroundColor: theme.colorScheme.primary,
                                          foregroundColor: Colors.white,
                                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                                          elevation: 0,
                                          minimumSize: Size.zero,
                                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                        ),
                                        child: const Text('Update', style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold)),
                                      )
                                    : const Row(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        children: [
                                          Icon(Icons.lock_outline_rounded, size: 14, color: Colors.grey),
                                          SizedBox(width: 4),
                                          Text('Locked', style: TextStyle(fontSize: 11, color: Colors.grey)),
                                        ],
                                      ),
                                colAct,
                                borderColor,
                                isLast: true,
                              ),
                            ],
                          ),
                        ),
                      );
                    }),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  // --- 4. DEPARTMENT-LEVEL VIEW - MOBILE ---
  Widget _buildMobileDepartmentCards(
      BuildContext context, List<ProjectModel> projects, List<DrawingModel> drawings, UserModel? user, ThemeData theme, bool isDark) {
    return ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: projects.length,
      itemBuilder: (context, idx) {
        final project = projects[idx];
        final stage = _getProjectStageObj(_selectedDepartment, project);
        final receivedDate = _getStageReceivedTime(_selectedDepartment, project);
        final remarks = _getStageLatestRemarks(_selectedDepartment, project);
        final completedCount = _getCompletedStagesCount(project);
        final hasPerm = _canUserEditStageAtThisMoment(_selectedDepartment, project, user);

        final linkedDrawings = drawings.where((d) =>
          d.drawingName.toLowerCase().contains(project.projectName.toLowerCase()) ||
          project.projectName.toLowerCase().contains(d.drawingName.toLowerCase())
        ).toList();

        final Color stageColor = _getStatusColor(stage.status == 'Pending' ? 'Planned' : stage.status);

        return Card(
          elevation: 0,
          margin: const EdgeInsets.symmetric(vertical: 6),
          color: isDark ? theme.colorScheme.surface : Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(color: isDark ? Colors.grey.shade800 : Colors.grey.shade200),
          ),
          child: InkWell(
            onTap: () => context.push('/project-tracker/${project.projectId}'),
            borderRadius: BorderRadius.circular(12),
            child: Padding(
              padding: const EdgeInsets.all(14.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          project.projectName,
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5),
                        ),
                      ),
                      _buildStatusBadge(stage.status, stageColor),
                    ],
                  ),
                  const Divider(height: 20),
                  _buildMobileInfoRow('Responsible', stage.assignedUser ?? 'Unassigned'),
                  _buildMobileInfoRow('Received', DateFormat('MMM d, h:mm a').format(receivedDate)),
                  _buildMobileInfoRow('Progress', '$completedCount/7 Stages Completed'),
                  if (remarks.isNotEmpty)
                    _buildMobileInfoRow('Remarks', remarks, italicValue: true),
                  if (linkedDrawings.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        const Text('Drawings: ', style: TextStyle(fontSize: 11, color: Colors.grey, fontWeight: FontWeight.bold)),
                        const SizedBox(width: 4),
                        ...linkedDrawings.map((doc) => GestureDetector(
                              onTap: () => _openFileUrl(doc.fileUrl),
                              child: Padding(
                                padding: const EdgeInsets.only(right: 8.0),
                                child: Text(
                                  doc.drawingName.length > 12 ? '${doc.drawingName.substring(0, 10)}...' : doc.drawingName,
                                  style: const TextStyle(color: Colors.blue, fontSize: 11, decoration: TextDecoration.underline),
                                ),
                              ),
                            )),
                      ],
                    ),
                  ],
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      if (hasPerm) ...[
                        ElevatedButton.icon(
                          onPressed: () => _openEditStageDialog(context, project, _selectedDepartment, stage),
                          icon: const Icon(Icons.edit_note_rounded, size: 14, color: Colors.white),
                          label: const Text('Update Stage', style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
                          style: ElevatedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            backgroundColor: theme.colorScheme.primary,
                            elevation: 0,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                        ),
                      ] else ...[
                        const Row(
                          children: [
                            Icon(Icons.lock_outline_rounded, size: 14, color: Colors.grey),
                            const SizedBox(width: 4),
                            Text('Read-Only (Stage Locked)', style: TextStyle(fontSize: 11, color: Colors.grey)),
                          ],
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
    );
  }

  Widget _buildMobileInfoRow(String label, String value, {bool italicValue = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('$label: ', style: const TextStyle(fontSize: 11.5, color: Colors.grey, fontWeight: FontWeight.bold)),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontSize: 11.5,
                fontStyle: italicValue ? FontStyle.italic : FontStyle.normal,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPaginationRow(int totalCount, ThemeData theme, bool isDark) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Column(
        children: [
          Text(
            'Showing $totalCount of $totalCount projects',
            style: const TextStyle(color: Colors.grey, fontSize: 11, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              IconButton(
                icon: const Icon(Icons.chevron_left_rounded, size: 18),
                onPressed: null,
                style: IconButton.styleFrom(
                  padding: EdgeInsets.zero,
                  minimumSize: const Size(32, 32),
                ),
              ),
              const SizedBox(width: 8),
              Container(
                width: 32,
                height: 32,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  border: Border.all(color: theme.colorScheme.primary),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  '1',
                  style: TextStyle(color: theme.colorScheme.primary, fontWeight: FontWeight.bold, fontSize: 12),
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                icon: const Icon(Icons.chevron_right_rounded, size: 18),
                onPressed: null,
                style: IconButton.styleFrom(
                  padding: EdgeInsets.zero,
                  minimumSize: const Size(32, 32),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }



  void _openEditStageDialog(BuildContext context, ProjectModel project, String departmentName, ProjectStage stage) {
    showDialog(
      context: context,
      builder: (ctx) => EditStageDialog(
        project: project,
        departmentName: departmentName,
        stage: stage,
      ),
    );
  }

  Widget _buildStatusBadge(String status, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color, width: 1),
      ),
      child: Text(
        status,
        style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.bold),
      ),
    );
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'Planned':
        return Colors.purple;
      case 'In Progress':
        return Colors.orange;
      case 'Completed':
        return Colors.green;
      case 'On Hold':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  void _confirmDelete(BuildContext context, ProjectModel project, UserModel? user) {
    if (user == null) return;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Project'),
        content: Text('Are you sure you want to permanently delete project "${project.projectName}"? This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.of(ctx).pop();
              try {
                final companyId = project.companyId;
                await ref.read(projectTrackerRepositoryProvider).deleteProject(companyId, project.projectId, user);
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Project deleted successfully.'), backgroundColor: Colors.green),
                  );
                }
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Failed to delete: $e'), backgroundColor: Colors.red),
                  );
                }
              }
            },
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  String _getProjectShortName(String name) {
    final clean = name.replaceAll('Project ', '').trim();
    if (clean.length > 3) {
      return clean.substring(0, 3).toUpperCase();
    }
    return clean.toUpperCase();
  }

  bool _canUserEditStageAtThisMoment(String stageName, ProjectModel project, UserModel? user) {
    if (user == null) return false;
    final bool isManager = user.role == 'Owner' || user.role == 'HR' || user.role == 'Supervisor';
    if (isManager) return true;

    if (project.currentStage != stageName) return false;

    final deptLower = user.department.trim().toLowerCase();
    final stageLower = stageName.trim().toLowerCase();
    if (deptLower == 'accountant' && stageLower == 'accounts') {
      return true;
    }
    return deptLower == stageLower;
  }

  ProjectStage _getProjectStageObj(String stageName, ProjectModel project) {
    final d = stageName.trim().toLowerCase();
    switch (d) {
      case 'marketing': return project.marketingStage;
      case 'design': return project.designStage;
      case 'purchase': return project.purchaseStage;
      case 'machining': return project.machiningStage;
      case 'assembly': return project.assemblyStage;
      case 'quality': return project.qualityStage;
      case 'accounts': return project.accountsStage;
      default: return const ProjectStage(status: 'Pending');
    }
  }

  DateTime _getStageReceivedTime(String stageName, ProjectModel project) {
    try {
      final entries = project.stageHistory.where(
        (e) => e.department.toLowerCase() == stageName.toLowerCase()
      ).toList();
      if (entries.isEmpty) {
        return project.createdAt;
      }
      return entries.first.timestamp;
    } catch (_) {
      return project.createdAt;
    }
  }

  DateTime? _getStageStartTime(String stageName, ProjectModel project) {
    try {
      final entries = project.stageHistory.where(
        (e) => e.department.toLowerCase() == stageName.toLowerCase() && e.status == 'In Progress'
      ).toList();
      if (entries.isEmpty) return null;
      return entries.first.timestamp;
    } catch (_) {
      return null;
    }
  }

  String _getStageLatestRemarks(String stageName, ProjectModel project) {
    try {
      final entries = project.stageHistory.where(
        (e) => e.department.toLowerCase() == stageName.toLowerCase()
      ).toList();
      if (entries.isEmpty) return '';
      return entries.last.remarks;
    } catch (_) {
      return '';
    }
  }

  List<StageHistoryEntry> _getStageHistoryLogs(String stageName, ProjectModel project) {
    try {
      return project.stageHistory.where(
        (e) => e.department.toLowerCase() == stageName.toLowerCase()
      ).toList();
    } catch (_) {
      return [];
    }
  }

  int _getCompletedStagesCount(ProjectModel project) {
    int count = 0;
    if (project.marketingStage.status == 'Completed') count++;
    if (project.designStage.status == 'Completed') count++;
    if (project.purchaseStage.status == 'Completed') count++;
    if (project.machiningStage.status == 'Completed') count++;
    if (project.assemblyStage.status == 'Completed') count++;
    if (project.qualityStage.status == 'Completed') count++;
    if (project.accountsStage.status == 'Completed') count++;
    return count;
  }
}
