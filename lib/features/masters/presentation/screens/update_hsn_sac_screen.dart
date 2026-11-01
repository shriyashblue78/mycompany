import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_sizes.dart';
import '../../../../core/widgets/erp_drawer.dart';
import '../../../../core/widgets/polish_widgets.dart';
import '../../../../core/widgets/responsive_layout.dart';
import '../../../../core/widgets/responsive_widgets.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../domain/models/group_model.dart';
import '../../domain/models/hsn_sac_model.dart';
import '../../domain/models/item_model.dart';
import '../providers/group_provider.dart';
import '../providers/hsn_sac_provider.dart';
import '../providers/item_provider.dart';

class UpdateHsnSacScreen extends ConsumerStatefulWidget {
  const UpdateHsnSacScreen({super.key});

  @override
  ConsumerState<UpdateHsnSacScreen> createState() => _UpdateHsnSacScreenState();
}

class _HsnSacRowState {
  final ItemModel item;
  final TextEditingController hsnSacController;
  final String originalHsnSac;

  _HsnSacRowState({
    required this.item,
    required this.hsnSacController,
    required this.originalHsnSac,
  });

  void dispose() {
    hsnSacController.dispose();
  }
}

class _UpdateHsnSacScreenState extends ConsumerState<UpdateHsnSacScreen> {
  // Step 1: Controls
  String? _selectedGroupId;
  GroupModel? _selectedGroup;
  String _orderBy = 'Code'; // 'Code', 'Description', 'Item No'

  // Step 2 / Spreadsheet State
  GroupModel? _confirmedGroup;
  List<_HsnSacRowState> _rowStates = [];
  bool _isSaving = false;
  String? _statusMessage;
  String _searchFilter = '';

  @override
  void dispose() {
    _clearRows();
    super.dispose();
  }

  void _clearRows() {
    for (final r in _rowStates) {
      r.dispose();
    }
    _rowStates = [];
  }

  void _onContinue(List<ItemModel> allItems) {
    if (_selectedGroup == null) return;

    final group = _selectedGroup!;
    final groupNameLower = group.groupName.trim().toLowerCase();

    // Find all items belonging to selected group
    final matchedItems = allItems.where((i) {
      final itemGroup = (i.underGroup ?? '').trim().toLowerCase();
      return itemGroup == groupNameLower;
    }).toList();

    // Order items according to Order By selection
    if (_orderBy == 'Code') {
      matchedItems.sort((a, b) => (a.hsnSac ?? '').compareTo(b.hsnSac ?? ''));
    } else if (_orderBy == 'Description') {
      matchedItems.sort((a, b) => a.itemDescription.toLowerCase().compareTo(b.itemDescription.toLowerCase()));
    } else if (_orderBy == 'Item No') {
      matchedItems.sort((a, b) => a.itemNo.toLowerCase().compareTo(b.itemNo.toLowerCase()));
    }

    _clearRows();

    _rowStates = matchedItems.map((item) {
      final currentHsn = item.hsnSac ?? '';
      return _HsnSacRowState(
        item: item,
        hsnSacController: TextEditingController(text: currentHsn),
        originalHsnSac: currentHsn,
      );
    }).toList();

    setState(() {
      _confirmedGroup = group;
      _statusMessage = null;
      _searchFilter = '';
    });
  }

  void _onCancel() {
    setState(() {
      _confirmedGroup = null;
      _statusMessage = null;
      _searchFilter = '';
    });
    _clearRows();
  }

  Future<void> _handleSave(String companyId) async {
    final updates = <String, String>{};

    for (final row in _rowStates) {
      final newHsn = row.hsnSacController.text.trim();
      if (newHsn != row.originalHsnSac) {
        updates[row.item.itemId] = newHsn;
      }
    }

    if (updates.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No changes detected in HSN/SAC codes.')),
      );
      return;
    }

    setState(() {
      _isSaving = true;
      _statusMessage = null;
    });

