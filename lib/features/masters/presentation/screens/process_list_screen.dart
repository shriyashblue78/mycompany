import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_sizes.dart';
import '../../../../core/widgets/erp_drawer.dart';
import '../../../../core/widgets/polish_widgets.dart';
import '../../../../core/widgets/responsive_layout.dart';
import '../../../../core/widgets/responsive_widgets.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../domain/models/process_model.dart';
import '../providers/hsn_sac_provider.dart';
import '../providers/process_provider.dart';

class ProcessListScreen extends ConsumerStatefulWidget {
  const ProcessListScreen({super.key});

  @override
  ConsumerState<ProcessListScreen> createState() => _ProcessListScreenState();
}

class _ProcessListScreenState extends ConsumerState<ProcessListScreen> {
  @override
  Widget build(BuildContext context) {
    final listAsync = ref.watch(filteredProcessesProvider);
    final hsnSacListAsync = ref.watch(companyHsnSacStreamProvider);
    final authState = ref.watch(authProvider);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final isMobile = ResponsiveLayout.isMobile(context);

    final role = authState.selectedRole ?? 'Employee';
    final canManage = role == 'Owner' || role == 'Accountant';
    final companyId = authState.user?.companyId ?? '';
    final hsnSacList = hsnSacListAsync.valueOrNull ?? [];

    final appBar = AppBar(
      title: const Text(
        'Process Master',
        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
      ),
      elevation: 0,
    );

    return listAsync.when(
      data: (processes) {
        final body = RefreshIndicator(
          onRefresh: () async {
            ref.invalidate(companyProcessesStreamProvider);
          },
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: EdgeInsets.symmetric(
              horizontal: isMobile ? AppSizes.p12 : AppSizes.p24,
              vertical: isMobile ? AppSizes.p12 : AppSizes.p16,
            ),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1200),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Top Bar: Search & Action Header
                    _buildHeaderBar(context, companyId, hsnSacList, canManage, theme, isDark, isMobile, processes.length),
                    const SizedBox(height: AppSizes.p12),
                    if (processes.isEmpty)
                      EmptyStateWidget(
                        icon: Icons.alt_route_rounded,
                        title: 'No Processes Found',
                        description: ref.watch(processSearchQueryProvider).isNotEmpty
                            ? 'No manufacturing processes match your search query.'
                            : 'Configure production operations, CNC, VMC, Turning, and Assembly stages.',
                      )
                    else if (isMobile)
                      _buildMobileProcessList(
                        context: context,
                        processes: processes,
                        hsnSacList: hsnSacList,
                        canManage: canManage,
                        companyId: companyId,
                        theme: theme,
                        isDark: isDark,
                      )
                    else
                      _buildProcessDataTable(
                        context: context,
                        processes: processes,
                        hsnSacList: hsnSacList,
                        canManage: canManage,
                        companyId: companyId,
                        theme: theme,
                        isDark: isDark,
                        isMobile: isMobile,
                      ),
                  ],
                ),
              ),
            ),
          ),
        );

        return ResponsiveScaffold(
          appBar: appBar,
          drawer: const ERPDrawer(),
          body: body,
        );
      },
      loading: () => ResponsiveScaffold(
        appBar: appBar,
        drawer: const ERPDrawer(),
        body: const Center(child: CardListSkeleton()),
      ),
      error: (err, _) => ResponsiveScaffold(
        appBar: appBar,
        drawer: const ERPDrawer(),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(AppSizes.p24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.error_outline_rounded, color: AppColors.error, size: 48),
                const SizedBox(height: 12),
                Text('Error loading processes: $err'),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: () => ref.invalidate(companyProcessesStreamProvider),
                  child: const Text('Retry'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeaderBar(
    BuildContext context,
    String companyId,
    List<dynamic> hsnSacList,
    bool canManage,
    ThemeData theme,
    bool isDark,
    bool isMobile,
    int count,
  ) {
    final borderColor = isDark ? AppColors.borderDark : AppColors.borderLight;
    final surfaceColor = isDark ? AppColors.surfaceDark : AppColors.surfaceLight;

    return Container(
      padding: EdgeInsets.symmetric(horizontal: isMobile ? 12 : 16, vertical: 10),
      decoration: BoxDecoration(
        color: surfaceColor,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: borderColor),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 4,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Wrap(
        alignment: WrapAlignment.spaceBetween,
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: 12,
        runSpacing: 10,
        children: [
          // Search input box
          ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: isMobile ? double.infinity : 400,
              minWidth: isMobile ? double.infinity : 280,
            ),
            child: SizedBox(
              height: 42,
              child: TextField(
                onChanged: (val) => ref.read(processSearchQueryProvider.notifier).state = val,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: isDark ? Colors.white : const Color(0xFF111827),
                ),
                decoration: InputDecoration(
                  hintText: 'Search by Process Name or SAC...',
                  hintStyle: TextStyle(
                    fontSize: 13.5,
                    color: isDark ? Colors.white54 : const Color(0xFF6B7280),
                  ),
                  prefixIcon: Icon(
                    Icons.search_rounded,
                    size: 20,
                    color: isDark ? Colors.white70 : const Color(0xFF4B5563),
                  ),
                  suffixIcon: ref.watch(processSearchQueryProvider).isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear_rounded, size: 18),
                          splashRadius: 18,
                          onPressed: () => ref.read(processSearchQueryProvider.notifier).state = '',
                        )
                      : null,
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  filled: true,
                  fillColor: isDark ? Colors.grey.shade900 : const Color(0xFFF9FAFB),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(6),
                    borderSide: BorderSide(color: borderColor),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(6),
                    borderSide: BorderSide(color: borderColor),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(6),
                    borderSide: BorderSide(
                      color: isDark ? AppColors.accentDark : AppColors.primaryLight,
                      width: 1.3,
                    ),
                  ),
                ),
              ),
            ),
          ),

          // Total count badge and New Process action button
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                decoration: BoxDecoration(
                  color: isDark ? Colors.grey.shade800 : const Color(0xFFF3F4F6),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: borderColor),
                ),
                child: Text(
                  'Total: $count',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: isDark ? Colors.white : const Color(0xFF1F2937),
                  ),
                ),
              ),
              if (canManage) ...[
                const SizedBox(width: 10),
                SizedBox(
                  height: 40,
                  child: ElevatedButton.icon(
                    onPressed: () => _openProcessDialog(context, companyId, hsnSacList: hsnSacList),
                    icon: const Icon(Icons.add_rounded, size: 18),
                    label: const Text(
                      'New Process',
                      style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: isDark ? AppColors.primaryDark : AppColors.primaryLight,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(6),
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMobileProcessList({
    required BuildContext context,
    required List<ProcessModel> processes,
    required List<dynamic> hsnSacList,
    required bool canManage,
    required String companyId,
    required ThemeData theme,
    required bool isDark,
  }) {
    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: processes.length,
      separatorBuilder: (_, _) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        final process = processes[index];
        return _buildMobileProcessCard(
          context: context,
          index: index,
          process: process,
          hsnSacList: hsnSacList,
          canManage: canManage,
          companyId: companyId,
          theme: theme,
          isDark: isDark,
        );
      },
    );
  }

  Widget _buildMobileProcessCard({
    required BuildContext context,
    required int index,
    required ProcessModel process,
    required List<dynamic> hsnSacList,
    required bool canManage,
    required String companyId,
    required ThemeData theme,
    required bool isDark,
  }) {
    final borderColor = isDark ? AppColors.borderDark : const Color(0xFFE5E7EB);
    final cardBgColor = isDark ? AppColors.surfaceDark : Colors.white;

    return Material(
      color: cardBgColor,
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: () => _viewProcessDetails(context, process),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: borderColor),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(isDark ? 0.15 : 0.03),
                blurRadius: 4,
                offset: const Offset(0, 1),
              ),
            ],
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Index badge / Icon
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: const Color(0xFF6366F1).withOpacity(isDark ? 0.22 : 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Center(
                  child: Text(
                    '${index + 1}',
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                      color: isDark ? const Color(0xFFA5B4FC) : const Color(0xFF4F46E5),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),

              // Title, SAC, Assembly badge in compact layout
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      process.processName,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: isDark ? Colors.white : const Color(0xFF111827),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 5),
                    Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        // SAC Tag
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: isDark ? Colors.grey.shade800 : const Color(0xFFF3F4F6),
                            borderRadius: BorderRadius.circular(4),
                            border: Border.all(
                              color: isDark ? Colors.grey.shade700 : const Color(0xFFE5E7EB),
                            ),
                          ),
                          child: Text(
                            process.sac != null && process.sac!.isNotEmpty
                                ? 'SAC: ${process.sac}'
                                : 'SAC: —',
                            style: TextStyle(
                              fontSize: 11,
                              fontFamily: 'monospace',
                              fontWeight: FontWeight.w600,
                              color: isDark ? const Color(0xFFD1D5DB) : const Color(0xFF4B5563),
                            ),
                          ),
                        ),
                        // Assembly indicator badge
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: process.isAssyProcess
                                ? (isDark ? const Color(0xFF064E3B).withOpacity(0.5) : const Color(0xFFECFDF5))
                                : (isDark ? Colors.white.withOpacity(0.04) : const Color(0xFFF3F4F6)),
                            borderRadius: BorderRadius.circular(4),
                            border: Border.all(
                              color: process.isAssyProcess
                                  ? (isDark ? const Color(0xFF059669) : const Color(0xFFA7F3D0))
                                  : (isDark ? Colors.white12 : const Color(0xFFE5E7EB)),
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                process.isAssyProcess ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded,
                                size: 11,
                                color: process.isAssyProcess
                                    ? (isDark ? const Color(0xFF34D399) : const Color(0xFF059669))
                                    : (isDark ? Colors.white38 : const Color(0xFF9CA3AF)),
                              ),
                              const SizedBox(width: 3),
                              Text(
                                process.isAssyProcess ? 'Assy: Yes' : 'Assy: No',
                                style: TextStyle(
                                  fontSize: 10.5,
                                  fontWeight: FontWeight.w600,
                                  color: process.isAssyProcess
                                      ? (isDark ? const Color(0xFF34D399) : const Color(0xFF047857))
                                      : (isDark ? Colors.white54 : const Color(0xFF6B7280)),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              // Action buttons (Compact)
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _buildSubtleActionButton(
                    icon: Icons.visibility_outlined,
                    tooltip: 'View Details',
                    color: const Color(0xFF2563EB),
                    hoverColor: const Color(0xFF2563EB).withOpacity(0.12),
                    onPressed: () => _viewProcessDetails(context, process),
                  ),
                  if (canManage) ...[
                    _buildSubtleActionButton(
                      icon: Icons.edit_outlined,
                      tooltip: 'Edit Process',
                      color: const Color(0xFF059669),
                      hoverColor: const Color(0xFF059669).withOpacity(0.12),
                      onPressed: () => _openProcessDialog(
                        context,
                        companyId,
                        process: process,
                        hsnSacList: hsnSacList,
                      ),
                    ),
                    _buildSubtleActionButton(
                      icon: Icons.delete_outline_rounded,
                      tooltip: 'Delete Process',
                      color: const Color(0xFFDC2626),
                      hoverColor: const Color(0xFFDC2626).withOpacity(0.12),
                      onPressed: () => _confirmDelete(context, process, companyId),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildProcessDataTable({
    required BuildContext context,
    required List<ProcessModel> processes,
    required List<dynamic> hsnSacList,
    required bool canManage,
    required String companyId,
    required ThemeData theme,
    required bool isDark,
    required bool isMobile,
  }) {
    final borderColor = isDark ? AppColors.borderDark : const Color(0xFFE5E7EB);
    final headerBgColor = isDark ? const Color(0xFF161F2E) : const Color(0xFFF8FAFC);
    final cardBgColor = isDark ? AppColors.surfaceDark : Colors.white;

    return Container(
      decoration: BoxDecoration(
        color: cardBgColor,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: borderColor),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: LayoutBuilder(
        builder: (context, constraints) {
          // On mobile, ensure horizontal scrolling with at least 680px table width so no content gets cramped
          const double minTableWidth = 680;
          final double tableWidth = constraints.maxWidth > minTableWidth ? constraints.maxWidth : minTableWidth;

          return SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: SizedBox(
              width: tableWidth,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Spreadsheet Column Headers
                  Container(
                    height: 46,
                    decoration: BoxDecoration(
                      color: headerBgColor,
                      border: Border(
                        bottom: BorderSide(color: borderColor, width: 1.5),
                      ),
                    ),
                    child: Row(
                      children: [
                        _buildHeaderCell('Sr. No.', width: 75, alignment: Alignment.center, isDark: isDark),
                        _buildHeaderCell('Process Name', flex: 4, minWidth: 200, isDark: isDark),
                        _buildHeaderCell('SAC', flex: 2, minWidth: 120, isDark: isDark),
                        _buildHeaderCell('Assembly Process', flex: 2, minWidth: 140, alignment: Alignment.center, isDark: isDark),
                        _buildHeaderCell('Actions', width: 135, alignment: Alignment.center, isDark: isDark),
                      ],
                    ),
                  ),
                  // Spreadsheet Rows
                  ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: processes.length,
                    separatorBuilder: (_, __) => Divider(
                      height: 1,
                      thickness: 1,
                      color: borderColor,
                    ),
                    itemBuilder: (context, index) {
                      final process = processes[index];
                      return _buildTableRow(
                        context: context,
                        index: index,
                        process: process,
                        hsnSacList: hsnSacList,
                        canManage: canManage,
                        companyId: companyId,
                        theme: theme,
                        isDark: isDark,
                      );
                    },
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildHeaderCell(
    String label, {
    double? width,
    int? flex,
    double? minWidth,
    Alignment alignment = Alignment.centerLeft,
    required bool isDark,
  }) {
    final cell = Container(
      alignment: alignment,
      padding: const EdgeInsets.symmetric(horizontal: 14),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w700,
          color: isDark ? const Color(0xFFD1D5DB) : const Color(0xFF1F2937),
          letterSpacing: 0.2,
        ),
      ),
    );

    if (width != null) {
      return SizedBox(width: width, child: cell);
    }
    return Expanded(
      flex: flex ?? 1,
      child: minWidth != null
          ? ConstrainedBox(
              constraints: BoxConstraints(minWidth: minWidth),
              child: cell,
            )
          : cell,
    );
  }

  Widget _buildTableRow({
    required BuildContext context,
    required int index,
    required ProcessModel process,
    required List<dynamic> hsnSacList,
    required bool canManage,
    required String companyId,
    required ThemeData theme,
    required bool isDark,
  }) {
    final zebraColor = index.isOdd
        ? (isDark ? Colors.white.withOpacity(0.02) : const Color(0xFFF9FAFB))
        : Colors.transparent;

    return Material(
      color: zebraColor,
      child: InkWell(
        hoverColor: isDark ? Colors.white.withOpacity(0.04) : const Color(0xFFF1F5F9),
        onTap: () => _viewProcessDetails(context, process),
        child: Container(
          constraints: const BoxConstraints(minHeight: 52),
          child: Row(
            children: [
              // Sr. No.
              SizedBox(
                width: 75,
                child: Center(
                  child: Text(
                    '${index + 1}',
                    style: TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w600,
                      color: isDark ? Colors.white70 : const Color(0xFF4B5563),
                    ),
                  ),
                ),
              ),

              // Process Name
              Expanded(
                flex: 4,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  child: Row(
                    children: [
                      Container(
                        width: 28,
                        height: 28,
                        decoration: BoxDecoration(
                          color: const Color(0xFF6366F1).withOpacity(isDark ? 0.22 : 0.1),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Icon(
                          Icons.alt_route_rounded,
                          size: 16,
                          color: Color(0xFF6366F1),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          process.processName,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: isDark ? Colors.white : const Color(0xFF111827),
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // SAC
              Expanded(
                flex: 2,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  child: process.sac != null && process.sac!.isNotEmpty
                      ? Align(
                          alignment: Alignment.centerLeft,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3.5),
                            decoration: BoxDecoration(
                              color: isDark ? Colors.grey.shade800 : const Color(0xFFF3F4F6),
                              borderRadius: BorderRadius.circular(4),
                              border: Border.all(
                                color: isDark ? Colors.grey.shade700 : const Color(0xFFD1D5DB),
                              ),
                            ),
                            child: Text(
                              process.sac!,
                              style: TextStyle(
                                fontSize: 12.5,
                                fontFamily: 'monospace',
                                fontWeight: FontWeight.w700,
                                color: isDark ? const Color(0xFFE5E7EB) : const Color(0xFF1F2937),
                              ),
                            ),
                          ),
                        )
                      : Text(
                          '—',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: isDark ? Colors.white38 : const Color(0xFF9CA3AF),
                          ),
                        ),
                ),
              ),

              // Assembly Process
              Expanded(
                flex: 2,
                child: Center(
                  child: process.isAssyProcess
                      ? Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: isDark ? const Color(0xFF064E3B).withOpacity(0.5) : const Color(0xFFECFDF5),
                            borderRadius: BorderRadius.circular(5),
                            border: Border.all(
                              color: isDark ? const Color(0xFF059669) : const Color(0xFFA7F3D0),
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.check_circle_rounded,
                                size: 14,
                                color: isDark ? const Color(0xFF34D399) : const Color(0xFF047857),
                              ),
                              const SizedBox(width: 4),
                              Text(
                                'Yes',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  color: isDark ? const Color(0xFF34D399) : const Color(0xFF047857),
                                ),
                              ),
                            ],
                          ),
                        )
                      : Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: isDark ? Colors.white.withOpacity(0.05) : const Color(0xFFF3F4F6),
                            borderRadius: BorderRadius.circular(5),
                          ),
                          child: Text(
                            'No',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: isDark ? const Color(0xFF9CA3AF) : const Color(0xFF4B5563),
                            ),
                          ),
                        ),
                ),
              ),

              // Actions (View, Edit, Delete)
              SizedBox(
                width: 135,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // View
                    _buildSubtleActionButton(
                      icon: Icons.visibility_outlined,
                      tooltip: 'View Details',
                      color: const Color(0xFF2563EB),
                      hoverColor: const Color(0xFF2563EB).withOpacity(0.12),
                      onPressed: () => _viewProcessDetails(context, process),
                    ),
                    if (canManage) ...[
                      const SizedBox(width: 4),
                      // Edit
                      _buildSubtleActionButton(
                        icon: Icons.edit_outlined,
                        tooltip: 'Edit Process',
                        color: const Color(0xFF059669),
                        hoverColor: const Color(0xFF059669).withOpacity(0.12),
                        onPressed: () => _openProcessDialog(
                          context,
                          companyId,
                          process: process,
                          hsnSacList: hsnSacList,
                        ),
                      ),
                      const SizedBox(width: 4),
                      // Delete
                      _buildSubtleActionButton(
                        icon: Icons.delete_outline_rounded,
                        tooltip: 'Delete Process',
                        color: const Color(0xFFDC2626),
                        hoverColor: const Color(0xFFDC2626).withOpacity(0.12),
                        onPressed: () => _confirmDelete(context, process, companyId),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSubtleActionButton({
    required IconData icon,
    required String tooltip,
    required Color color,
    required Color hoverColor,
    required VoidCallback onPressed,
  }) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          hoverColor: hoverColor,
          onTap: onPressed,
          child: Padding(
            padding: const EdgeInsets.all(7),
            child: Icon(icon, size: 18, color: color),
          ),
        ),
      ),
    );
  }

  void _viewProcessDetails(BuildContext context, ProcessModel process) {
    showDialog(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFF6366F1).withOpacity(0.15),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.alt_route_rounded, color: Color(0xFF6366F1), size: 22),
            ),
            const SizedBox(width: 12),
            const Text('Process Details'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Process Name', style: TextStyle(fontSize: 12, color: Colors.grey, fontWeight: FontWeight.w500)),
            const SizedBox(height: 4),
            Text(process.processName, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            const Text('SAC (Service Accounting Code)', style: TextStyle(fontSize: 12, color: Colors.grey, fontWeight: FontWeight.w500)),
            const SizedBox(height: 4),
            Text(process.sac ?? 'Not configured', style: const TextStyle(fontSize: 14)),
            const SizedBox(height: 12),
            const Text('Assembly Process?', style: TextStyle(fontSize: 12, color: Colors.grey, fontWeight: FontWeight.w500)),
            const SizedBox(height: 4),
            Text(process.isAssyProcess ? 'Yes' : 'No', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Future<void> _openProcessDialog(
    BuildContext context,
    String companyId, {
    ProcessModel? process,
    required List<dynamic> hsnSacList,
  }) async {
    final isEdit = process != null;
    final formKey = GlobalKey<FormState>();
    final nameController = TextEditingController(text: process?.processName ?? '');
    final sacController = TextEditingController(text: process?.sac ?? '');
    bool isAssy = process?.isAssyProcess ?? false;

    // Available SAC options from HSN/SAC master
    final sacCodes = hsnSacList.map((h) => h.code as String).toSet().toList();

    final result = await showDialog<bool>(
      context: context,
      builder: (dialogCtx) {
        bool isSaving = false;
        String? errorMessage;

        return StatefulBuilder(
          builder: (ctx, setDialogState) {
            return AlertDialog(
              title: Text(isEdit ? 'Edit Process' : 'New Process'),
              content: SizedBox(
                width: 440,
                child: Form(
                  key: formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextFormField(
                        controller: nameController,
                        autofocus: true,
                        decoration: InputDecoration(
                          labelText: 'Process Name *',
                          hintText: 'e.g. Turning, Milling, Powder Coating',
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(AppSizes.inputRadius)),
                        ),
                        validator: (val) {
                          if (val == null || val.trim().isEmpty) return 'Process name is required';
                          return null;
                        },
                      ),
                      const SizedBox(height: AppSizes.p16),
                      // SAC autocomplete / text field
                      TextFormField(
                        controller: sacController,
                        decoration: InputDecoration(
                          labelText: 'SAC (Service Accounting Code)',
                          hintText: 'e.g. 9988, 9987',
                          helperText: sacCodes.isNotEmpty ? 'Registered: ${sacCodes.take(3).join(', ')}' : null,
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(AppSizes.inputRadius)),
                        ),
                      ),
                      const SizedBox(height: AppSizes.p16),
                      CheckboxListTile(
                        contentPadding: EdgeInsets.zero,
                        title: const Text('Assy Process?'),
                        subtitle: const Text('Designate if this is a sub-assembly or final assembly operation'),
                        value: isAssy,
                        activeColor: AppColors.primaryLight,
                        onChanged: (val) {
                          setDialogState(() => isAssy = val ?? false);
                        },
                      ),
                      if (errorMessage != null) ...[
                        const SizedBox(height: 12),
                        Text(errorMessage!, style: const TextStyle(color: AppColors.error, fontSize: 12)),
                      ],
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: isSaving ? null : () => Navigator.pop(dialogCtx, false),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: isSaving
                      ? null
                      : () async {
                          if (!formKey.currentState!.validate()) return;
                          final name = nameController.text.trim();
                          final sac = sacController.text.trim();
                          final repo = ref.read(processRepositoryProvider);

                          setDialogState(() {
                            isSaving = true;
                            errorMessage = null;
                          });

                          try {
                            final isTaken = await repo.isProcessNameTaken(
                              companyId,
                              name,
                              excludeId: isEdit ? process.processId : null,
                            );
                            if (isTaken) {
                              setDialogState(() {
                                isSaving = false;
                                errorMessage = 'A process named "$name" already exists.';
                              });
                              return;
                            }

                            if (isEdit) {
                              final updated = process.copyWith(
                                processName: name,
                                sac: sac.isNotEmpty ? sac : null,
                                isAssyProcess: isAssy,
                              );
                              await repo.updateProcess(companyId, updated);
                            } else {
                              final newProcess = ProcessModel(
                                processId: '',
                                companyId: companyId,
                                processName: name,
                                sac: sac.isNotEmpty ? sac : null,
                                isAssyProcess: isAssy,
                                createdAt: DateTime.now(),
                                updatedAt: DateTime.now(),
                              );
                              await repo.createProcess(companyId, newProcess);
                            }

                            if (ctx.mounted) {
                              Navigator.pop(dialogCtx, true);
                            }
                          } catch (e) {
                            setDialogState(() {
                              isSaving = false;
                              errorMessage = 'Error saving process: $e';
                            });
                          }
                        },
                  child: isSaving
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : Text(isEdit ? 'Update' : 'Create'),
                ),
              ],
            );
          },
        );
      },
    );

    if (result == true && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(isEdit ? 'Process updated successfully' : 'Process created successfully'),
          backgroundColor: AppColors.success,
        ),
      );
    }
  }

  Future<void> _confirmDelete(BuildContext context, ProcessModel process, String companyId) async {
    final repo = ref.read(processRepositoryProvider);
    final isReferenced = await repo.isProcessReferenced(companyId, process.processName);

    if (!mounted) return;

    if (isReferenced) {
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.warning_amber_rounded, color: AppColors.warning),
              SizedBox(width: 8),
              Text('Cannot Delete Process'),
            ],
          ),
          content: Text(
            'The process "${process.processName}" is actively assigned to production operations or inventory items. Please reassign those items before deleting.',
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('OK')),
          ],
        ),
      );
      return;
    }

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Process'),
        content: Text('Are you sure you want to permanently delete "${process.processName}"?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete', style: TextStyle(color: AppColors.error)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await repo.deleteProcess(companyId, process.processId);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Process deleted successfully'), backgroundColor: AppColors.success),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error deleting process: $e')),
          );
        }
      }
    }
  }
}
