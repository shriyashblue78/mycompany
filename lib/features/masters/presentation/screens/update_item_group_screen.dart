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
import '../../domain/repositories/item_repository.dart';
import '../providers/group_provider.dart';
import '../providers/item_provider.dart';

final updateItemGroupSearchQueryProvider = StateProvider<String>((ref) => '');

class _GroupItemEntry {
  final GroupModel group;
  final ItemModel? item;

  const _GroupItemEntry({required this.group, this.item});
}

class UpdateItemGroupScreen extends ConsumerStatefulWidget {
  const UpdateItemGroupScreen({super.key});

  @override
  ConsumerState<UpdateItemGroupScreen> createState() => _UpdateItemGroupScreenState();
}

class _UpdateItemGroupScreenState extends ConsumerState<UpdateItemGroupScreen> {
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
    final query = ref.watch(updateItemGroupSearchQueryProvider).trim().toLowerCase();

    // Flatten group-item associations into spreadsheet rows
    final List<_GroupItemEntry> allEntries = [];
    for (final g in allGroups) {
      final gItems = allItems.where((i) =>
          (i.underGroup ?? '').trim().toLowerCase() ==
          g.groupName.trim().toLowerCase()).toList();

      if (gItems.isEmpty) {
        allEntries.add(_GroupItemEntry(group: g, item: null));
      } else {
        for (final it in gItems) {
          allEntries.add(_GroupItemEntry(group: g, item: it));
        }
      }
    }

    // Filter by query
    final filteredEntries = allEntries.where((entry) {
      if (query.isEmpty) return true;
      final groupMatch = entry.group.groupName.toLowerCase().contains(query);
      final itemMatch = entry.item != null &&
          (entry.item!.itemDescription.toLowerCase().contains(query) ||
              entry.item!.itemNo.toLowerCase().contains(query));
      return groupMatch || itemMatch;
    }).toList();