    try {
      final itemRepo = ref.read(itemRepositoryProvider);
      final count = await itemRepo.updateItemsHsnSac(companyId, updates);

      ref.invalidate(companyItemsStreamProvider);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('HSN/SAC updated successfully for $count item(s).'),
            backgroundColor: AppColors.success,
          ),
        );
        setState(() {
          _isSaving = false;
          _confirmedGroup = null;
          _selectedGroupId = null;
          _selectedGroup = null;
        });
        _clearRows();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isSaving = false;
          _statusMessage = 'Failed to save HSN/SAC updates: $e';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final groupsAsync = ref.watch(companyGroupsStreamProvider);
    final itemsAsync = ref.watch(companyItemsStreamProvider);
    final hsnSacAsync = ref.watch(companyHsnSacStreamProvider);
    final authState = ref.watch(authProvider);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final isMobile = ResponsiveLayout.isMobile(context);

    final role = authState.selectedRole ?? 'Employee';
    final canManage = role == 'Owner' || role == 'Accountant';
    final companyId = authState.user?.companyId ?? '';

    final allGroups = groupsAsync.valueOrNull ?? [];
    final allItems = itemsAsync.valueOrNull ?? [];
    final allHsnSacList = hsnSacAsync.valueOrNull ?? [];

    final appBar = AppBar(
      title: const Text(
        'Update HSN/SAC',
        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
      ),
      elevation: 0,
      leading: _confirmedGroup != null
          ? IconButton(
              icon: const Icon(Icons.arrow_back_rounded),
              tooltip: 'Back to Group Selection',
              onPressed: _onCancel,
            )
          : null,
      actions: [
        Padding(
          padding: const EdgeInsets.only(right: AppSizes.p16),
          child: TextButton.icon(
            onPressed: () => context.push('/masters/hsn-sac'),
            icon: const Icon(Icons.tag_rounded, size: 18),
            label: const Text('HSN/SAC Master'),
          ),
        ),
      ],
    );

    return ResponsiveScaffold(
      appBar: appBar,
      drawer: const ERPDrawer(),
      body: _confirmedGroup == null
          ? _buildStep1Selector(
              context: context,
              allGroups: allGroups,
              allItems: allItems,
              groupsAsync: groupsAsync,
              theme: theme,
              isDark: isDark,
              isMobile: isMobile,
            )
          : _buildStep2Spreadsheet(
              context: context,
              group: _confirmedGroup!,
              allHsnSacList: allHsnSacList,
              companyId: companyId,
              canManage: canManage,
              theme: theme,
              isDark: isDark,
              isMobile: isMobile,
            ),
    );
  }

  /// Step 1: Initial Screen - Group Name & Order By Dropdowns + Continue
  Widget _buildStep1Selector({
    required BuildContext context,
    required List<GroupModel> allGroups,
    required List<ItemModel> allItems,
    required AsyncValue<List<GroupModel>> groupsAsync,
    required ThemeData theme,
    required bool isDark,
    required bool isMobile,
  }) {
    final borderColor = isDark ? AppColors.borderDark : const Color(0xFFE5E7EB);
    final cardBgColor = isDark ? AppColors.surfaceDark : Colors.white;

    return SingleChildScrollView(
      padding: EdgeInsets.all(isMobile ? AppSizes.p16 : AppSizes.p24),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 820),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header Card
              Container(
                padding: EdgeInsets.all(isMobile ? AppSizes.p16 : AppSizes.p24),
                decoration: BoxDecoration(
                  color: cardBgColor,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: borderColor),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.03),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: const Color(0xFF8B5CF6).withOpacity(0.12),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(
                            Icons.tune_rounded,
                            color: Color(0xFF8B5CF6),
                            size: 26,
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Update HSN/SAC',
                                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Select a Group Name and sorting order to display and update HSN/SAC codes for its associated items.',
                                style: TextStyle(
                                  fontSize: 13,
                                  color: isDark ? Colors.white60 : const Color(0xFF4B5563),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    const Divider(height: 1),
                    const SizedBox(height: 20),

                    // Controls Row (Group Name + Order By)
                    groupsAsync.when(
                      data: (groups) {
                        if (groups.isEmpty) {
                          return Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: isDark ? Colors.grey.shade900 : const Color(0xFFF9FAFB),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: borderColor),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.info_outline_rounded, size: 20, color: Colors.grey),
                                const SizedBox(width: 10),
                                const Expanded(
                                  child: Text(
                                    'No groups found in Group Master. Please create item groups first.',
                                    style: TextStyle(fontSize: 13.5, color: Colors.grey),
                                  ),
                                ),
                                TextButton(
                                  onPressed: () => context.push('/masters/groups'),
                                  child: const Text('Go to Group Master'),
                                ),
                              ],
                            ),
                          );
                        }

                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            // 1. Group Name Dropdown
                            Text(
                              'Group Name *',
                              style: TextStyle(
                                fontSize: 13.5,
                                fontWeight: FontWeight.w600,
                                color: isDark ? const Color(0xFFD1D5DB) : const Color(0xFF374151),
                              ),
                            ),
                            const SizedBox(height: 8),
                            Container(
                              decoration: BoxDecoration(
                                color: isDark ? Colors.grey.shade900 : const Color(0xFFF9FAFB),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: DropdownButtonFormField<String>(
                                value: _selectedGroupId,
                                isExpanded: true,
                                decoration: InputDecoration(
                                  hintText: 'Select Group Name...',
                                  hintStyle: TextStyle(
                                    fontSize: 14,
                                    color: isDark ? Colors.white54 : const Color(0xFF6B7280),
                                  ),
                                  prefixIcon: const Icon(Icons.folder_special_rounded, size: 20),
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(8),
                                    borderSide: BorderSide(color: borderColor),
                                  ),
                                  enabledBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(8),
                                    borderSide: BorderSide(color: borderColor),
                                  ),
                                ),
                                items: [
                                  for (final g in groups)
                                    DropdownMenuItem<String>(
                                      value: g.groupId,
                                      child: Text(
                                        (g.parentGroupName != null && g.parentGroupName!.isNotEmpty)
                                            ? '${g.groupName} (under ${g.parentGroupName})'
                                            : g.groupName,
                                        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                ],
                                onChanged: (val) {
                                  setState(() {
                                    _selectedGroupId = val;
                                    _selectedGroup = groups.where((g) => g.groupId == val).firstOrNull;
                                  });
                                },
                              ),
                            ),
                            const SizedBox(height: 18),

                            // 2. Order By Dropdown (Code default)
                            Text(
                              'Order By',
                              style: TextStyle(
                                fontSize: 13.5,
                                fontWeight: FontWeight.w600,
                                color: isDark ? const Color(0xFFD1D5DB) : const Color(0xFF374151),
                              ),
                            ),
                            const SizedBox(height: 8),
                            Container(
                              decoration: BoxDecoration(
                                color: isDark ? Colors.grey.shade900 : const Color(0xFFF9FAFB),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: DropdownButtonFormField<String>(
                                value: _orderBy,
                                isExpanded: true,
                                decoration: InputDecoration(
                                  prefixIcon: const Icon(Icons.sort_rounded, size: 20),
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(8),
                                    borderSide: BorderSide(color: borderColor),
                                  ),
                                  enabledBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(8),
                                    borderSide: BorderSide(color: borderColor),
                                  ),
                                ),
                                items: const [
                                  DropdownMenuItem<String>(
                                    value: 'Code',
                                    child: Text('Code (HSN/SAC Code)', style: TextStyle(fontSize: 14)),
                                  ),
                                  DropdownMenuItem<String>(
                                    value: 'Description',
                                    child: Text('Item Description', style: TextStyle(fontSize: 14)),
                                  ),
                                  DropdownMenuItem<String>(
                                    value: 'Item No',
                                    child: Text('Matl / Item No.', style: TextStyle(fontSize: 14)),
                                  ),
                                ],
                                onChanged: (val) {
                                  if (val != null) setState(() => _orderBy = val);
                                },
                              ),
                            ),
                            const SizedBox(height: 24),

                            // Continue Action Button
                            Row(
                              mainAxisAlignment: MainAxisAlignment.end,
                              children: [
                                SizedBox(
                                  height: 46,
                                  child: ElevatedButton.icon(
                                    onPressed: _selectedGroup != null
                                        ? () => _onContinue(allItems)
                                        : null,
                                    icon: const Icon(Icons.arrow_forward_rounded, size: 18),
                                    label: const Text(
                                      'Continue to HSN/SAC Form',
                                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                                    ),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: AppColors.primaryLight,
                                      foregroundColor: Colors.white,
                                      disabledBackgroundColor: isDark ? Colors.grey.shade800 : Colors.grey.shade300,
                                      disabledForegroundColor: Colors.grey.shade500,
                                      elevation: 0,
                                      padding: const EdgeInsets.symmetric(horizontal: 24),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        );
                      },
                      loading: () => const Padding(
                        padding: EdgeInsets.symmetric(vertical: 24),
                        child: Center(child: CircularProgressIndicator()),
                      ),
                      error: (err, _) => Text('Error loading groups: $err', style: const TextStyle(color: AppColors.error)),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: AppSizes.p24),

              // Existing Groups List quick-pick
              if (allGroups.isNotEmpty)
                Container(
                  decoration: BoxDecoration(
                    color: cardBgColor,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: borderColor),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        color: isDark ? const Color(0xFF161F2E) : const Color(0xFFF8FAFC),
                        child: Row(
                          children: [
                            Text(
                              'Available Groups (${allGroups.length})',
                              style: TextStyle(
                                fontSize: 13.5,
                                fontWeight: FontWeight.w700,
                                color: isDark ? const Color(0xFFD1D5DB) : const Color(0xFF1F2937),
                              ),
                            ),
                            const Spacer(),
                            Text(
                              'Tap any group to load HSN/SAC table',
                              style: TextStyle(
                                fontSize: 12,
                                color: isDark ? Colors.white54 : const Color(0xFF6B7280),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const Divider(height: 1, thickness: 1),
                      ListView.separated(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: allGroups.length,
                        separatorBuilder: (_, __) => Divider(height: 1, thickness: 1, color: borderColor),
                        itemBuilder: (context, idx) {
                          final g = allGroups[idx];
                          final gItems = allItems.where((i) =>
                              (i.underGroup ?? '').trim().toLowerCase() ==
                              g.groupName.trim().toLowerCase()).toList();

                          return ListTile(
                            dense: true,
                            leading: Container(
                              width: 32,
                              height: 32,
                              decoration: BoxDecoration(
                                color: const Color(0xFF8B5CF6).withOpacity(isDark ? 0.22 : 0.12),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Icon(Icons.folder_special_rounded, color: Color(0xFF8B5CF6), size: 16),
                            ),
                            title: Text(
                              g.groupName,
                              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13.5),
                            ),
                            subtitle: g.parentGroupName != null && g.parentGroupName!.isNotEmpty
                                ? Text(
                                    '↳ Under: ${g.parentGroupName}',
                                    style: TextStyle(
                                      fontSize: 11.5,
                                      color: isDark ? Colors.purple.shade300 : Colors.purple.shade800,
                                    ),
                                  )
                                : null,
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                  decoration: BoxDecoration(
                                    color: isDark ? Colors.grey.shade800 : const Color(0xFFF3F4F6),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    '${gItems.length} items',
                                    style: TextStyle(
                                      fontSize: 11.5,
                                      fontWeight: FontWeight.w600,
                                      color: isDark ? Colors.white70 : const Color(0xFF4B5563),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                const Icon(Icons.arrow_forward_ios_rounded, size: 13, color: Colors.grey),
                              ],
                            ),
                            onTap: () {
                              setState(() {
                                _selectedGroupId = g.groupId;
                                _selectedGroup = g;
                              });
                              _onContinue(allItems);
                            },
                          );
                        },
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  /// Step 2: Spreadsheet-style HSN/SAC update table
  Widget _buildStep2Spreadsheet({
    required BuildContext context,
    required GroupModel group,
    required List<HsnSacModel> allHsnSacList,
    required String companyId,
    required bool canManage,
    required ThemeData theme,
    required bool isDark,
    required bool isMobile,
  }) {
    final borderColor = isDark ? AppColors.borderDark : const Color(0xFFE5E7EB);
    final headerBgColor = isDark ? const Color(0xFF161F2E) : const Color(0xFFF8FAFC);
    final cardBgColor = isDark ? AppColors.surfaceDark : Colors.white;

    final filteredRows = _rowStates.where((r) {
      if (_searchFilter.isEmpty) return true;
      final q = _searchFilter.toLowerCase();
      return r.item.itemDescription.toLowerCase().contains(q) ||
          r.item.itemNo.toLowerCase().contains(q) ||
          r.hsnSacController.text.toLowerCase().contains(q);
    }).toList();

    return SingleChildScrollView(
      padding: EdgeInsets.symmetric(
        horizontal: isMobile ? AppSizes.p12 : AppSizes.p24,
        vertical: isMobile ? AppSizes.p12 : AppSizes.p16,
      ),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1150),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Top Info Banner Card
              Container(
                padding: EdgeInsets.symmetric(
                  horizontal: isMobile ? 14 : 20,
                  vertical: isMobile ? 12 : 14,
                ),
                decoration: BoxDecoration(
                  color: cardBgColor,
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
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: const Color(0xFF8B5CF6).withOpacity(0.15),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(Icons.folder_special_rounded, color: Color(0xFF8B5CF6), size: 20),
                        ),
                        const SizedBox(width: 12),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Text(
                                  'Group: ',
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: isDark ? Colors.white60 : const Color(0xFF6B7280),
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                Text(
                                  group.groupName,
                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                                ),
                                if (group.parentGroupName != null && group.parentGroupName!.isNotEmpty) ...[
                                  const SizedBox(width: 8),
                                  Text(
                                    '(under ${group.parentGroupName})',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: isDark ? Colors.purple.shade300 : Colors.purple.shade800,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Ordered By: $_orderBy  •  Total Items: ${_rowStates.length}',
                              style: TextStyle(
                                fontSize: 11.5,
                                color: isDark ? Colors.white60 : const Color(0xFF6B7280),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),

                    // Change Group Action
                    OutlinedButton.icon(
                      onPressed: _onCancel,
                      icon: const Icon(Icons.swap_horiz_rounded, size: 16),
                      label: const Text('Change Group / Order', style: TextStyle(fontSize: 12.5)),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: AppSizes.p12),

              // Search Filter Bar
              if (_rowStates.isNotEmpty)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: cardBgColor,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: borderColor),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: SizedBox(
                          height: 38,
                          child: TextField(
                            onChanged: (val) => setState(() => _searchFilter = val),
                            style: const TextStyle(fontSize: 13),
                            decoration: InputDecoration(
                              hintText: 'Search items or HSN/SAC codes in this group...',
                              hintStyle: TextStyle(
                                fontSize: 12.5,
                                color: isDark ? Colors.white54 : const Color(0xFF6B7280),
                              ),
                              prefixIcon: const Icon(Icons.search_rounded, size: 18),
                              suffixIcon: _searchFilter.isNotEmpty
                                  ? IconButton(
                                      icon: const Icon(Icons.clear_rounded, size: 16),
                                      onPressed: () => setState(() => _searchFilter = ''),
                                    )
                                  : null,
                              isDense: true,
                              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                              border: InputBorder.none,
                            ),
                          ),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: isDark ? Colors.grey.shade800 : const Color(0xFFF3F4F6),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          '${filteredRows.length} items',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: isDark ? Colors.white70 : const Color(0xFF4B5563),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

              if (_statusMessage != null) ...[
                const SizedBox(height: AppSizes.p12),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: AppColors.error.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: AppColors.error.withOpacity(0.3)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.error_outline_rounded, color: AppColors.error, size: 18),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _statusMessage!,
                          style: const TextStyle(color: AppColors.error, fontSize: 13),
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              const SizedBox(height: AppSizes.p12),

              // Spreadsheet Table
              Container(
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
                child: _rowStates.isEmpty
                    ? Padding(
                        padding: const EdgeInsets.symmetric(vertical: 48, horizontal: 24),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.inventory_2_outlined, size: 48, color: Colors.grey),
                            const SizedBox(height: 12),
                            Text(
                              'No items assigned to group "${group.groupName}".',
                              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                            ),
                            const SizedBox(height: 6),
                            const Text(
                              'Please associate items to this group in Item Master or Update Item Group.',
                              style: TextStyle(fontSize: 13, color: Colors.grey),
                            ),
                            const SizedBox(height: 18),
                            OutlinedButton.icon(
                              onPressed: _onCancel,
                              icon: const Icon(Icons.arrow_back_rounded, size: 16),
                              label: const Text('Back to Group Selection'),
                            ),
                          ],
                        ),
                      )
                    : LayoutBuilder(
                        builder: (context, constraints) {
                          const double minTableWidth = 750;
                          final double tableWidth = constraints.maxWidth > minTableWidth
                              ? constraints.maxWidth
                              : minTableWidth;

                          return SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            child: SizedBox(
                              width: tableWidth,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  // Table Header
                                  Container(
                                    height: 42,
                                    decoration: BoxDecoration(
                                      color: headerBgColor,
                                      border: Border(bottom: BorderSide(color: borderColor, width: 1.5)),
                                    ),
                                    child: Row(
                                      children: [
                                        _buildHeaderCell('Sr. No.', width: 75, alignment: Alignment.center, isDark: isDark),
                                        _buildHeaderCell('Matl No.', width: 150, isDark: isDark),
                                        _buildHeaderCell('Item Description', flex: 4, minWidth: 220, isDark: isDark),
                                        _buildHeaderCell('HSN / SAC Code', width: 200, isDark: isDark),
                                        _buildHeaderCell('Quick Pick', width: 110, alignment: Alignment.center, isDark: isDark),
                                      ],
                                    ),
                                  ),

                                  // Table Rows
                                  ListView.separated(
                                    shrinkWrap: true,
                                    physics: const NeverScrollableScrollPhysics(),
                                    itemCount: filteredRows.length,
                                    separatorBuilder: (_, __) => Divider(height: 1, thickness: 1, color: borderColor),
                                    itemBuilder: (context, index) {
                                      final row = filteredRows[index];

                                      return Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                        child: Row(
                                          crossAxisAlignment: CrossAxisAlignment.center,
                                          children: [
                                            // Sr. No.
                                            SizedBox(
                                              width: 75,
                                              child: Center(
                                                child: Text(
                                                  '${index + 1}',
                                                  style: TextStyle(
                                                    fontWeight: FontWeight.w600,
                                                    fontSize: 13,
                                                    color: isDark ? Colors.white70 : const Color(0xFF4B5563),
                                                  ),
                                                ),
                                              ),
                                            ),

                                            // Matl No.
                                            SizedBox(
                                              width: 150,
                                              child: Container(
                                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                                decoration: BoxDecoration(
                                                  color: isDark ? Colors.white.withOpacity(0.06) : Colors.grey.shade100,
                                                  borderRadius: BorderRadius.circular(4),
                                                ),
                                                child: Text(
                                                  row.item.itemNo,
                                                  style: const TextStyle(
                                                    fontFamily: 'monospace',
                                                    fontWeight: FontWeight.bold,
                                                    fontSize: 12.5,
                                                  ),
                                                  overflow: TextOverflow.ellipsis,
                                                ),
                                              ),
                                            ),
                                            const SizedBox(width: 10),

                                            // Item Description
                                            Expanded(
                                              flex: 4,
                                              child: ConstrainedBox(
                                                constraints: const BoxConstraints(minWidth: 220),
                                                child: Column(
                                                  crossAxisAlignment: CrossAxisAlignment.start,
                                                  mainAxisSize: MainAxisSize.min,
                                                  children: [
                                                    Text(
                                                      row.item.itemDescription,
                                                      style: const TextStyle(
                                                        fontWeight: FontWeight.w600,
                                                        fontSize: 13.5,
                                                      ),
                                                      maxLines: 2,
                                                      overflow: TextOverflow.ellipsis,
                                                    ),
                                                    Text(
                                                      'Category: ${row.item.category} • Unit: ${row.item.stockUnit}',
                                                      style: TextStyle(
                                                        fontSize: 11,
                                                        color: isDark ? Colors.white54 : const Color(0xFF6B7280),
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            ),
                                            const SizedBox(width: 10),

                                            // Editable HSN/SAC Field
                                            SizedBox(
                                              width: 200,
                                              child: SizedBox(
                                                height: 38,
                                                child: TextFormField(
                                                  controller: row.hsnSacController,
                                                  style: const TextStyle(
                                                    fontFamily: 'monospace',
                                                    fontWeight: FontWeight.w600,
                                                    fontSize: 13,
                                                  ),
                                                  decoration: InputDecoration(
                                                    hintText: 'Enter HSN/SAC Code',
                                                    hintStyle: const TextStyle(fontSize: 12, color: Colors.grey),
                                                    contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                                    border: OutlineInputBorder(
                                                      borderRadius: BorderRadius.circular(6),
                                                      borderSide: BorderSide(color: borderColor),
                                                    ),
                                                    enabledBorder: OutlineInputBorder(
                                                      borderRadius: BorderRadius.circular(6),
                                                      borderSide: BorderSide(color: borderColor),
                                                    ),
                                                    isDense: true,
                                                  ),
                                                ),
                                              ),
                                            ),
                                            const SizedBox(width: 10),

                                            // Quick Pick from Master
                                            SizedBox(
                                              width: 110,
                                              child: Center(
                                                child: OutlinedButton(
                                                  style: OutlinedButton.styleFrom(
                                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                                                  ),
                                                  onPressed: () => _pickHsnFromMaster(context, row, allHsnSacList),
                                                  child: const Row(
                                                    mainAxisSize: MainAxisSize.min,
                                                    children: [
                                                      Icon(Icons.list_alt_rounded, size: 14),
                                                      SizedBox(width: 4),
                                                      Text('Pick', style: TextStyle(fontSize: 11.5)),
                                                    ],
                                                  ),
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      );
                                    },
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
              ),

              const SizedBox(height: AppSizes.p16),

              // Bottom Actions Bar
              if (_rowStates.isNotEmpty)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                  decoration: BoxDecoration(
                    color: cardBgColor,
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
                  child: Row(
                    children: [
                      Text(
                        'Total ${_rowStates.length} items ready for HSN/SAC update',
                        style: TextStyle(
                          fontSize: 13,
                          color: isDark ? Colors.white70 : const Color(0xFF4B5563),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const Spacer(),
                      OutlinedButton(
                        onPressed: _isSaving ? null : _onCancel,
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                        ),
                        child: const Text('Cancel'),
                      ),
                      const SizedBox(width: 12),
                      if (canManage)
                        ElevatedButton.icon(
                          onPressed: _isSaving ? null : () => _handleSave(companyId),
                          icon: _isSaving
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                )
                              : const Icon(Icons.save_rounded, size: 18),
                          label: Text(
                            _isSaving ? 'Saving...' : 'Save HSN/SAC',
                            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primaryLight,
                            foregroundColor: Colors.white,
                            elevation: 0,
                            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                          ),
                        ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  void _pickHsnFromMaster(BuildContext context, _HsnSacRowState row, List<HsnSacModel> allHsnSacList) {
    if (allHsnSacList.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No HSN/SAC codes in master. You can enter code manually.')),
      );
      return;
    }

    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        title: const Text('Select HSN/SAC Code', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        content: SizedBox(
          width: 400,
          height: 350,
          child: ListView.separated(
            itemCount: allHsnSacList.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (context, idx) {
              final hsn = allHsnSacList[idx];
              return ListTile(
                dense: true,
                title: Text(
                  hsn.code,
                  style: const TextStyle(fontFamily: 'monospace', fontWeight: FontWeight.bold),
                ),
                subtitle: Text(
                  hsn.description,
                  style: const TextStyle(fontSize: 12),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                trailing: Text(
                  hsn.gstCategory ?? hsn.type,
                  style: const TextStyle(fontSize: 11, color: Colors.grey),
                ),
                onTap: () {
                  setState(() {
                    row.hsnSacController.text = hsn.code;
                  });
                  Navigator.pop(ctx);
                },
              );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
        ],
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
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 12.5,
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
}
