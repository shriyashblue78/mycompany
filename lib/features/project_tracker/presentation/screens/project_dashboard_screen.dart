import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:google_fonts/google_fonts.dart';
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
  String _currentView = 'overview'; // 'overview', 'expanded', 'details', 'department'
  String _sidebarSelection = 'Project Tracker'; // 'Dashboard', 'Project Tracker', 'My Work', 'Team', 'Reports'
  ProjectModel? _selectedProject;
  String _activeDepartment = 'Marketing';
  String _statusFilter = 'All';
  String _departmentFilter = 'All';

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
        _activeDepartment = userDeptMapped;
      } else {
        _selectedDepartment = 'All';
        _activeDepartment = 'Marketing';
      }
      _isInitialized = true;
    }

    final projectsAsync = ref.watch(filteredProjectsProvider);
    final drawingsAsync = ref.watch(companyDrawingsStreamProvider);
    final screenWidth = MediaQuery.of(context).size.width;
    final isDesktop = screenWidth >= 850;

    return Theme(
      data: theme.copyWith(
        textTheme: GoogleFonts.ibmPlexMonoTextTheme(theme.textTheme),
      ),
      child: Scaffold(
        body: SafeArea(
          child: _buildMainView(
            context,
            projectsAsync,
            drawingsAsync,
            user,
            role,
            theme,
            isDark,
            isDesktop,
          ),
        ),
      ),
    );
  }



  Widget _buildMainView(
    BuildContext context,
    AsyncValue<List<ProjectModel>> projectsAsync,
    AsyncValue<List<DrawingModel>> drawingsAsync,
    UserModel? user,
    String role,
    ThemeData theme,
    bool isDark,
    bool isDesktop,
  ) {
    return projectsAsync.when(
      loading: () => const Center(child: Padding(
        padding: EdgeInsets.all(32.0),
        child: CircularProgressIndicator(),
      )),
      error: (err, stack) => Center(child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Text('Error loading projects: $err'),
      )),
      data: (projects) {
        final drawings = drawingsAsync.maybeWhen(
          data: (list) => list,
          orElse: () => <DrawingModel>[],
        );

        if (_currentView == 'expanded') {
          return _buildExpandedListView(context, projects, user, role, theme, isDark, isDesktop);
        } else if (_currentView == 'details' && _selectedProject != null) {
          return _buildSimplifiedDetailsView(context, _selectedProject!, user, role, theme, isDark, isDesktop);
        } else if (_currentView == 'department') {
          return _buildDepartmentDetailsView(context, projects, drawings, user, role, theme, isDark, isDesktop);
        } else {
          return _buildOverviewView(context, projects, user, role, theme, isDark, isDesktop);
        }
      },
    );
  }

  Widget _buildOverviewView(
    BuildContext context,
    List<ProjectModel> projects,
    UserModel? user,
    String role,
    ThemeData theme,
    bool isDark,
    bool isDesktop,
  ) {
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.all(AppSizes.p20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          if (!isDesktop) ...[
            Row(
              children: [
                Builder(builder: (ctx) => IconButton(icon: const Icon(Icons.menu), onPressed: () => Scaffold.of(ctx).openDrawer())),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Project Tracker', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                      Text('Track. Manage. Deliver.', style: TextStyle(fontSize: 11, color: Colors.grey.shade600)),
                    ],
                  ),
                ),
                IconButton(
                  tooltip: 'Expanded Project List View',
                  icon: const Icon(Icons.table_rows_rounded, size: 20, color: Colors.grey),
                  onPressed: () {
                    setState(() {
                      _currentView = 'expanded';
                    });
                  },
                ),
                if (role == 'Owner')
                  IconButton(
                    tooltip: 'Add Project',
                    icon: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: const Color(0xFF10B981),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Icon(Icons.add_rounded, size: 16, color: Colors.white),
                    ),
                    onPressed: () => context.push('/project-tracker/create'),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            Container(
              height: 38,
              decoration: BoxDecoration(
                color: isDark ? Colors.grey.shade900 : Colors.grey.shade100,
                borderRadius: BorderRadius.circular(8),
              ),
              child: TextField(
                onChanged: (val) => ref.read(projectSearchQueryProvider.notifier).state = val,
                decoration: const InputDecoration(
                  hintText: 'Search projects...',
                  hintStyle: TextStyle(fontSize: 12, color: Colors.grey),
                  prefixIcon: Icon(Icons.search_rounded, size: 16, color: Colors.grey),
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.symmetric(vertical: 10),
                ),
                style: const TextStyle(fontSize: 12),
              ),
            ),
          ] else ...[
            Row(
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Project Tracker', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 2),
                    Text('Track. Manage. Deliver.', style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
                  ],
                ),
                const Spacer(),
                // Search input
                Container(
                  width: 200,
                  height: 38,
                  decoration: BoxDecoration(
                    color: isDark ? Colors.grey.shade900 : Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: TextField(
                    onChanged: (val) => ref.read(projectSearchQueryProvider.notifier).state = val,
                    decoration: const InputDecoration(
                      hintText: 'Search projects...',
                      hintStyle: TextStyle(fontSize: 12, color: Colors.grey),
                      prefixIcon: Icon(Icons.search_rounded, size: 16, color: Colors.grey),
                      border: InputBorder.none,
                      contentPadding: EdgeInsets.symmetric(vertical: 10),
                    ),
                    style: const TextStyle(fontSize: 12),
                  ),
                ),
                const SizedBox(width: 10),
                // Bell icon
                IconButton(
                  icon: const Icon(Icons.notifications_none_rounded, size: 20, color: Colors.grey),
                  onPressed: () {},
                ),
                const SizedBox(width: 4),
                // Toggle to expanded view
                IconButton(
                  tooltip: 'Expanded Project List View',
                  icon: const Icon(Icons.table_rows_rounded, size: 20, color: Colors.grey),
                  onPressed: () {
                    setState(() {
                      _currentView = 'expanded';
                    });
                  },
                ),
                if (role == 'Owner') ...[
                  const SizedBox(width: 8),
                  ElevatedButton.icon(
                    onPressed: () => context.push('/project-tracker/create'),
                    icon: const Icon(Icons.add_rounded, size: 16, color: Colors.white),
                    label: const Text('Add Project', style: TextStyle(color: Colors.white, fontSize: 12.5, fontWeight: FontWeight.bold)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF10B981),
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      elevation: 0,
                    ),
                  ),
                ],
              ],
            ),
          ],
          const SizedBox(height: 18),
          // 4 Stat Cards
          _buildReferenceStatCards(projects, theme, isDark, isDesktop),
          const SizedBox(height: 16),
          // Department Quick Cards row
          _buildDepartmentQuickCards(projects, theme, isDark),
          const SizedBox(height: 16),
          // Left-side Middle Pagination
          _buildPaginationRow(projects.length, theme, isDark),
          const SizedBox(height: 12),
          // Overview Table
          _buildDesktopTable(context, projects, user, theme, isDark),
        ],
      ),
    );
  }

  Widget _buildReferenceStatCards(List<ProjectModel> projects, ThemeData theme, bool isDark, bool isDesktop) {
    final total = projects.length;
    final active = projects.where((p) => p.status == 'In Progress' || p.status == 'Active').length;
    final now = DateTime.now();
    bool isSameDay(DateTime a, DateTime b) =>
        a.year == b.year && a.month == b.month && a.day == b.day;
    final dueToday = projects.where((p) => p.endDate != null && isSameDay(p.endDate!, now)).length;
    final blocked = projects.where((p) => p.status == 'On Hold' || p.status == 'Blocked' || p.status == 'Attention Required').length;

    final cards = [
      _buildStatCardItem('Total Projects', total.toString(), Icons.folder_rounded, const Color(0xFF3B82F6), theme, isDark),
      _buildStatCardItem('Active', active.toString(), Icons.sync_rounded, const Color(0xFF10B981), theme, isDark),
      _buildStatCardItem('Due Today', dueToday.toString(), Icons.calendar_today_rounded, const Color(0xFFF59E0B), theme, isDark),
      _buildStatCardItem('Blocked', blocked.toString(), Icons.shield_outlined, const Color(0xFFEF4444), theme, isDark),
    ];

    if (!isDesktop) {
      return Column(
        children: [
          Row(
            children: [
              cards[0],
              const SizedBox(width: 10),
              cards[1],
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              cards[2],
              const SizedBox(width: 10),
              cards[3],
            ],
          ),
        ],
      );
    }

    return Row(
      children: [
        cards[0],
        const SizedBox(width: 12),
        cards[1],
        const SizedBox(width: 12),
        cards[2],
        const SizedBox(width: 12),
        cards[3],
      ],
    );
  }

  Widget _buildStatCardItem(String label, String value, IconData icon, Color color, ThemeData theme, bool isDark) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: isDark ? theme.colorScheme.surface : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: isDark ? Colors.grey.shade800 : Colors.grey.shade200),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: color.withOpacity(0.12),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, color: color, size: 20),
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  value,
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, height: 1.1),
                ),
                const SizedBox(height: 2),
                Text(
                  label,
                  style: TextStyle(fontSize: 11, color: Colors.grey.shade600, fontWeight: FontWeight.w500),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDepartmentQuickCards(List<ProjectModel> projects, ThemeData theme, bool isDark) {
    final stages = ProjectTrackerConfig.stages;

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      physics: const BouncingScrollPhysics(),
      child: Row(
        children: stages.map((dept) {
          final deptColor = _getStageIconColor(dept);
          final activeCount = projects.where((p) => p.currentStage.toLowerCase() == dept.toLowerCase() && p.status != 'Completed' && p.status != 'On Hold').length;
          final completedCount = projects.where((p) => _getProjectStageObj(dept, p).status == 'Completed').length;

          return Padding(
            padding: const EdgeInsets.only(right: 10),
            child: InkWell(
              onTap: () {
                setState(() {
                  _activeDepartment = dept;
                  _currentView = 'department';
                });
              },
              borderRadius: BorderRadius.circular(10),
              child: Container(
                width: 140,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: isDark ? theme.colorScheme.surface : Colors.white,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: isDark ? Colors.grey.shade800 : Colors.grey.shade200),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(color: deptColor, shape: BoxShape.circle),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          dept,
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '$activeCount Active | $completedCount Done',
                      style: TextStyle(fontSize: 10.5, color: Colors.grey.shade600),
                    ),
                  ],
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildExpandedListView(
    BuildContext context,
    List<ProjectModel> projects,
    UserModel? user,
    String role,
    ThemeData theme,
    bool isDark,
    bool isDesktop,
  ) {
    final borderColor = isDark ? Colors.grey.shade800 : Colors.grey.shade200;

    var filtered = projects;
    if (_statusFilter != 'All') {
      filtered = filtered.where((p) => p.status == _statusFilter).toList();
    }
    if (_departmentFilter != 'All') {
      filtered = filtered.where((p) => p.currentStage == _departmentFilter).toList();
    }

    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.all(AppSizes.p20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          if (!isDesktop) ...[
            Row(
              children: [
                Builder(builder: (ctx) => IconButton(icon: const Icon(Icons.menu), onPressed: () => Scaffold.of(ctx).openDrawer())),
                InkWell(
                  onTap: () {
                    setState(() {
                      _currentView = 'overview';
                    });
                  },
                  borderRadius: BorderRadius.circular(6),
                  child: Row(
                    children: [
                      Icon(Icons.chevron_left_rounded, size: 20, color: theme.colorScheme.primary),
                      Text('Back', style: TextStyle(color: theme.colorScheme.primary, fontWeight: FontWeight.bold, fontSize: 13.5)),
                    ],
                  ),
                ),
                const Spacer(),
                if (role == 'Owner')
                  IconButton(
                    tooltip: 'Add Project',
                    icon: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: const Color(0xFF10B981),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Icon(Icons.add_rounded, size: 16, color: Colors.white),
                    ),
                    onPressed: () => context.push('/project-tracker/create'),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            Container(
              height: 38,
              decoration: BoxDecoration(
                color: isDark ? Colors.grey.shade900 : Colors.grey.shade100,
                borderRadius: BorderRadius.circular(8),
              ),
              child: TextField(
                onChanged: (val) => ref.read(projectSearchQueryProvider.notifier).state = val,
                decoration: const InputDecoration(
                  hintText: 'Search projects...',
                  hintStyle: TextStyle(fontSize: 12, color: Colors.grey),
                  prefixIcon: Icon(Icons.search_rounded, size: 16, color: Colors.grey),
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.symmetric(vertical: 10),
                ),
                style: const TextStyle(fontSize: 12),
              ),
            ),
          ] else ...[
            Row(
              children: [
                InkWell(
                  onTap: () {
                    setState(() {
                      _currentView = 'overview';
                    });
                  },
                  borderRadius: BorderRadius.circular(6),
                  child: Row(
                    children: [
                      Icon(Icons.chevron_left_rounded, size: 20, color: theme.colorScheme.primary),
                      Text('Project Tracker', style: TextStyle(color: theme.colorScheme.primary, fontWeight: FontWeight.bold, fontSize: 13.5)),
                    ],
                  ),
                ),
                const Spacer(),
                // Search field
                Container(
                  width: 220,
                  height: 38,
                  decoration: BoxDecoration(
                    color: isDark ? Colors.grey.shade900 : Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: TextField(
                    onChanged: (val) => ref.read(projectSearchQueryProvider.notifier).state = val,
                    decoration: const InputDecoration(
                      hintText: 'Search projects...',
                      hintStyle: TextStyle(fontSize: 12, color: Colors.grey),
                      prefixIcon: Icon(Icons.search_rounded, size: 16, color: Colors.grey),
                      border: InputBorder.none,
                      contentPadding: EdgeInsets.symmetric(vertical: 10),
                    ),
                    style: const TextStyle(fontSize: 12),
                  ),
                ),
                const SizedBox(width: 10),
                IconButton(
                  icon: const Icon(Icons.notifications_none_rounded, size: 20, color: Colors.grey),
                  onPressed: () {},
                ),
                if (role == 'Owner') ...[
                  const SizedBox(width: 8),
                  ElevatedButton.icon(
                    onPressed: () => context.push('/project-tracker/create'),
                    icon: const Icon(Icons.add_rounded, size: 16, color: Colors.white),
                    label: const Text('Add Project', style: TextStyle(color: Colors.white, fontSize: 12.5, fontWeight: FontWeight.bold)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF10B981),
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      elevation: 0,
                    ),
                  ),
                ],
              ],
            ),
          ],
          const SizedBox(height: 16),
          // Filter Bar
          if (!isDesktop) ...[
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              child: Row(
                children: [
                  Container(
                    height: 36,
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: borderColor),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: _departmentFilter,
                        items: ['All', ...ProjectTrackerConfig.stages]
                            .map((s) => DropdownMenuItem(value: s, child: Text(s == 'All' ? 'All Departments' : s, style: const TextStyle(fontSize: 12))))
                            .toList(),
                        onChanged: (val) {
                          if (val != null) setState(() => _departmentFilter = val);
                        },
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Container(
                    height: 36,
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: borderColor),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: _statusFilter,
                        items: ['All', 'In Progress', 'Completed', 'Blocked', 'Planned']
                            .map((s) => DropdownMenuItem(value: s, child: Text(s == 'All' ? 'All Status' : s, style: const TextStyle(fontSize: 12))))
                            .toList(),
                        onChanged: (val) {
                          if (val != null) setState(() => _statusFilter = val);
                        },
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              child: Row(
                children: [
                  _buildLegendItem('Completed', Colors.green),
                  const SizedBox(width: 12),
                  _buildLegendItem('In Progress', Colors.orange),
                  const SizedBox(width: 12),
                  _buildLegendItem('Blocked', Colors.red),
                  const SizedBox(width: 12),
                  _buildLegendItem('Not Started', Colors.grey),
                ],
              ),
            ),
          ] else ...[
            Row(
              children: [
                Container(
                  height: 36,
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: borderColor),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: _departmentFilter,
                      items: ['All', ...ProjectTrackerConfig.stages]
                          .map((s) => DropdownMenuItem(value: s, child: Text(s == 'All' ? 'All Departments' : s, style: const TextStyle(fontSize: 12))))
                          .toList(),
                      onChanged: (val) {
                        if (val != null) setState(() => _departmentFilter = val);
                      },
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Container(
                  height: 36,
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: borderColor),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: _statusFilter,
                      items: ['All', 'In Progress', 'Completed', 'Blocked', 'Planned']
                          .map((s) => DropdownMenuItem(value: s, child: Text(s == 'All' ? 'All Status' : s, style: const TextStyle(fontSize: 12))))
                          .toList(),
                      onChanged: (val) {
                        if (val != null) setState(() => _statusFilter = val);
                      },
                    ),
                  ),
                ),
                const Spacer(),
                Row(
                  children: [
                    _buildLegendItem('Completed', Colors.green),
                    const SizedBox(width: 12),
                    _buildLegendItem('In Progress', Colors.orange),
                    const SizedBox(width: 12),
                    _buildLegendItem('Blocked', Colors.red),
                    const SizedBox(width: 12),
                    _buildLegendItem('Not Started', Colors.grey),
                  ],
                ),
              ],
            ),
          ],
          const SizedBox(height: 16),
          _buildExpandedProjectsTable(context, filtered, user, theme, isDark),
        ],
      ),
    );
  }

  Widget _buildLegendItem(String label, Color color) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(width: 7, height: 7, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 5),
        Text(label, style: const TextStyle(fontSize: 11.5, color: Colors.grey, fontWeight: FontWeight.w500)),
      ],
    );
  }

  Widget _buildExpandedProjectsTable(BuildContext context, List<ProjectModel> projects, UserModel? user, ThemeData theme, bool isDark) {
    final Color borderColor = isDark ? Colors.grey.shade800 : Colors.grey.shade200;

    return LayoutBuilder(
      builder: (context, constraints) {
        final double width = constraints.maxWidth < 1100 ? 1100 : constraints.maxWidth;
        final double srWidth = width * 0.04;
        final double projWidth = width * 0.17;
        final double stageWidth = width * 0.095;
        final double statusWidth = width * 0.11;
        final double actionsWidth = width * 0.04;

        return Container(
          decoration: BoxDecoration(
            color: isDark ? theme.colorScheme.surface : Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: borderColor),
          ),
          clipBehavior: Clip.antiAlias,
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
                        _buildHeaderCell('#', srWidth, Colors.grey.shade700, borderColor),
                        _buildHeaderCell('Project', projWidth, Colors.grey.shade700, borderColor),
                        ...ProjectTrackerConfig.stages.map((stg) => _buildHeaderCell(stg, stageWidth, _getStageIconColor(stg), borderColor)),
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
                    final completedCount = _getCompletedStagesCount(project);
                    final percent = completedCount / 7.0;

                    return InkWell(
                      onTap: () {
                        setState(() {
                          _selectedProject = project;
                          _currentView = 'details';
                        });
                      },
                      hoverColor: theme.colorScheme.primary.withOpacity(0.04),
                      child: Container(
                        height: 64,
                        decoration: BoxDecoration(
                          border: Border(bottom: BorderSide(color: borderColor, width: 0.5)),
                        ),
                        child: Row(
                          children: [
                            _buildBodyCell(Text(srNo, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)), srWidth, borderColor),
                            _buildBodyCell(
                              Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(project.projectName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13), maxLines: 1, overflow: TextOverflow.ellipsis),
                                  Text('Created ${DateFormat('dd MMM yyyy').format(project.startDate)}', style: const TextStyle(color: Colors.grey, fontSize: 10.5)),
                                ],
                              ),
                              projWidth,
                              borderColor,
                              alignment: Alignment.centerLeft,
                              horizontalPadding: 8,
                            ),
                            ...ProjectTrackerConfig.stages.map((stg) {
                              final stage = _getProjectStageObj(stg, project);
                              final color = _getStatusColor(stage.status);
                              final hasWork = stage.status != 'Pending';

                              return _buildBodyCell(
                                hasWork
                                    ? Row(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        children: [
                                          Container(width: 6, height: 6, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
                                          const SizedBox(width: 4),
                                          Text(
                                            stage.status == 'Completed' ? 'Done' : 'Active',
                                            style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: color),
                                          ),
                                        ],
                                      )
                                    : const Text('-', style: TextStyle(color: Colors.grey, fontSize: 12)),
                                stageWidth,
                                borderColor,
                              );
                            }),
                            _buildBodyCell(
                              Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                crossAxisAlignment: CrossAxisAlignment.center,
                                children: [
                                  _buildOverallStatusBadge(project.status, _getStatusColor(project.status)),
                                  const SizedBox(height: 4),
                                  SizedBox(
                                    width: 70,
                                    child: ClipRRect(
                                      borderRadius: BorderRadius.circular(3),
                                      child: LinearProgressIndicator(
                                        value: percent,
                                        minHeight: 4,
                                        backgroundColor: isDark ? Colors.grey.shade800 : Colors.grey.shade200,
                                        valueColor: AlwaysStoppedAnimation(Colors.green.shade600),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text('${(percent * 100).toInt()}%', style: const TextStyle(fontSize: 9.5, color: Colors.grey, fontWeight: FontWeight.bold)),
                                ],
                              ),
                              statusWidth,
                              borderColor,
                            ),
                            _buildBodyCell(
                              PopupMenuButton<String>(
                                icon: const Icon(Icons.more_vert_rounded, color: Colors.grey, size: 18),
                                padding: EdgeInsets.zero,
                                onSelected: (val) {
                                  if (val == 'details') {
                                    setState(() {
                                      _selectedProject = project;
                                      _currentView = 'details';
                                    });
                                  } else if (val == 'edit') {
                                    context.push('/project-tracker/${project.projectId}/edit', extra: project);
                                  } else if (val == 'delete') {
                                    _confirmDelete(context, project, user);
                                  }
                                },
                                itemBuilder: (ctx) => [
                                  const PopupMenuItem(value: 'details', child: Text('Open Details')),
                                  const PopupMenuItem(value: 'edit', child: Text('Edit Metadata')),
                                  const PopupMenuItem(value: 'delete', child: Text('Delete Project', style: TextStyle(color: Colors.red))),
                                ],
                              ),
                              actionsWidth,
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
        );
      },
    );
  }

  Widget _buildSimplifiedDetailsView(
    BuildContext context,
    ProjectModel project,
    UserModel? user,
    String role,
    ThemeData theme,
    bool isDark,
    bool isDesktop,
  ) {
    final borderColor = isDark ? Colors.grey.shade800 : Colors.grey.shade200;
    final completedCount = _getCompletedStagesCount(project);
    final percent = completedCount / 7.0;

    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.all(AppSizes.p20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          if (!isDesktop) ...[
            Row(
              children: [
                Builder(builder: (ctx) => IconButton(icon: const Icon(Icons.menu), onPressed: () => Scaffold.of(ctx).openDrawer())),
                InkWell(
                  onTap: () {
                    setState(() {
                      _currentView = 'overview';
                      _selectedProject = null;
                    });
                  },
                  borderRadius: BorderRadius.circular(6),
                  child: Row(
                    children: [
                      Icon(Icons.chevron_left_rounded, size: 22, color: theme.colorScheme.primary),
                      Text('Back', style: TextStyle(color: theme.colorScheme.primary, fontWeight: FontWeight.bold, fontSize: 13)),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    project.projectName,
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 6),
                _buildOverallStatusBadge(project.status, _getStatusColor(project.status)),
                PopupMenuButton<String>(
                  icon: const Icon(Icons.more_vert_rounded, color: Colors.grey, size: 20),
                  padding: EdgeInsets.zero,
                  onSelected: (val) {
                    if (val == 'edit') {
                      context.push('/project-tracker/${project.projectId}/edit', extra: project);
                    } else if (val == 'delete') {
                      _confirmDelete(context, project, user);
                    }
                  },
                  itemBuilder: (ctx) => [
                    const PopupMenuItem(value: 'edit', child: Text('Edit Metadata')),
                    const PopupMenuItem(value: 'delete', child: Text('Delete Project', style: TextStyle(color: Colors.red))),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 12,
              runSpacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.calendar_today_rounded, size: 13, color: Colors.grey),
                    const SizedBox(width: 4),
                    Text(DateFormat('dd MMM yyyy').format(project.startDate), style: const TextStyle(fontSize: 11, color: Colors.grey)),
                  ],
                ),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.access_time_rounded, size: 13, color: Colors.grey),
                    const SizedBox(width: 4),
                    Text(
                      project.endDate != null ? DateFormat('dd MMM yyyy').format(project.endDate!) : 'No Due Date',
                      style: const TextStyle(fontSize: 11, color: Colors.grey),
                    ),
                  ],
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: isDark ? Colors.grey.shade900 : Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: borderColor),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text('Client: ${_getClientName(project)}', style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold)),
                      const SizedBox(width: 6),
                      Container(width: 1, height: 10, color: Colors.grey.shade400),
                      const SizedBox(width: 6),
                      Text('Code: ${_getProjectCode(project)}', style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold, color: theme.colorScheme.primary)),
                    ],
                  ),
                ),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SizedBox(
                      width: 80,
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: percent,
                          minHeight: 6,
                          backgroundColor: isDark ? Colors.grey.shade800 : Colors.grey.shade200,
                          valueColor: AlwaysStoppedAnimation(Colors.green.shade600),
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text('${(percent * 100).toInt()}%', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                  ],
                ),
              ],
            ),
          ] else ...[
            Row(
              children: [
                InkWell(
                  onTap: () {
                    setState(() {
                      _currentView = 'overview';
                      _selectedProject = null;
                    });
                  },
                  borderRadius: BorderRadius.circular(6),
                  child: Row(
                    children: [
                      Icon(Icons.chevron_left_rounded, size: 22, color: theme.colorScheme.primary),
                      Text('Project Tracker', style: TextStyle(color: theme.colorScheme.primary, fontWeight: FontWeight.bold, fontSize: 13)),
                    ],
                  ),
                ),
                const SizedBox(width: 14),
                Text(
                  project.projectName,
                  style: const TextStyle(fontSize: 19, fontWeight: FontWeight.bold),
                ),
                const SizedBox(width: 10),
                _buildOverallStatusBadge(project.status, _getStatusColor(project.status)),
                const Spacer(),
                PopupMenuButton<String>(
                  icon: const Icon(Icons.more_vert_rounded, color: Colors.grey, size: 20),
                  onSelected: (val) {
                    if (val == 'edit') {
                      context.push('/project-tracker/${project.projectId}/edit', extra: project);
                    } else if (val == 'delete') {
                      _confirmDelete(context, project, user);
                    }
                  },
                  itemBuilder: (ctx) => [
                    const PopupMenuItem(value: 'edit', child: Text('Edit Metadata')),
                    const PopupMenuItem(value: 'delete', child: Text('Delete Project', style: TextStyle(color: Colors.red))),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                const Icon(Icons.calendar_today_rounded, size: 14, color: Colors.grey),
                const SizedBox(width: 4),
                Text('Created: ${DateFormat('dd MMM yyyy').format(project.startDate)}', style: const TextStyle(fontSize: 12, color: Colors.grey)),
                const SizedBox(width: 16),
                const Icon(Icons.access_time_rounded, size: 14, color: Colors.grey),
                const SizedBox(width: 4),
                Text(
                  'Due: ${project.endDate != null ? DateFormat('dd MMM yyyy').format(project.endDate!) : 'Not Specified'}',
                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                ),
                const SizedBox(width: 16),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: isDark ? Colors.grey.shade900 : Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: borderColor),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text('Client: ${_getClientName(project)}', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                      const SizedBox(width: 8),
                      Container(width: 1, height: 10, color: Colors.grey.shade400),
                      const SizedBox(width: 8),
                      Text('Code: ${_getProjectCode(project)}', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: theme.colorScheme.primary)),
                    ],
                  ),
                ),
                const Spacer(),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SizedBox(
                      width: 120,
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: percent,
                          minHeight: 8,
                          backgroundColor: isDark ? Colors.grey.shade800 : Colors.grey.shade200,
                          valueColor: AlwaysStoppedAnimation(Colors.green.shade600),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text('${(percent * 100).toInt()}%', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                  ],
                ),
              ],
            ),
          ],
          const SizedBox(height: 18),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            child: Row(
              children: ProjectTrackerConfig.stages.map((stg) {
                final stage = _getProjectStageObj(stg, project);
                final colColor = _getStageIconColor(stg);
                final isCurrent = project.currentStage.toLowerCase() == stg.toLowerCase();
                final status = stage.status;

                return Padding(
                  padding: const EdgeInsets.only(right: 12),
                  child: InkWell(
                    onTap: () {
                      setState(() {
                        _activeDepartment = stg;
                        _currentView = 'department';
                      });
                    },
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      width: 140,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: isCurrent
                            ? (isDark ? colColor.withOpacity(0.12) : const Color(0xFFFFFBEB))
                            : (isDark ? theme.colorScheme.surface : Colors.white),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: isCurrent ? Colors.orange.shade300 : borderColor,
                          width: isCurrent ? 1.5 : 1,
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(6),
                                decoration: BoxDecoration(
                                  color: colColor.withOpacity(0.12),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Icon(_getStageIcon(stg), color: colColor, size: 16),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(stg, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13), overflow: TextOverflow.ellipsis),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          Text(
                            status == 'Completed' ? 'Completed' : (isCurrent ? 'In Progress' : 'Not Started'),
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: status == 'Completed' ? Colors.green : (isCurrent ? Colors.orange.shade800 : Colors.grey),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 20),
          LayoutBuilder(
            builder: (context, constraints) {
              final isNarrow = constraints.maxWidth < 750;
              final currentTaskWidget = Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: isDark ? theme.colorScheme.surface : Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: borderColor),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Current Task', style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: _getStageIconColor(project.currentStage).withOpacity(0.12),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Icon(_getStageIcon(project.currentStage), color: _getStageIconColor(project.currentStage), size: 20),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('${project.currentStage} Task', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                              Text(project.currentStage, style: const TextStyle(color: Colors.grey, fontSize: 11)),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text('Assigned to: ${_getProjectStageObj(project.currentStage, project).assignedUser ?? "Unassigned"}', style: const TextStyle(fontSize: 12)),
                    const SizedBox(height: 4),
                    Text('Due: ${project.endDate != null ? DateFormat('dd MMM yyyy').format(project.endDate!) : "Ongoing"}', style: const TextStyle(fontSize: 12, color: Colors.grey)),
                    const SizedBox(height: 12),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: isDark ? Colors.grey.shade900 : Colors.grey.shade50,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: borderColor),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Latest Update', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11.5)),
                          const SizedBox(height: 4),
                          Text(
                            _getStageLatestRemarks(project.currentStage, project).isNotEmpty
                                ? _getStageLatestRemarks(project.currentStage, project)
                                : 'No remarks logged yet. Waiting for stage progress.',
                            style: const TextStyle(fontSize: 12, height: 1.4),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            DateFormat('dd MMM yyyy - hh:mm a').format(_getStageReceivedTime(project.currentStage, project)),
                            style: const TextStyle(fontSize: 10, color: Colors.grey),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              );

              final quickInfoWidget = Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: isDark ? theme.colorScheme.surface : Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: borderColor),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Quick Info', style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 16),
                    _buildQuickInfoRow('Total Tasks', '7', Colors.blue),
                    const Divider(height: 20),
                    _buildQuickInfoRow('Completed', completedCount.toString(), Colors.green),
                    const Divider(height: 20),
                    _buildQuickInfoRow('In Progress', (7 - completedCount > 0 ? 1 : 0).toString(), Colors.orange),
                    const Divider(height: 20),
                    _buildQuickInfoRow('Blocked', (project.status == 'On Hold' || project.status == 'Blocked' ? 1 : 0).toString(), Colors.red),
                  ],
                ),
              );

              if (isNarrow) {
                return Column(
                  children: [
                    currentTaskWidget,
                    const SizedBox(height: 16),
                    quickInfoWidget,
                  ],
                );
              }

              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(flex: 6, child: currentTaskWidget),
                  const SizedBox(width: 16),
                  Expanded(flex: 4, child: quickInfoWidget),
                ],
              );
            },
          ),
          const SizedBox(height: 20),
          InkWell(
            onTap: () => context.push('/project-tracker/${project.projectId}'),
            borderRadius: BorderRadius.circular(8),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: isDark ? Colors.grey.shade900 : Colors.white,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: borderColor),
              ),
              child: Row(
                children: [
                  Icon(Icons.description_outlined, size: 18, color: theme.colorScheme.primary),
                  const SizedBox(width: 8),
                  Text('View Full Project Details & History', style: TextStyle(color: theme.colorScheme.primary, fontWeight: FontWeight.bold, fontSize: 13)),
                  const Spacer(),
                  Icon(Icons.chevron_right_rounded, size: 18, color: theme.colorScheme.primary),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickInfoRow(String label, String value, Color dotColor) {
    return Row(
      children: [
        Container(width: 8, height: 8, decoration: BoxDecoration(color: dotColor, shape: BoxShape.circle)),
        const SizedBox(width: 8),
        Text(label, style: const TextStyle(fontSize: 13, color: Colors.grey)),
        const Spacer(),
        Text(value, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
      ],
    );
  }

  Widget _buildDepartmentDetailsView(
    BuildContext context,
    List<ProjectModel> projects,
    List<DrawingModel> drawings,
    UserModel? user,
    String role,
    ThemeData theme,
    bool isDark,
    bool isDesktop,
  ) {
    final borderColor = isDark ? Colors.grey.shade800 : Colors.grey.shade200;
    final isManager = role == 'Owner' || role == 'HR' || role == 'Supervisor';
    final userDeptMapped = ProjectTrackerConfig.getStageNameFromDepartment(user?.department ?? '');
    final effectiveDept = isManager ? _activeDepartment : (userDeptMapped.isNotEmpty ? userDeptMapped : _activeDepartment);
    final deptColor = _getStageIconColor(effectiveDept);

    final allDeptTasks = <Map<String, dynamic>>[];
    for (final p in projects) {
      final stage = _getProjectStageObj(effectiveDept, p);
      final receivedTime = _getStageReceivedTime(effectiveDept, p);
      allDeptTasks.add({
        'project': p,
        'stage': stage,
        'receivedTime': receivedTime,
        'status': stage.status,
        'assignedUser': stage.assignedUser ?? 'Unassigned',
        'isCurrent': p.currentStage.toLowerCase() == effectiveDept.toLowerCase(),
      });
    }

    final total = allDeptTasks.length;
    final completed = allDeptTasks.where((t) => t['status'] == 'Completed').length;
    final inProgress = allDeptTasks.where((t) => t['status'] == 'In Progress').length;
    final pending = allDeptTasks.where((t) => t['status'] != 'Completed' && t['status'] != 'In Progress').length;
    final remaining = total - completed;
    final percent = total > 0 ? (completed / total.toDouble()) : 0.0;

    final now = DateTime.now();
    bool isSameDay(DateTime a, DateTime b) =>
        a.year == b.year && a.month == b.month && a.day == b.day;
    final todayCount = allDeptTasks.where((t) => isSameDay(t['receivedTime'] as DateTime, now)).length;

    final assignedEmployee = allDeptTasks.firstWhere(
      (t) => (t['assignedUser'] as String) != 'Unassigned',
      orElse: () => {'assignedUser': user?.name ?? 'Employee'},
    )['assignedUser'] as String;

    final initials = assignedEmployee.trim().isNotEmpty
        ? assignedEmployee.trim().split(' ').map((e) => e.isNotEmpty ? e[0] : '').take(2).join().toUpperCase()
        : 'EM';

    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.all(AppSizes.p20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!isDesktop) ...[
            Row(
              children: [
                Builder(builder: (ctx) => IconButton(icon: const Icon(Icons.menu), onPressed: () => Scaffold.of(ctx).openDrawer())),
                InkWell(
                  onTap: () {
                    setState(() {
                      if (_selectedProject != null) {
                        _currentView = 'details';
                      } else {
                        _currentView = 'overview';
                        _sidebarSelection = 'Project Tracker';
                      }
                    });
                  },
                  borderRadius: BorderRadius.circular(6),
                  child: Row(
                    children: [
                      Icon(Icons.chevron_left_rounded, size: 20, color: theme.colorScheme.primary),
                      Text('Back', style: TextStyle(color: theme.colorScheme.primary, fontWeight: FontWeight.bold, fontSize: 13)),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: deptColor.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Icon(_getStageIcon(effectiveDept), color: deptColor, size: 16),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    effectiveDept,
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (isManager) ...[
                  Container(
                    height: 30,
                    padding: const EdgeInsets.symmetric(horizontal: 6),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: borderColor),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: effectiveDept,
                        items: ProjectTrackerConfig.stages
                            .map((s) => DropdownMenuItem(value: s, child: Text(s, style: const TextStyle(fontSize: 11))))
                            .toList(),
                        onChanged: (val) {
                          if (val != null) setState(() => _activeDepartment = val);
                        },
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ] else ...[
            Row(
              children: [
                InkWell(
                  onTap: () {
                    setState(() {
                      if (_selectedProject != null) {
                        _currentView = 'details';
                      } else {
                        _currentView = 'overview';
                        _sidebarSelection = 'Project Tracker';
                      }
                    });
                  },
                  borderRadius: BorderRadius.circular(6),
                  child: Row(
                    children: [
                      Icon(Icons.chevron_left_rounded, size: 20, color: theme.colorScheme.primary),
                      Text(_selectedProject != null ? _selectedProject!.projectName : 'Project Tracker', style: TextStyle(color: theme.colorScheme.primary, fontWeight: FontWeight.bold, fontSize: 13)),
                    ],
                  ),
                ),
                const SizedBox(width: 14),
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: deptColor.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(_getStageIcon(effectiveDept), color: deptColor, size: 18),
                ),
                const SizedBox(width: 10),
                Text(
                  effectiveDept,
                  style: const TextStyle(fontSize: 19, fontWeight: FontWeight.bold),
                ),
                const SizedBox(width: 10),
                _buildOverallStatusBadge('In Progress', Colors.orange),
                if (isManager) ...[
                  const SizedBox(width: 12),
                  Container(
                    height: 32,
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: borderColor),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: effectiveDept,
                        items: ProjectTrackerConfig.stages
                            .map((s) => DropdownMenuItem(value: s, child: Text(s, style: const TextStyle(fontSize: 12))))
                            .toList(),
                        onChanged: (val) {
                          if (val != null) setState(() => _activeDepartment = val);
                        },
                      ),
                    ),
                  ),
                ],
                const Spacer(),
                OutlinedButton(
                  onPressed: () {
                    setState(() {
                      _currentView = 'overview';
                      _sidebarSelection = 'Project Tracker';
                    });
                  },
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  child: const Text('View All Stages', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                ),
              ],
            ),
          ],
          const SizedBox(height: 6),
          Text(
            'Total Tasks: $total  |  Completed: $completed  |  In Progress: $inProgress  |  Pending: $pending',
            style: const TextStyle(fontSize: 12, color: Colors.grey),
          ),
          const SizedBox(height: 20),
          LayoutBuilder(
            builder: (context, constraints) {
              final isNarrow = constraints.maxWidth < 800;

              final leftTasksSection = Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: isDark ? theme.colorScheme.surface : Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: borderColor),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Text('Tasks', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                        const Spacer(),
                        SizedBox(
                          width: 100,
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(3),
                            child: LinearProgressIndicator(
                              value: percent,
                              minHeight: 6,
                              backgroundColor: isDark ? Colors.grey.shade800 : Colors.grey.shade200,
                              valueColor: AlwaysStoppedAnimation(Colors.green.shade600),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text('$completed/$total', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey)),
                      ],
                    ),
                    const SizedBox(height: 14),
                    const Divider(height: 1),
                    const SizedBox(height: 8),
                    allDeptTasks.isEmpty
                        ? const Padding(
                            padding: EdgeInsets.all(32.0),
                            child: Center(child: Text('No tasks recorded for this department.', style: TextStyle(color: Colors.grey))),
                          )
                        : SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            physics: const BouncingScrollPhysics(),
                            child: ConstrainedBox(
                              constraints: BoxConstraints(minWidth: isNarrow ? 620 : constraints.maxWidth - 50),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Padding(
                                    padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
                                    child: Row(
                                      children: const [
                                        SizedBox(width: 24, child: Text('#', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11.5, color: Colors.grey))),
                                        SizedBox(width: 14),
                                        SizedBox(width: 180, child: Text('Task', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11.5, color: Colors.grey))),
                                        SizedBox(width: 130, child: Text('Assigned to', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11.5, color: Colors.grey))),
                                        SizedBox(width: 110, child: Text('Due Date', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11.5, color: Colors.grey))),
                                        SizedBox(width: 90, child: Text('Status', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11.5, color: Colors.grey), textAlign: TextAlign.center)),
                                        SizedBox(width: 36),
                                      ],
                                    ),
                                  ),
                                  const Divider(height: 1),
                                  ...allDeptTasks.asMap().entries.map((entry) {
                                    final idx = entry.key;
                                    final item = entry.value;
                                    final ProjectModel project = item['project'] as ProjectModel;
                                    final ProjectStage stage = item['stage'] as ProjectStage;
                                    final status = stage.status;
                                    final statusColor = _getStatusColor(status);
                                    final assignedUser = item['assignedUser'] as String;
                                    final srNo = (idx + 1).toString().padLeft(2, '0');

                                    return Container(
                                      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
                                      decoration: BoxDecoration(
                                        border: Border(bottom: BorderSide(color: borderColor.withOpacity(0.4), width: 0.5)),
                                      ),
                                      child: Row(
                                        children: [
                                          SizedBox(width: 24, child: Text(srNo, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey))),
                                          const SizedBox(width: 14),
                                          SizedBox(
                                            width: 180,
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  '$effectiveDept - ${project.projectName}',
                                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                                                  maxLines: 1,
                                                  overflow: TextOverflow.ellipsis,
                                                ),
                                                const SizedBox(height: 2),
                                                Text('Code: ${_getProjectCode(project)}', style: const TextStyle(fontSize: 11, color: Colors.grey)),
                                              ],
                                            ),
                                          ),
                                          SizedBox(
                                            width: 130,
                                            child: Row(
                                              children: [
                                                const Icon(Icons.person_outline_rounded, size: 14, color: Colors.grey),
                                                const SizedBox(width: 4),
                                                Expanded(
                                                  child: Text(assignedUser, style: const TextStyle(fontSize: 12), maxLines: 1, overflow: TextOverflow.ellipsis),
                                                ),
                                              ],
                                            ),
                                          ),
                                          SizedBox(
                                            width: 110,
                                            child: Text(
                                              stage.completedAt != null
                                                  ? DateFormat('dd MMM yyyy').format(stage.completedAt!)
                                                  : DateFormat('dd MMM yyyy').format(item['receivedTime'] as DateTime),
                                              style: const TextStyle(fontSize: 11.5, color: Colors.grey),
                                            ),
                                          ),
                                          SizedBox(
                                            width: 90,
                                            child: Center(child: _buildOverallStatusBadge(status, statusColor)),
                                          ),
                                          const SizedBox(width: 8),
                                          IconButton(
                                            icon: const Icon(Icons.edit_note_rounded, size: 18, color: Colors.blue),
                                            onPressed: () => _openEditStageDialog(context, project, effectiveDept, stage),
                                            tooltip: 'Update Status',
                                          ),
                                        ],
                                      ),
                                    );
                                  }),
                                ],
                              ),
                            ),
                          ),
                  ],
                ),
              );

              final rightSidebarSection = Column(
                children: [
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      color: isDark ? theme.colorScheme.surface : Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: borderColor),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Align(
                          alignment: Alignment.centerLeft,
                          child: Text('Stage Progress', style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold)),
                        ),
                        const SizedBox(height: 18),
                        Stack(
                          alignment: Alignment.center,
                          children: [
                            SizedBox(
                              width: 86,
                              height: 86,
                              child: CircularProgressIndicator(
                                value: percent,
                                strokeWidth: 8,
                                backgroundColor: isDark ? Colors.grey.shade800 : Colors.grey.shade200,
                                valueColor: AlwaysStoppedAnimation<Color>(const Color(0xFF10B981)),
                              ),
                            ),
                            Text(
                              '${(percent * 100).toInt()}%',
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 19),
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),
                        Text('$completed/$total Completed', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5)),
                        const SizedBox(height: 2),
                        Text('$remaining Tasks Remaining', style: const TextStyle(fontSize: 11.5, color: Colors.grey)),
                        const SizedBox(height: 10),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.blue.withOpacity(0.08),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text('$todayCount Due Today', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.blue)),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      color: isDark ? theme.colorScheme.surface : Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: borderColor),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Stage Owner', style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold)),
                        const SizedBox(height: 14),
                        Row(
                          children: [
                            CircleAvatar(
                              radius: 20,
                              backgroundColor: Colors.blue.shade900,
                              child: Text(initials, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12.5)),
                            ),
                            const SizedBox(width: 12),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(assignedEmployee, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5)),
                                const SizedBox(height: 2),
                                Text('$effectiveDept Lead', style: const TextStyle(color: Colors.grey, fontSize: 11)),
                              ],
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      color: isDark ? theme.colorScheme.surface : Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: borderColor),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Quick Actions', style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold)),
                        const SizedBox(height: 12),
                        InkWell(
                          onTap: () {
                            setState(() {
                              _currentView = 'overview';
                              _sidebarSelection = 'Project Tracker';
                            });
                          },
                          child: Row(
                            children: [
                              Text('View All Tasks', style: TextStyle(fontSize: 12.5, color: theme.colorScheme.primary, fontWeight: FontWeight.bold)),
                              const Spacer(),
                              Icon(Icons.chevron_right_rounded, size: 18, color: theme.colorScheme.primary),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              );

              if (isNarrow) {
                return Column(
                  children: [
                    leftTasksSection,
                    const SizedBox(height: 16),
                    rightSidebarSection,
                  ],
                );
              }

              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(flex: 7, child: leftTasksSection),
                  const SizedBox(width: 16),
                  Expanded(flex: 3, child: rightSidebarSection),
                ],
              );
            },
          ),
        ],
      ),
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
        final double projWidth = baseWidth * 0.17;
        final double stageWidth = baseWidth * 0.095;
        final double statusWidth = baseWidth * 0.085;
        final double actionsWidth = baseWidth * 0.04;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              decoration: BoxDecoration(
                color: isDark ? theme.colorScheme.surface : Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: borderColor),
              ),
              clipBehavior: Clip.antiAlias,
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                physics: const BouncingScrollPhysics(),
                child: IntrinsicWidth(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // STICKY LOCKED HEADER ROW
                      Container(
                        color: isDark ? Colors.grey.shade900 : const Color(0xFFF8FAFC),
                        height: 52,
                        child: Row(
                          children: [
                            _buildHeaderCell('#', srWidth, Colors.grey.shade700, borderColor),
                            _buildHeaderCell('Project', projWidth, Colors.grey.shade700, borderColor, alignment: Alignment.centerLeft, horizontalPadding: 12),
                            _buildDepartmentHeaderCell('Marketing', stageWidth, _getStageIconColor('Marketing'), borderColor, projects),
                            _buildDepartmentHeaderCell('Design', stageWidth, _getStageIconColor('Design'), borderColor, projects),
                            _buildDepartmentHeaderCell('Purchase', stageWidth, _getStageIconColor('Purchase'), borderColor, projects),
                            _buildDepartmentHeaderCell('Machining', stageWidth, _getStageIconColor('Machining'), borderColor, projects),
                            _buildDepartmentHeaderCell('Assembly', stageWidth, _getStageIconColor('Assembly'), borderColor, projects),
                            _buildDepartmentHeaderCell('Quality', stageWidth, _getStageIconColor('Quality'), borderColor, projects),
                            _buildDepartmentHeaderCell('Accounts', stageWidth, _getStageIconColor('Accounts'), borderColor, projects),
                            _buildHeaderCell('Status', statusWidth, Colors.grey.shade700, borderColor),
                            _buildHeaderCell('Actions', actionsWidth, Colors.grey.shade700, borderColor, isLast: true),
                          ],
                        ),
                      ),
                      const Divider(height: 1, thickness: 1),
                      // SCROLLABLE PROJECT ROWS (Locked Header remains visible above)
                      ConstrainedBox(
                        constraints: BoxConstraints(
                          maxHeight: (projects.length * 68.0).clamp(100.0, 520.0),
                        ),
                        child: SingleChildScrollView(
                          scrollDirection: Axis.vertical,
                          physics: const BouncingScrollPhysics(),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: projects.asMap().entries.map((entry) {
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
                                        _selectedProject = project;
                                        _currentView = 'details';
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
                                            Column(
                                              mainAxisAlignment: MainAxisAlignment.center,
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  project.projectName,
                                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5),
                                                  maxLines: 1,
                                                  overflow: TextOverflow.ellipsis,
                                                ),
                                                const SizedBox(height: 3),
                                                Text(
                                                  'Created ${DateFormat('dd MMM yyyy').format(project.startDate)}',
                                                  style: TextStyle(color: Colors.grey.shade600, fontSize: 10.5),
                                                ),
                                              ],
                                            ),
                                            projWidth,
                                            borderColor,
                                            alignment: Alignment.centerLeft,
                                            horizontalPadding: 12,
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
                            }).toList(),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
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
              // Client / Code info corner
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  color: isDark ? Colors.grey.shade800.withOpacity(0.5) : Colors.white,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: isDark ? Colors.grey.shade700 : Colors.grey.shade300),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.business_rounded, size: 16, color: Colors.grey),
                    const SizedBox(width: 6),
                    Text(
                      'Client: ',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey.shade700),
                    ),
                    Text(
                      _getClientName(project),
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(width: 16),
                    Container(width: 1, height: 14, color: Colors.grey.shade400),
                    const SizedBox(width: 16),
                    const Icon(Icons.tag_rounded, size: 16, color: Colors.grey),
                    const SizedBox(width: 4),
                    Text(
                      'Code: ',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey.shade700),
                    ),
                    Text(
                      _getProjectCode(project),
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: theme.colorScheme.primary),
                    ),
                  ],
                ),
              ),
            ],
          ),
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

  Widget _buildDepartmentHeaderCell(String text, double width, Color textColor, Color borderColor, List<ProjectModel> projects, {bool isLast = false}) {
    return Container(
      width: width,
      height: 52,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        border: Border(
          right: isLast ? BorderSide.none : BorderSide(color: borderColor, width: 0.5),
        ),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          InkWell(
            onTap: () {
              setState(() {
                _activeDepartment = text;
                _currentView = 'department';
              });
            },
            child: Text(
              text,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 12.5,
                color: textColor,
              ),
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(height: 3),
          InkWell(
            onTap: () {
              setState(() {
                _activeDepartment = text;
                _currentView = 'department';
              });
            },
            borderRadius: BorderRadius.circular(4),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
              decoration: BoxDecoration(
                color: textColor.withOpacity(0.12),
                borderRadius: BorderRadius.circular(4),
                border: Border.all(color: textColor.withOpacity(0.3), width: 0.5),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.person_pin_rounded, size: 9, color: textColor),
                  const SizedBox(width: 2),
                  Text(
                    'My Work',
                    style: TextStyle(fontSize: 8.5, fontWeight: FontWeight.bold, color: textColor),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showMyWorkModal(BuildContext context, String department, List<ProjectModel> projects) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final deptColor = _getStageIconColor(department);

    // Extract task items for this department across projects
    final allDeptTasks = <Map<String, dynamic>>[];
    for (final p in projects) {
      final stage = _getProjectStageObj(department, p);
      final receivedTime = _getStageReceivedTime(department, p);
      allDeptTasks.add({
        'project': p,
        'stage': stage,
        'receivedTime': receivedTime,
        'status': stage.status,
        'assignedUser': stage.assignedUser ?? 'Unassigned',
        'isCurrent': p.currentStage.toLowerCase() == department.toLowerCase(),
      });
    }

    final today = DateTime.now();
    bool isSameDay(DateTime a, DateTime b) =>
        a.year == b.year && a.month == b.month && a.day == b.day;

    final todayTasks = allDeptTasks.where((t) {
      final dt = t['receivedTime'] as DateTime;
      return isSameDay(dt, today);
    }).toList();

    final completedTasks = allDeptTasks.where((t) => t['status'] == 'Completed').toList();
    final pendingTasks = allDeptTasks.where((t) => t['status'] != 'Completed').toList();
    final currentTasks = allDeptTasks.where((t) => t['isCurrent'] == true && t['status'] != 'Completed').toList();

    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
        child: LayoutBuilder(
          builder: (context, modalConstraints) {
            final isMobileModal = modalConstraints.maxWidth < 600;

            return Container(
              width: 720,
              constraints: const BoxConstraints(maxHeight: 640),
              padding: EdgeInsets.all(isMobileModal ? 14 : 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: deptColor.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(_getStageIcon(department), color: deptColor, size: isMobileModal ? 18 : 22),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '$department — My Work',
                              style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold, fontSize: isMobileModal ? 14 : 16),
                            ),
                            Text(
                              'Tasks & stage progress for $department',
                              style: const TextStyle(fontSize: 11, color: Colors.grey),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close_rounded),
                        onPressed: () => Navigator.of(ctx).pop(),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  // Compact summary row
                  if (isMobileModal) ...[
                    Row(
                      children: [
                        _buildMyWorkSummaryChip('Today', todayTasks.length.toString(), Colors.blue),
                        const SizedBox(width: 6),
                        _buildMyWorkSummaryChip('Active', currentTasks.length.toString(), Colors.orange),
                        const SizedBox(width: 6),
                        _buildMyWorkSummaryChip('Pending', pendingTasks.length.toString(), Colors.grey.shade700),
                        const SizedBox(width: 6),
                        _buildMyWorkSummaryChip('Done', completedTasks.length.toString(), Colors.green),
                      ],
                    ),
                  ] else ...[
                    Row(
                      children: [
                        _buildMyWorkSummaryChip('Today\'s Tasks', todayTasks.length.toString(), Colors.blue),
                        const SizedBox(width: 8),
                        _buildMyWorkSummaryChip('Current Active', currentTasks.length.toString(), Colors.orange),
                        const SizedBox(width: 8),
                        _buildMyWorkSummaryChip('Pending', pendingTasks.length.toString(), Colors.grey.shade700),
                        const SizedBox(width: 8),
                        _buildMyWorkSummaryChip('Completed', completedTasks.length.toString(), Colors.green),
                      ],
                    ),
                  ],
                  const SizedBox(height: 14),
                  const Divider(height: 1),
                  const SizedBox(height: 10),
                  // Task list
                  Expanded(
                    child: allDeptTasks.isEmpty
                        ? const Center(
                            child: Text('No tasks found for this department.', style: TextStyle(color: Colors.grey)),
                          )
                        : ListView.separated(
                            shrinkWrap: true,
                            itemCount: allDeptTasks.length,
                            separatorBuilder: (_, __) => const SizedBox(height: 8),
                            itemBuilder: (context, idx) {
                              final item = allDeptTasks[idx];
                              final ProjectModel project = item['project'] as ProjectModel;
                              final ProjectStage stage = item['stage'] as ProjectStage;
                              final status = stage.status;
                              final assignedUser = item['assignedUser'] as String;
                              final isCurrent = item['isCurrent'] as bool;
                              final statusColor = _getStatusColor(status);

                              if (isMobileModal) {
                                return Container(
                                  padding: const EdgeInsets.all(10),
                                  decoration: BoxDecoration(
                                    color: isDark ? Colors.grey.shade900 : Colors.grey.shade50,
                                    borderRadius: BorderRadius.circular(10),
                                    border: Border.all(
                                      color: isCurrent
                                          ? deptColor.withOpacity(0.5)
                                          : (isDark ? Colors.grey.shade800 : Colors.grey.shade200),
                                      width: isCurrent ? 1.5 : 1,
                                    ),
                                  ),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          if (isCurrent)
                                            Container(
                                              margin: const EdgeInsets.only(right: 6),
                                              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                                              decoration: BoxDecoration(
                                                color: Colors.orange.withOpacity(0.15),
                                                borderRadius: BorderRadius.circular(4),
                                              ),
                                              child: const Text('Current', style: TextStyle(fontSize: 8.5, fontWeight: FontWeight.bold, color: Colors.orange)),
                                            ),
                                          Expanded(
                                            child: Text(
                                              project.projectName,
                                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                            decoration: BoxDecoration(
                                              color: statusColor.withOpacity(0.12),
                                              borderRadius: BorderRadius.circular(8),
                                              border: Border.all(color: statusColor, width: 0.8),
                                            ),
                                            child: Text(
                                              status,
                                              style: TextStyle(color: statusColor, fontSize: 10, fontWeight: FontWeight.bold),
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 6),
                                      Row(
                                        children: [
                                          Text('Code: ${_getProjectCode(project)}', style: const TextStyle(fontSize: 10.5, color: Colors.grey)),
                                          const Spacer(),
                                          const Icon(Icons.person_outline_rounded, size: 12, color: Colors.grey),
                                          const SizedBox(width: 3),
                                          Text(assignedUser, style: const TextStyle(fontSize: 10.5, color: Colors.grey)),
                                          const SizedBox(width: 8),
                                          Text(
                                            stage.completedAt != null
                                                ? 'Done: ${DateFormat('dd/MM').format(stage.completedAt!)}'
                                                : 'Recv: ${DateFormat('dd/MM').format(item['receivedTime'] as DateTime)}',
                                            style: const TextStyle(fontSize: 10.5, color: Colors.grey),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                );
                              }

                              return Container(
                                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                                decoration: BoxDecoration(
                                  color: isDark ? Colors.grey.shade900 : Colors.grey.shade50,
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(
                                    color: isCurrent
                                        ? deptColor.withOpacity(0.5)
                                        : (isDark ? Colors.grey.shade800 : Colors.grey.shade200),
                                    width: isCurrent ? 1.5 : 1,
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    if (isCurrent)
                                      Container(
                                        margin: const EdgeInsets.only(right: 10),
                                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: Colors.orange.withOpacity(0.15),
                                          borderRadius: BorderRadius.circular(4),
                                        ),
                                        child: const Text(
                                          'Current Task',
                                          style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Colors.orange),
                                        ),
                                      ),
                                    Expanded(
                                      flex: 3,
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            project.projectName,
                                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                          const SizedBox(height: 2),
                                          Text(
                                            'Code: ${_getProjectCode(project)}',
                                            style: const TextStyle(fontSize: 11, color: Colors.grey),
                                          ),
                                        ],
                                      ),
                                    ),
                                    Expanded(
                                      flex: 2,
                                      child: Row(
                                        children: [
                                          const Icon(Icons.person_outline_rounded, size: 14, color: Colors.grey),
                                          const SizedBox(width: 4),
                                          Expanded(
                                            child: Text(
                                              assignedUser,
                                              style: const TextStyle(fontSize: 12),
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    Expanded(
                                      flex: 2,
                                      child: Text(
                                        stage.completedAt != null
                                            ? 'Done: ${DateFormat('dd/MM/yy').format(stage.completedAt!)}'
                                            : 'Recv: ${DateFormat('dd/MM/yy').format(item['receivedTime'] as DateTime)}',
                                        style: const TextStyle(fontSize: 11, color: Colors.grey),
                                        textAlign: TextAlign.center,
                                      ),
                                    ),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: statusColor.withOpacity(0.12),
                                        borderRadius: BorderRadius.circular(12),
                                        border: Border.all(color: statusColor, width: 1),
                                      ),
                                      child: Text(
                                        status,
                                        style: TextStyle(color: statusColor, fontSize: 11, fontWeight: FontWeight.bold),
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildPaginationRow(int totalProjects, ThemeData theme, bool isDark) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            color: isDark ? Colors.grey.shade900 : Colors.grey.shade100,
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: isDark ? Colors.grey.shade800 : Colors.grey.shade300),
          ),
          child: Text(
            'Showing 1-$totalProjects of $totalProjects',
            style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: Colors.grey),
          ),
        ),
        const SizedBox(width: 8),
        IconButton(
          icon: const Icon(Icons.chevron_left_rounded, size: 18),
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
          onPressed: null,
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: theme.colorScheme.primary,
            borderRadius: BorderRadius.circular(4),
          ),
          child: const Text('1', style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
        ),
        IconButton(
          icon: const Icon(Icons.chevron_right_rounded, size: 18),
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
          onPressed: null,
        ),
      ],
    );
  }

  Widget _buildMyWorkSummaryChip(String label, String value, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 10),
        decoration: BoxDecoration(
          color: color.withOpacity(0.08),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: color.withOpacity(0.25)),
        ),
        child: Column(
          children: [
            Text(value, style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: color)),
            const SizedBox(height: 2),
            Text(label, style: TextStyle(fontSize: 10.5, color: color, fontWeight: FontWeight.w600), maxLines: 1, overflow: TextOverflow.ellipsis),
          ],
        ),
      ),
    );
  }

  Widget _buildHeaderCell(String text, double width, Color textColor, Color borderColor,
      {bool isLast = false, Alignment alignment = Alignment.center, double horizontalPadding = 0}) {
    return Container(
      width: width,
      height: 52,
      padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
      alignment: alignment,
      decoration: BoxDecoration(
        border: Border(
          right: isLast ? BorderSide.none : BorderSide(color: borderColor, width: 0.5),
        ),
      ),
      child: Text(
        text,
        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: textColor),
        textAlign: alignment == Alignment.centerLeft ? TextAlign.left : TextAlign.center,
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
    return Container(
      width: double.infinity,
      height: double.infinity,
      alignment: Alignment.center,
      child: _buildStageStatusView(stage, stageName, project, isDark),
    );
  }

  Widget _buildStageStatusView(ProjectStage stage, String stageName, ProjectModel project, bool isDark) {
    final bool isCompleted = stage.status == 'Completed';
    final bool isInProgress = stage.status == 'In Progress' || project.currentStage.toLowerCase() == stageName.toLowerCase();
    final Color dotColor = _getStatusColor(stage.status);
    final String remarks = _getStageLatestRemarks(stageName, project);
    final String taskLabel = remarks.isNotEmpty
        ? remarks
        : (isCompleted
            ? (stage.completedAt != null ? DateFormat('dd/MM').format(stage.completedAt!) : 'Completed')
            : stage.status);
    final String assignee = (stage.assignedUser != null && stage.assignedUser!.isNotEmpty)
        ? stage.assignedUser!
        : '-';

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (isCompleted)
                const Icon(Icons.check_circle_rounded, color: Colors.green, size: 14)
              else if (isInProgress)
                Container(
                  width: 7,
                  height: 7,
                  decoration: BoxDecoration(color: dotColor, shape: BoxShape.circle),
                )
              else
                Icon(Icons.access_time_rounded, color: Colors.grey.shade400, size: 13),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  taskLabel,
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 11.5,
                    color: isCompleted
                        ? Colors.green
                        : (isInProgress ? (dotColor == Colors.grey ? Colors.orange.shade700 : dotColor) : Colors.grey.shade600),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 2),
          Padding(
            padding: const EdgeInsets.only(left: 11),
            child: Text(
              assignee,
              style: TextStyle(color: Colors.grey.shade600, fontSize: 10.5),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
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
      case 'Completed':
      case 'Finished':
        return Colors.green;
      case 'In Progress':
      case 'Active':
        return Colors.orange;
      case 'On Hold':
      case 'Blocked':
      case 'Delayed':
      case 'Attention Required':
      case 'Rejected':
        return Colors.red;
      case 'Planned':
      case 'Not Started':
      case 'Pending':
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