    final appBar = AppBar(
      title: const Text(
        'Update Item Group',
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
                      canManage: canManage,
                      isDark: isDark,
                      isMobile: isMobile,
                      count: filteredEntries.length,
                    ),
                    const SizedBox(height: AppSizes.p12),
                    if (filteredEntries.isEmpty)
                      EmptyStateWidget(
                        icon: Icons.edit_note_rounded,
                        title: 'No Group Associations Found',
                        description: query.isNotEmpty
                            ? 'No group or item associations match your search.'
                            : 'Create groups in Group Master and assign items here.',
                      )
                    else
                      _buildSpreadsheetTable(
                        context: context,
                        entries: filteredEntries,
                        allGroups: allGroups,
                        allItems: allItems,
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
    required bool canManage,
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
                onChanged: (val) => ref.read(updateItemGroupSearchQueryProvider.notifier).state = val,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: isDark ? Colors.white : const Color(0xFF111827),
                ),
                decoration: InputDecoration(
                  hintText: 'Search Group Name, Item, or Matl No...',
                  hintStyle: TextStyle(
                    fontSize: 13.5,
                    color: isDark ? Colors.white54 : const Color(0xFF6B7280),
                  ),
                  prefixIcon: Icon(
                    Icons.search_rounded,
                    size: 20,
                    color: isDark ? Colors.white70 : const Color(0xFF4B5563),
                  ),
                  suffixIcon: ref.watch(updateItemGroupSearchQueryProvider).isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear_rounded, size: 18),
                          splashRadius: 18,
                          onPressed: () => ref.read(updateItemGroupSearchQueryProvider.notifier).state = '',
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

          // Total count badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
            decoration: BoxDecoration(
              color: isDark ? Colors.grey.shade800 : const Color(0xFFF3F4F6),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: borderColor),
            ),
            child: Text(
              'Total Rows: $count',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: isDark ? Colors.white : const Color(0xFF1F2937),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSpreadsheetTable({
    required BuildContext context,
    required List<_GroupItemEntry> entries,
    required List<GroupModel> allGroups,
    required List<ItemModel> allItems,
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
          const double minTableWidth = 720;
          final double tableWidth = constraints.maxWidth > minTableWidth ? constraints.maxWidth : minTableWidth;

          return SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: SizedBox(
              width: tableWidth,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Spreadsheet Column Headers: Group Name, Item Description, Matl No., Actions
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
                        _buildHeaderCell('Group Name', flex: 3, minWidth: 200, isDark: isDark),
                        _buildHeaderCell('Item Description', flex: 4, minWidth: 260, isDark: isDark),
                        _buildHeaderCell('Matl No.', flex: 2, minWidth: 140, isDark: isDark),
                        _buildHeaderCell('Actions', width: 120, alignment: Alignment.center, isDark: isDark),
                      ],
                    ),
                  ),
                  // Spreadsheet Rows
                  ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: entries.length,
                    separatorBuilder: (_, __) => Divider(
                      height: 1,
                      thickness: 1,
                      color: borderColor,
                    ),
                    itemBuilder: (context, index) {
                      final entry = entries[index];
                      return _buildEntryRow(
                        context: context,
                        entry: entry,
                        allGroups: allGroups,
                        allItems: allItems,
                        canManage: canManage,
                        companyId: companyId,
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

  Widget _buildEntryRow({
    required BuildContext context,
    required _GroupItemEntry entry,
    required List<GroupModel> allGroups,
    required List<ItemModel> allItems,
    required bool canManage,
    required String companyId,
    required bool isDark,
  }) {
    final item = entry.item;
    final group = entry.group;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // 1. Group Name
          Expanded(
            flex: 3,
            child: ConstrainedBox(
              constraints: const BoxConstraints(minWidth: 200),
              child: Row(
                children: [
                  Container(
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                      color: const Color(0xFF14B8A6).withOpacity(isDark ? 0.22 : 0.12),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Icon(Icons.folder_special_rounded, color: Color(0xFF14B8A6), size: 15),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          group.groupName,
                          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13.5),
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (group.parentGroupName != null && group.parentGroupName!.isNotEmpty)
                          Text(
                            '↳ ${group.parentGroupName}',
                            style: TextStyle(
                              fontSize: 11,
                              color: isDark ? Colors.teal.shade300 : Colors.teal.shade800,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          // 2. Item Description
          Expanded(
            flex: 4,
            child: ConstrainedBox(
              constraints: const BoxConstraints(minWidth: 260),
              child: item != null
                  ? Row(
                      children: [
                        Container(
                          width: 6,
                          height: 6,
                          margin: const EdgeInsets.only(right: 8),
                          decoration: BoxDecoration(
                            color: Colors.teal.shade400,
                            shape: BoxShape.circle,
                          ),
                        ),
                        Expanded(
                          child: Text(
                            item.itemDescription,
                            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    )
                  : Row(
                      children: [
                        const Text(
                          '(No items associated)',
                          style: TextStyle(fontSize: 12.5, fontStyle: FontStyle.italic, color: Colors.grey),
                        ),
                        if (canManage) ...[
                          const SizedBox(width: 8),
                          InkWell(
                            onTap: () => _showAddItemsToGroup(context, companyId, group, allItems),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: const Color(0xFF059669).withOpacity(0.1),
                                borderRadius: BorderRadius.circular(4),
                                border: Border.all(color: const Color(0xFF059669).withOpacity(0.3)),
                              ),
                              child: const Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.add_link_rounded, size: 12, color: Color(0xFF059669)),
                                  SizedBox(width: 3),
                                  Text(
                                    'Assign',
                                    style: TextStyle(fontSize: 11, color: Color(0xFF059669), fontWeight: FontWeight.w600),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
            ),
          ),

          // 3. Matl No.
          Expanded(
            flex: 2,
            child: ConstrainedBox(
              constraints: const BoxConstraints(minWidth: 140),
              child: item != null
                  ? Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: isDark ? Colors.white.withOpacity(0.06) : Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        item.itemNo,
                        style: const TextStyle(
                          fontFamily: 'monospace',
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    )
                  : const Text('—', style: TextStyle(color: Colors.grey)),
            ),
          ),

          // 4. Actions
          SizedBox(
            width: 120,
            child: canManage
                ? Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      if (item != null) ...[
                        // Edit item association
                        Tooltip(
                          message: 'Change Group for "${item.itemDescription}"',
                          child: IconButton(
                            icon: const Icon(Icons.swap_horiz_rounded, size: 18, color: Color(0xFF2563EB)),
                            onPressed: () => _changeItemGroup(context, companyId, item, group, allGroups),
                          ),
                        ),
                        // Unlink item from group
                        Tooltip(
                          message: 'Unlink from ${group.groupName}',
                          child: IconButton(
                            icon: const Icon(Icons.link_off_rounded, size: 18, color: AppColors.error),
                            onPressed: () async {
                              final confirmed = await showDialog<bool>(
                                context: context,
                                builder: (ctx) => AlertDialog(
                                  title: const Text('Unlink Item from Group'),
                                  content: Text('Remove item "${item.itemDescription}" from group "${group.groupName}"?'),
                                  actions: [
                                    TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
                                    ElevatedButton(
                                      style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
                                      onPressed: () => Navigator.pop(ctx, true),
                                      child: const Text('Unlink'),
                                    ),
                                  ],
                                ),
                              );
                              if (confirmed == true) {
                                await ref.read(itemRepositoryProvider).removeItemFromGroup(companyId, item.itemId);
                                ref.invalidate(companyItemsStreamProvider);
                              }
                            },
                          ),
                        ),
                      ] else ...[
                        Tooltip(
                          message: 'Add items to ${group.groupName}',
                          child: IconButton(
                            icon: const Icon(Icons.add_link_rounded, size: 18, color: Color(0xFF059669)),
                            onPressed: () => _showAddItemsToGroup(context, companyId, group, allItems),
                          ),
                        ),
                      ],
                    ],
                  )
                : const SizedBox.shrink(),
          ),
        ],
      ),
    );
  }

  Future<void> _changeItemGroup(
    BuildContext context,
    String companyId,
    ItemModel item,
    GroupModel currentGroup,
    List<GroupModel> allGroups,
  ) async {
    String? selectedNewGroup = currentGroup.groupName;

    final updated = await showDialog<String>(
      context: context,
      builder: (dialogCtx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text('Change Item Group', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Item: ${item.itemDescription}', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13.5)),
              Text('Matl No: ${item.itemNo}', style: const TextStyle(fontFamily: 'monospace', fontSize: 12, color: Colors.grey)),
              const SizedBox(height: 16),
              DropdownButtonFormField<String?>(
                value: selectedNewGroup,
                isExpanded: true,
                decoration: const InputDecoration(labelText: 'Select New Group', border: OutlineInputBorder()),
                items: [
                  const DropdownMenuItem<String?>(value: null, child: Text('None (Primary / Unassigned)')),
                  for (final g in allGroups)
                    DropdownMenuItem<String?>(value: g.groupName, child: Text(g.groupName)),
                ],
                onChanged: (val) {
                  setDialogState(() => selectedNewGroup = val);
                },
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(dialogCtx, null), child: const Text('Cancel')),
            ElevatedButton(
              onPressed: () => Navigator.pop(dialogCtx, selectedNewGroup ?? ''),
              child: const Text('Update'),
            ),
          ],
        ),
      ),
    );

    if (updated != null) {
      final repo = ref.read(itemRepositoryProvider);
      if (updated.isEmpty) {
        await repo.removeItemFromGroup(companyId, item.itemId);
      } else {
        await repo.assignItemsToGroup(companyId, updated, [item.itemId]);
      }
      ref.invalidate(companyItemsStreamProvider);

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Item group updated to "${updated.isEmpty ? "None" : updated}".'),
            backgroundColor: AppColors.success,
          ),
        );
      }
    }
  }

  Future<void> _showAddItemsToGroup(
    BuildContext context,
    String companyId,
    GroupModel group,
    List<ItemModel> allItems,
  ) async {
    final unassignedItems = allItems.where((i) =>
        (i.underGroup ?? '').trim().toLowerCase() != group.groupName.trim().toLowerCase()).toList();

    final selectedIds = <String>{};
    String filter = '';

    final toAdd = await showDialog<List<String>>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (dialogCtx, setSelectorState) {
          final itemsToShow = unassignedItems.where((i) {
            if (filter.isEmpty) return true;
            return i.itemDescription.toLowerCase().contains(filter) ||
                i.itemNo.toLowerCase().contains(filter);
          }).toList();

          return AlertDialog(
            title: Text('Assign Items to "${group.groupName}"', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            content: SizedBox(
              width: 500,
              height: 400,
              child: Column(
                children: [
                  TextField(
                    decoration: const InputDecoration(
                      hintText: 'Search items by description or Matl No...',
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
                        ? const Center(child: Text('No available items to assign.'))
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
                                  'Matl No: ${it.itemNo} • Current Group: ${it.underGroup ?? "None"}',
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
              TextButton(onPressed: () => Navigator.pop(dialogCtx, null), child: const Text('Cancel')),
              ElevatedButton(
                onPressed: selectedIds.isEmpty ? null : () => Navigator.pop(dialogCtx, selectedIds.toList()),
                child: Text('Assign (${selectedIds.length})'),
              ),
            ],
          );
        },
      ),
    );

    if (toAdd != null && toAdd.isNotEmpty) {
      await ref.read(itemRepositoryProvider).assignItemsToGroup(companyId, group.groupName, toAdd);
      ref.invalidate(companyItemsStreamProvider);

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${toAdd.length} item(s) assigned to "${group.groupName}".'),
            backgroundColor: AppColors.success,
          ),
        );
      }
    }
  }
}
