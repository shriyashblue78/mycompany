import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_sizes.dart';
import '../../../../core/widgets/erp_drawer.dart';
import '../../../../core/widgets/polish_widgets.dart';
import '../../../../core/widgets/responsive_layout.dart';
import '../../../../core/widgets/responsive_widgets.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../domain/models/group_model.dart';
import '../../domain/models/item_model.dart';
import '../providers/group_provider.dart';
import '../providers/item_provider.dart';

class GroupListScreen extends ConsumerStatefulWidget {
  const GroupListScreen({super.key});

  @override
  ConsumerState<GroupListScreen> createState() => _GroupListScreenState();
}

class _GroupListScreenState extends ConsumerState<GroupListScreen> {
  @override
  Widget build(BuildContext context) {
    final groupsAsync = ref.watch(companyGroupsStreamProvider);
    final itemsAsync = ref.watch(companyItemsStreamProvider);
    final authState = ref.watch(authProvider);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final isMobile = ResponsiveLayout.isMobile(context);

    final role = authState.selectedRole ?? 'Employee';
    final canManage = role == 'Owner' || role == 'Accountant';
    final companyId = authState.user?.companyId ?? '';

    final allGroups = groupsAsync.valueOrNull ?? [];
    final allItems = itemsAsync.valueOrNull ?? [];
    final query = ref.watch(groupSearchQueryProvider).trim().toLowerCase();

    // Filter groups by search query
    final filteredGroups = allGroups.where((g) {
      if (query.isEmpty) return true;
      final groupNameMatch = g.groupName.toLowerCase().contains(query);
      final parentMatch = (g.parentGroupName ?? '').toLowerCase().contains(query);
      return groupNameMatch || parentMatch;
    }).toList();

    final appBar = AppBar(
      title: const Text(
        'Group Master',
        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
      ),
      elevation: 0,
    );

    return groupsAsync.when(
      data: (_) {
        final body = RefreshIndicator(
          onRefresh: () async {
            ref.invalidate(companyGroupsStreamProvider);
            ref.invalidate(companyItemsStreamProvider);
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
                    _buildHeaderBar(
                      context: context,
                      companyId: companyId,
                      allGroups: allGroups,
                      allItems: allItems,
                      canManage: canManage,
                      theme: theme,
                      isDark: isDark,
                      isMobile: isMobile,
                      count: filteredGroups.length,
                    ),
                    const SizedBox(height: AppSizes.p12),
                    if (filteredGroups.isEmpty)
                      EmptyStateWidget(
                        icon: Icons.folder_special_outlined,
                        title: 'No Groups Found',
                        description: query.isNotEmpty
                            ? 'No groups match your search query. Try another keyword.'
                            : 'Create item groups to organize materials, parts, and inventory hierarchies.',
                      )
                    else
                      _buildDesktopTable(
                      context: context,
                      groups: filteredGroups,
                      allItems: allItems,
                      allGroups: allGroups,
                      canManage: canManage,
                      companyId: companyId,
                      theme: theme,
                      isDark: isDark,
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
                Text('Error loading groups: $err'),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: () {
                    ref.invalidate(companyGroupsStreamProvider);
                    ref.invalidate(companyItemsStreamProvider);
                  },
                  child: const Text('Retry'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeaderBar({
    required BuildContext context,
    required String companyId,
    required List<GroupModel> allGroups,
    required List<ItemModel> allItems,
    required bool canManage,
    required ThemeData theme,
    required bool isDark,
    required bool isMobile,
    required int count,
  }) {
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
                onChanged: (val) => ref.read(groupSearchQueryProvider.notifier).state = val,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: isDark ? Colors.white : const Color(0xFF111827),
                ),
                decoration: InputDecoration(
                  hintText: 'Search Group Name or Under Group...',
                  hintStyle: TextStyle(
                    fontSize: 13.5,
                    color: isDark ? Colors.white54 : const Color(0xFF6B7280),
                  ),
                  prefixIcon: Icon(
                    Icons.search_rounded,
                    size: 20,
                    color: isDark ? Colors.white70 : const Color(0xFF4B5563),
                  ),
                  suffixIcon: ref.watch(groupSearchQueryProvider).isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear_rounded, size: 18),
                          splashRadius: 18,
                          onPressed: () => ref.read(groupSearchQueryProvider.notifier).state = '',
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

          // Total count badge and New Group button
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
                    onPressed: () => _openGroupDialog(
                      context,
                      companyId,
                      allGroups: allGroups,
                      allItems: allItems,
                    ),
                    icon: const Icon(Icons.add_rounded, size: 18),
                    label: const Text(
                      'New Group',
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

  Widget _buildDesktopTable({
    required BuildContext context,
    required List<GroupModel> groups,
    required List<ItemModel> allItems,
    required List<GroupModel> allGroups,
    required bool canManage,
    required String companyId,
    required ThemeData theme,
    required bool isDark,
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
          const double minTableWidth = 640;
          final double tableWidth = constraints.maxWidth > minTableWidth ? constraints.maxWidth : minTableWidth;

          return SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: SizedBox(
              width: tableWidth,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Spreadsheet Column Headers: Sr. No., Group Name, Under Group, Actions
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
                        _buildHeaderCell('Sr.', width: 65, alignment: Alignment.center, isDark: isDark),
                        _buildHeaderCell('Group Name', flex: 4, minWidth: 220, isDark: isDark),
                        _buildHeaderCell('Under Group', flex: 3, minWidth: 180, isDark: isDark),
                        _buildHeaderCell('Actions', width: 140, alignment: Alignment.center, isDark: isDark),
                      ],
                    ),
                  ),
                  // Spreadsheet Rows
                  ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: groups.length,
                    separatorBuilder: (_, __) => Divider(
                      height: 1,
                      thickness: 1,
                      color: borderColor,
                    ),
                    itemBuilder: (context, index) {
                      final group = groups[index];
                      final groupItems = allItems.where((i) =>
                          (i.underGroup ?? '').trim().toLowerCase() ==
                          group.groupName.trim().toLowerCase()).toList();

                      return _buildGroupRow(
                        context: context,
                        index: index,
                        group: group,
                        groupItems: groupItems,
                        allGroups: allGroups,
                        allItems: allItems,
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

  Widget _buildGroupRow({
    required BuildContext context,
    required int index,
    required GroupModel group,
    required List<ItemModel> groupItems,
    required List<GroupModel> allGroups,
    required List<ItemModel> allItems,
    required bool canManage,
    required String companyId,
    required ThemeData theme,
    required bool isDark,
  }) {
    final hasParent = group.parentGroupName != null && group.parentGroupName!.isNotEmpty;

    return Container(
      constraints: const BoxConstraints(minHeight: 52),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // 1. Sr. No.
          SizedBox(
            width: 65,
            child: Center(
              child: Text(
                '${index + 1}',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: isDark ? const Color(0xFF9CA3AF) : const Color(0xFF6B7280),
                ),
              ),
            ),
          ),

          // 2. Group Name
          Expanded(
            flex: 4,
            child: ConstrainedBox(
              constraints: const BoxConstraints(minWidth: 220),
              child: Row(
                children: [
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: const Color(0xFF14B8A6).withOpacity(isDark ? 0.22 : 0.12),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.folder_special_rounded, color: Color(0xFF14B8A6), size: 16),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      group.groupName,
                      style: TextStyle(
                        fontSize: 13.5,
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

          // 3. Under Group (Parent)
          Expanded(
            flex: 3,
            child: ConstrainedBox(
              constraints: const BoxConstraints(minWidth: 180),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: isDark ? Colors.white.withOpacity(0.06) : Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  hasParent ? group.parentGroupName! : 'Primary (Root)',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: hasParent
                        ? (isDark ? Colors.teal.shade300 : Colors.teal.shade800)
                        : (isDark ? Colors.white60 : Colors.black54),
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ),
          ),

          // 4. Actions
          SizedBox(
            width: 140,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _buildSubtleActionButton(
                  icon: Icons.visibility_outlined,
                  tooltip: 'View Details',
                  color: const Color(0xFF2563EB),
                  hoverColor: const Color(0xFF2563EB).withOpacity(0.12),
                  onPressed: () => _viewGroupDetails(context, group, groupItems),
                ),
                if (canManage) ...[
                  const SizedBox(width: 4),
                  _buildSubtleActionButton(
                    icon: Icons.edit_outlined,
                    tooltip: 'Edit Group',
                    color: const Color(0xFF059669),
                    hoverColor: const Color(0xFF059669).withOpacity(0.12),
                    onPressed: () => _openGroupDialog(
                      context,
                      companyId,
                      group: group,
                      allGroups: allGroups,
                      allItems: allItems,
                    ),
                  ),
                  const SizedBox(width: 4),
                  _buildSubtleActionButton(
                    icon: Icons.delete_outline_rounded,
                    tooltip: 'Delete Group',
                    color: const Color(0xFFDC2626),
                    hoverColor: const Color(0xFFDC2626).withOpacity(0.12),
                    onPressed: () => _confirmDelete(context, group, groupItems, companyId),
                  ),
                ],
              ],
            ),
          ),
        ],
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

  Widget _buildMobileGroupCard({
    required BuildContext context,
    required GroupModel group,
    required List<ItemModel> groupItems,
    required List<GroupModel> allGroups,
    required List<ItemModel> allItems,
    required bool canManage,
    required String companyId,
    required ThemeData theme,
    required bool isDark,
  }) {
    final hasParent = group.parentGroupName != null && group.parentGroupName!.isNotEmpty;

    return ResponsiveCard(
      padding: const EdgeInsets.all(AppSizes.p16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: const Color(0xFF14B8A6).withOpacity(isDark ? 0.22 : 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.folder_special_rounded, color: Color(0xFF14B8A6), size: 18),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      group.groupName,
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                    ),
                    if (hasParent)
                      Text(
                        'Under: ${group.parentGroupName}',
                        style: TextStyle(
                          fontSize: 12,
                          color: isDark ? Colors.teal.shade300 : Colors.teal.shade800,
                        ),
                      ),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.visibility_outlined, size: 20, color: AppColors.info),
                onPressed: () => _viewGroupDetails(context, group, groupItems),
              ),
              if (canManage) ...[
                IconButton(
                  icon: const Icon(Icons.edit_outlined, size: 20, color: Colors.blue),
                  onPressed: () => _openGroupDialog(
                    context,
                    companyId,
                    group: group,
                    allGroups: allGroups,
                    allItems: allItems,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.delete_outline_rounded, size: 20, color: AppColors.error),
                  onPressed: () => _confirmDelete(context, group, groupItems, companyId),
                ),
              ],
            ],
          ),
          const SizedBox(height: 12),
          Text(
            'Associated Items (${groupItems.length})',
            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: Colors.grey),
          ),
          const SizedBox(height: 6),
          if (groupItems.isEmpty)
            const Text(
              'No items associated with this group.',
              style: TextStyle(fontSize: 13, fontStyle: FontStyle.italic, color: Colors.grey),
            )
          else
            ...groupItems.map((item) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          item.itemDescription,
                          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: isDark ? Colors.white.withOpacity(0.06) : Colors.grey.shade100,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          item.itemNo,
                          style: const TextStyle(fontFamily: 'monospace', fontSize: 11, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  ),
                )),
        ],
      ),
    );
  }

  void _viewGroupDetails(BuildContext context, GroupModel group, List<ItemModel> groupItems) {
    final hasParent = group.parentGroupName != null && group.parentGroupName!.isNotEmpty;

    showDialog(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFF14B8A6).withOpacity(0.15),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.folder_special_rounded, color: Color(0xFF14B8A6), size: 22),
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: Text('Group Details', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
        content: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 550),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildDetailRow('Group Name', group.groupName),
                const SizedBox(height: 8),
                _buildDetailRow(
                  'Under Group (Parent)',
                  hasParent ? group.parentGroupName! : 'Primary (Root / No parent group)',
                ),
                const SizedBox(height: 8),
                _buildDetailRow(
                  'Last Updated',
                  DateFormat('dd MMM yyyy, hh:mm a').format(group.updatedAt),
                ),
                const Divider(height: 24),
                Text(
                  'Associated Items (${groupItems.length})',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                ),
                const SizedBox(height: 8),
                if (groupItems.isEmpty)
                  const Text(
                    'No items currently associated with this group.',
                    style: TextStyle(fontStyle: FontStyle.italic, color: Colors.grey),
                  )
                else
                  Container(
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey.withOpacity(0.2)),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: ListView.separated(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: groupItems.length,
                      separatorBuilder: (_, __) => Divider(height: 1, color: Colors.grey.withOpacity(0.2)),
                      itemBuilder: (ctx, i) {
                        final item = groupItems[i];
                        return ListTile(
                          dense: true,
                          title: Text(item.itemDescription, style: const TextStyle(fontWeight: FontWeight.w600)),
                          subtitle: Text('Category: ${item.category} • Unit: ${item.stockUnit}'),
                          trailing: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.teal.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              item.itemNo,
                              style: const TextStyle(fontFamily: 'monospace', fontWeight: FontWeight.bold),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
              ],
            ),
          ),
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

  Widget _buildDetailRow(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey, fontWeight: FontWeight.w500)),
        const SizedBox(height: 2),
        Text(value, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
      ],
    );
  }

  Future<void> _openGroupDialog(
    BuildContext context,
    String companyId, {
    GroupModel? group,
    required List<GroupModel> allGroups,
    required List<ItemModel> allItems,
  }) async {
    final isEdit = group != null;
    final formKey = GlobalKey<FormState>();
    final nameController = TextEditingController(text: group?.groupName ?? '');

    String? selectedParentId = group?.parentGroupId;

    final availableParents = allGroups.where((g) {
      if (!isEdit) return true;
      if (g.groupId == group.groupId) return false;
      return true;
    }).toList();

    if (selectedParentId != null && !availableParents.any((g) => g.groupId == selectedParentId)) {
      selectedParentId = null;
    }

    // Track associated items locally during editing
    final currentGroupName = group?.groupName ?? '';
    List<ItemModel> associatedItems = isEdit
        ? allItems
            .where((i) =>
                (i.underGroup ?? '').trim().toLowerCase() == currentGroupName.trim().toLowerCase())
            .toList()
        : [];

    await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dialogCtx) {
        bool isSaving = false;
        String? errorMessage;

        return StatefulBuilder(
          builder: (ctx, setDialogState) {
            return AlertDialog(
              title: Row(
                children: [
                  Icon(
                    isEdit ? Icons.edit_rounded : Icons.add_circle_outline_rounded,
                    color: isEdit ? Colors.blue : AppColors.primaryLight,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    isEdit ? 'Edit Group & Item Associations' : 'New Group',
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              content: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 620, maxHeight: 600),
                child: SingleChildScrollView(
                  child: Form(
                    key: formKey,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        TextFormField(
                          controller: nameController,
                          autofocus: !isEdit,
                          decoration: InputDecoration(
                            labelText: 'Group Name *',
                            hintText: 'e.g. Raw Materials, Packing, Finished Goods',
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(AppSizes.inputRadius),
                            ),
                          ),
                          validator: (val) {
                            if (val == null || val.trim().isEmpty) {
                              return 'Group name is required';
                            }
                            if (val.trim().length < 2) {
                              return 'Must be at least 2 characters';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: AppSizes.p16),
                        DropdownButtonFormField<String?>(
                          value: selectedParentId,
                          isExpanded: true,
                          decoration: InputDecoration(
                            labelText: 'Under Group (Parent Hierarchy)',
                            helperText: 'Select parent group or leave as Primary',
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(AppSizes.inputRadius),
                            ),
                          ),
                          items: [
                            const DropdownMenuItem<String?>(
                              value: null,
                              child: Text('Primary (Root / No parent)'),
                            ),
                            ...availableParents.map((g) {
                              return DropdownMenuItem<String?>(
                                value: g.groupId,
                                child: Text(g.groupName),
                              );
                            }),
                          ],
                          onChanged: (val) {
                            setDialogState(() {
                              selectedParentId = val;
                              errorMessage = null;
                            });
                          },
                        ),
                        if (isEdit) ...[
                          const SizedBox(height: 20),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'Associated Items (${associatedItems.length})',
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                              ),
                              ElevatedButton.icon(
                                onPressed: () async {
                                  // Pick unassigned items to associate
                                  final assignedIds = associatedItems.map((i) => i.itemId).toSet();
                                  final availableItems = allItems
                                      .where((i) => !assignedIds.contains(i.itemId))
                                      .toList();

                                  final selectedIds = await _showItemSelectorDialog(
                                    context,
                                    availableItems,
                                  );

                                  if (selectedIds != null && selectedIds.isNotEmpty) {
                                    setDialogState(() {
                                      isSaving = true;
                                    });
                                    final itemRepo = ref.read(itemRepositoryProvider);
                                    await itemRepo.assignItemsToGroup(
                                      companyId,
                                      nameController.text.trim(),
                                      selectedIds,
                                    );
                                    ref.invalidate(companyItemsStreamProvider);

                                    // Refresh local list
                                    final added = allItems
                                        .where((i) => selectedIds.contains(i.itemId))
                                        .map((i) => i.copyWith(underGroup: nameController.text.trim()))
                                        .toList();

                                    setDialogState(() {
                                      associatedItems.addAll(added);
                                      isSaving = false;
                                    });
                                  }
                                },
                                icon: const Icon(Icons.add_link_rounded, size: 16),
                                label: const Text('Add Items'),
                                style: ElevatedButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                  textStyle: const TextStyle(fontSize: 12),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          if (associatedItems.isEmpty)
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.grey.withOpacity(0.08),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Row(
                                children: [
                                  Icon(Icons.info_outline_rounded, size: 18, color: Colors.grey),
                                  SizedBox(width: 8),
                                  Text(
                                    'No items associated with this group yet.',
                                    style: TextStyle(fontSize: 12, color: Colors.grey),
                                  ),
                                ],
                              ),
                            )
                          else
                            Container(
                              constraints: const BoxConstraints(maxHeight: 200),
                              decoration: BoxDecoration(
                                border: Border.all(color: Colors.grey.withOpacity(0.2)),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: ListView.separated(
                                shrinkWrap: true,
                                itemCount: associatedItems.length,
                                separatorBuilder: (_, __) => Divider(
                                  height: 1,
                                  color: Colors.grey.withOpacity(0.2),
                                ),
                                itemBuilder: (ctx, i) {
                                  final item = associatedItems[i];
                                  return ListTile(
                                    dense: true,
                                    title: Text(
                                      item.itemDescription,
                                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    subtitle: Text(
                                      'Part: ${item.itemNo}',
                                      style: const TextStyle(fontFamily: 'monospace', fontSize: 11),
                                    ),
                                    trailing: IconButton(
                                      icon: const Icon(Icons.link_off_rounded, color: AppColors.error, size: 18),
                                      tooltip: 'Remove from this group',
                                      onPressed: () async {
                                        final itemRepo = ref.read(itemRepositoryProvider);
                                        await itemRepo.removeItemFromGroup(companyId, item.itemId);
                                        ref.invalidate(companyItemsStreamProvider);

                                        setDialogState(() {
                                          associatedItems.removeWhere((it) => it.itemId == item.itemId);
                                        });
                                      },
                                    ),
                                  );
                                },
                              ),
                            ),
                        ],
                        if (errorMessage != null) ...[
                          const SizedBox(height: 12),
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: AppColors.error.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: AppColors.error.withOpacity(0.3)),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.error_outline_rounded, color: AppColors.error, size: 18),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    errorMessage!,
                                    style: const TextStyle(color: AppColors.error, fontSize: 12),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
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
                          final newName = nameController.text.trim();
                          final repo = ref.read(groupRepositoryProvider);
                          final itemRepo = ref.read(itemRepositoryProvider);

                          setDialogState(() {
                            isSaving = true;
                            errorMessage = null;
                          });

                          try {
                            // 1. Duplicate name validation
                            final isTaken = await repo.isGroupNameTaken(
                              companyId,
                              newName,
                              excludeGroupId: isEdit ? group.groupId : null,
                            );
                            if (isTaken) {
                              setDialogState(() {
                                isSaving = false;
                                errorMessage = 'A group named "$newName" already exists in this company.';
                              });
                              return;
                            }

                            // 2. Circular reference validation
                            if (isEdit && selectedParentId != null && selectedParentId!.isNotEmpty) {
                              final createsCycle = await repo.wouldCreateCycle(
                                companyId,
                                group.groupId,
                                selectedParentId!,
                              );
                              if (createsCycle) {
                                setDialogState(() {
                                  isSaving = false;
                                  errorMessage = 'Cannot select this parent: it would cause a circular relationship.';
                                });
                                return;
                              }
                            }

                            // 3. Resolve parent name
                            String? parentName;
                            if (selectedParentId != null && selectedParentId!.isNotEmpty) {
                              final parentMatch = allGroups.where((g) => g.groupId == selectedParentId).firstOrNull;
                              parentName = parentMatch?.groupName;
                            }

                            if (isEdit) {
                              final oldName = group.groupName;
                              final updated = group.copyWith(
                                groupName: newName,
                                parentGroupId: selectedParentId,
                                parentGroupName: parentName,
                                clearParent: selectedParentId == null,
                              );
                              await repo.updateGroup(companyId, updated);

                              // If group was renamed, also safely update all associated items
                              if (oldName.trim().toLowerCase() != newName.trim().toLowerCase()) {
                                await itemRepo.updateGroupForItems(companyId, oldName, newName);
                              }
                            } else {
                              final newGroup = GroupModel(
                                groupId: '',
                                companyId: companyId,
                                groupName: newName,
                                parentGroupId: selectedParentId,
                                parentGroupName: parentName,
                                createdAt: DateTime.now(),
                                updatedAt: DateTime.now(),
                              );
                              await repo.createGroup(companyId, newGroup);
                            }

                            ref.invalidate(companyGroupsStreamProvider);
                            ref.invalidate(companyItemsStreamProvider);

                            if (ctx.mounted) {
                              Navigator.pop(dialogCtx, true);
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    isEdit
                                        ? 'Group and item associations updated successfully'
                                        : 'Group created successfully',
                                  ),
                                  backgroundColor: AppColors.success,
                                ),
                              );
                            }
                          } catch (e) {
                            setDialogState(() {
                              isSaving = false;
                              errorMessage = 'Error saving group: $e';
                            });
                          }
                        },
                  child: isSaving
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : Text(isEdit ? 'Update Group' : 'Save Group'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<List<String>?> _showItemSelectorDialog(
    BuildContext context,
    List<ItemModel> availableItems,
  ) {
    final selectedIds = <String>{};
    String filter = '';

    return showDialog<List<String>>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (dialogCtx, setSelectorState) {
          final itemsToShow = availableItems.where((i) {
            if (filter.isEmpty) return true;
            return i.itemDescription.toLowerCase().contains(filter) ||
                i.itemNo.toLowerCase().contains(filter);
          }).toList();

          return AlertDialog(
            title: const Text('Add Existing Items to Group', style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
            content: SizedBox(
              width: 500,
              height: 400,
              child: Column(
                children: [
                  TextField(
                    decoration: const InputDecoration(
                      hintText: 'Search items by description or part number...',
                      prefixIcon: Icon(Icons.search_rounded),
                      isDense: true,
                    ),
                    onChanged: (val) {
                      setSelectorState(() {
                        filter = val.trim().toLowerCase();
                      });
                    },
                  ),
                  const SizedBox(height: 10),
                  Expanded(
                    child: itemsToShow.isEmpty
                        ? const Center(
                            child: Text(
                              'No matching items available.',
                              style: TextStyle(color: Colors.grey),
                            ),
                          )
                        : ListView.separated(
                            itemCount: itemsToShow.length,
                            separatorBuilder: (_, __) => const Divider(height: 1),
                            itemBuilder: (c, idx) {
                              final it = itemsToShow[idx];
                              final isSelected = selectedIds.contains(it.itemId);
                              return CheckboxListTile(
                                value: isSelected,
                                title: Text(it.itemDescription, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                                subtitle: Text(
                                  'Part: ${it.itemNo} • Current Group: ${it.underGroup ?? "None"}',
                                  style: const TextStyle(fontSize: 11),
                                ),
                                dense: true,
                                onChanged: (checked) {
                                  setSelectorState(() {
                                    if (checked == true) {
                                      selectedIds.add(it.itemId);
                                    } else {
                                      selectedIds.remove(it.itemId);
                                    }
                                  });
                                },
                              );
                            },
                          ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogCtx, null),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: selectedIds.isEmpty
                    ? null
                    : () => Navigator.pop(dialogCtx, selectedIds.toList()),
                child: Text('Add (${selectedIds.length})'),
              ),
            ],
          );
        },
      ),
    );
  }

  void _confirmDelete(
    BuildContext context,
    GroupModel group,
    List<ItemModel> groupItems,
    String companyId,
  ) async {
    final repo = ref.read(groupRepositoryProvider);
    final hasChildren = await repo.hasChildGroups(companyId, group.groupId);

    if (!context.mounted) return;

    if (hasChildren) {
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.warning_amber_rounded, color: AppColors.error),
              SizedBox(width: 8),
              Text('Cannot Delete Group'),
            ],
          ),
          content: Text(
            'Cannot delete "${group.groupName}" because child groups are nested under it in the hierarchy. Please reassign or delete child groups first.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('OK'),
            ),
          ],
        ),
      );
      return;
    }

    final hasItems = groupItems.isNotEmpty;

    showDialog(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: AppColors.error),
            SizedBox(width: 8),
            Text('Delete Group'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Are you sure you want to delete group "${group.groupName}"?'),
            if (hasItems) ...[
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.amber.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: Colors.amber.shade700.withOpacity(0.3)),
                ),
                child: Text(
                  'Note: ${groupItems.length} item(s) are associated with this group. Their group link will be safely cleared without deleting the items.',
                  style: TextStyle(fontSize: 12, color: Colors.amber.shade900),
                ),
              ),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
            onPressed: () async {
              Navigator.pop(dialogCtx);
              try {
                // Safely unassociate items if any
                for (final item in groupItems) {
                  await ref.read(itemRepositoryProvider).removeItemFromGroup(companyId, item.itemId);
                }
                await repo.deleteGroup(companyId, group.groupId);
                ref.invalidate(companyGroupsStreamProvider);
                ref.invalidate(companyItemsStreamProvider);

                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Group deleted successfully'),
                      backgroundColor: AppColors.success,
                    ),
                  );
                }
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Failed to delete group: $e'),
                      backgroundColor: AppColors.error,
                    ),
                  );
                }
              }
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }
}
