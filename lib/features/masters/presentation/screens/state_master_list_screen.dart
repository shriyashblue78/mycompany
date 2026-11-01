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
import '../../domain/models/state_master_model.dart';
import '../providers/state_master_provider.dart';

class StateMasterListScreen extends ConsumerStatefulWidget {
  const StateMasterListScreen({super.key});

  @override
  ConsumerState<StateMasterListScreen> createState() => _StateMasterListScreenState();
}

class _StateMasterListScreenState extends ConsumerState<StateMasterListScreen> {
  @override
  Widget build(BuildContext context) {
    final statesAsync = ref.watch(filteredStatesProvider);
    final authState = ref.watch(authProvider);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final isMobile = ResponsiveLayout.isMobile(context);

    final role = authState.selectedRole ?? 'Employee';
    final canManage = role == 'Owner' || role == 'Accountant';
    final companyId = authState.user?.companyId ?? '';

    final appBar = AppBar(
      title: const Text(
        'State Master',
        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
      ),
      elevation: 0,
    );

    return statesAsync.when(
      data: (states) {
        final body = RefreshIndicator(
          onRefresh: () async {
            ref.invalidate(companyStatesStreamProvider);
          },
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: EdgeInsets.symmetric(
              horizontal: isMobile ? AppSizes.p12 : AppSizes.p24,
              vertical: isMobile ? AppSizes.p12 : AppSizes.p16,
            ),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1100),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _buildHeaderBar(
                      context: context,
                      companyId: companyId,
                      canManage: canManage,
                      theme: theme,
                      isDark: isDark,
                      isMobile: isMobile,
                      count: states.length,
                    ),
                    const SizedBox(height: AppSizes.p12),
                    if (states.isEmpty)
                      EmptyStateWidget(
                        icon: Icons.map_outlined,
                        title: 'No States Found',
                        description: ref.watch(stateMasterSearchQueryProvider).isNotEmpty
                            ? 'No states or union territories match your search query.'
                            : 'Indian states and GST codes are being initialized...',
                      )
                    else
                      _buildStateDataTable(
                        context: context,
                        states: states,
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
                Text('Error loading State Master: $err'),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: () => ref.invalidate(companyStatesStreamProvider),
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
              maxWidth: isMobile ? double.infinity : 360,
              minWidth: isMobile ? double.infinity : 260,
            ),
            child: SizedBox(
              height: 40,
              child: TextField(
                onChanged: (val) => ref.read(stateMasterSearchQueryProvider.notifier).state = val,
                style: TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w500,
                  color: isDark ? Colors.white : const Color(0xFF111827),
                ),
                decoration: InputDecoration(
                  hintText: 'Search by State Name or GST Code...',
                  hintStyle: TextStyle(
                    fontSize: 13,
                    color: isDark ? Colors.white54 : const Color(0xFF6B7280),
                  ),
                  prefixIcon: Icon(
                    Icons.search_rounded,
                    size: 19,
                    color: isDark ? Colors.white70 : const Color(0xFF4B5563),
                  ),
                  suffixIcon: ref.watch(stateMasterSearchQueryProvider).isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear_rounded, size: 16),
                          splashRadius: 16,
                          onPressed: () => ref.read(stateMasterSearchQueryProvider.notifier).state = '',
                        )
                      : null,
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
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

          // Total count & + New Button
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
                    onPressed: () => _openStateDialog(context, companyId),
                    icon: const Icon(Icons.add_rounded, size: 18),
                    label: const Text(
                      'New State',
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

  Widget _buildStateDataTable({
    required BuildContext context,
    required List<StateMasterModel> states,
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
          const double minTableWidth = 650;
          final double tableWidth = constraints.maxWidth > minTableWidth
              ? constraints.maxWidth
              : minTableWidth;

          return SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: SizedBox(
              width: tableWidth,
              child: Column(
                children: [
                  // Table Header: Sr. No. | State Name | State Code | Actions
                  Container(
                    height: 42,
                    decoration: BoxDecoration(
                      color: headerBgColor,
                      border: Border(bottom: BorderSide(color: borderColor, width: 1.5)),
                    ),
                    child: Row(
                      children: [
                        _buildHeaderCell('Sr. No.', width: 80, alignment: Alignment.center, isDark: isDark),
                        _buildHeaderCell('State Name', flex: 5, minWidth: 220, isDark: isDark),
                        _buildHeaderCell('State Code', flex: 3, minWidth: 140, isDark: isDark),
                        _buildHeaderCell('Actions', width: 120, alignment: Alignment.centerRight, isDark: isDark),
                      ],
                    ),
                  ),

                  // Table Rows
                  ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: states.length,
                    separatorBuilder: (_, __) => Divider(height: 1, thickness: 1, color: borderColor),
                    itemBuilder: (context, index) {
                      final state = states[index];

                      return Container(
                        height: 48,
                        padding: const EdgeInsets.symmetric(horizontal: 14),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            // Sr. No.
                            SizedBox(
                              width: 80,
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

                            // State Name
                            Expanded(
                              flex: 5,
                              child: ConstrainedBox(
                                constraints: const BoxConstraints(minWidth: 220),
                                child: Row(
                                  children: [
                                    Container(
                                      width: 28,
                                      height: 28,
                                      decoration: BoxDecoration(
                                        color: const Color(0xFF0284C7).withOpacity(isDark ? 0.22 : 0.1),
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: const Icon(Icons.location_on_rounded, color: Color(0xFF0284C7), size: 15),
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: Text(
                                        state.stateName,
                                        style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13.5),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),

                            // State Code (GST)
                            Expanded(
                              flex: 3,
                              child: ConstrainedBox(
                                constraints: const BoxConstraints(minWidth: 140),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                  decoration: BoxDecoration(
                                    color: isDark ? Colors.grey.shade800 : const Color(0xFFF3F4F6),
                                    borderRadius: BorderRadius.circular(4),
                                    border: Border.all(
                                      color: isDark ? Colors.grey.shade700 : const Color(0xFFE5E7EB),
                                    ),
                                  ),
                                  child: Text(
                                    state.stateCode,
                                    style: TextStyle(
                                      fontSize: 12.5,
                                      fontFamily: 'monospace',
                                      fontWeight: FontWeight.bold,
                                      color: isDark ? const Color(0xFF38BDF8) : const Color(0xFF0369A1),
                                    ),
                                  ),
                                ),
                              ),
                            ),

                            // Actions
                            SizedBox(
                              width: 120,
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.end,
                                children: [
                                  _buildSubtleActionButton(
                                    icon: Icons.visibility_outlined,
                                    tooltip: 'View Details',
                                    color: const Color(0xFF2563EB),
                                    onPressed: () => _viewStateDetails(context, state),
                                  ),
                                  if (canManage) ...[
                                    _buildSubtleActionButton(
                                      icon: Icons.edit_outlined,
                                      tooltip: 'Edit State',
                                      color: const Color(0xFF059669),
                                      onPressed: () => _openStateDialog(context, companyId, state: state),
                                    ),
                                    _buildSubtleActionButton(
                                      icon: Icons.delete_outline_rounded,
                                      tooltip: 'Delete State',
                                      color: const Color(0xFFDC2626),
                                      onPressed: () => _confirmDelete(context, state, companyId),
                                    ),
                                  ],
                                ],
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

  Widget _buildSubtleActionButton({
    required IconData icon,
    required String tooltip,
    required Color color,
    required VoidCallback onPressed,
  }) {
    return IconButton(
      icon: Icon(icon, size: 17, color: color),
      tooltip: tooltip,
      splashRadius: 18,
      padding: const EdgeInsets.all(6),
      constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
      onPressed: onPressed,
    );
  }

  void _openStateDialog(BuildContext context, String companyId, {StateMasterModel? state}) {
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogCtx) => _StateFormDialog(
        companyId: companyId,
        existingState: state,
      ),
    );
  }

  void _viewStateDetails(BuildContext context, StateMasterModel state) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final dateFmt = DateFormat('dd MMM yyyy, hh:mm a');

    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFF0284C7).withOpacity(0.15),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.location_on_rounded, color: Color(0xFF0284C7), size: 20),
            ),
            const SizedBox(width: 10),
            const Text('State Master Details', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildDetailRow('State Name', state.stateName, isDark),
            const SizedBox(height: 10),
            _buildDetailRow('State Code (GST)', state.stateCode, isDark),
            const SizedBox(height: 10),
            _buildDetailRow('Created At', dateFmt.format(state.createdAt), isDark),
            const SizedBox(height: 10),
            _buildDetailRow('Updated At', dateFmt.format(state.updatedAt), isDark),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value, bool isDark) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 120,
          child: Text(
            label,
            style: TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w600,
              color: isDark ? Colors.white60 : const Color(0xFF6B7280),
            ),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
          ),
        ),
      ],
    );
  }

  Future<void> _confirmDelete(BuildContext context, StateMasterModel state, String companyId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        title: const Text('Delete State', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        content: Text('Are you sure you want to delete state "${state.stateName}" (Code: ${state.stateCode})?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await ref.read(stateMasterRepositoryProvider).deleteState(companyId, state.stateId);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('State "${state.stateName}" deleted successfully.'),
              backgroundColor: AppColors.success,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to delete: $e'), backgroundColor: AppColors.error),
          );
        }
      }
    }
  }
}

class _StateFormDialog extends ConsumerStatefulWidget {
  final String companyId;
  final StateMasterModel? existingState;

  const _StateFormDialog({
    required this.companyId,
    this.existingState,
  });

  @override
  ConsumerState<_StateFormDialog> createState() => _StateFormDialogState();
}

class _StateFormDialogState extends ConsumerState<_StateFormDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _codeController;
  bool _isSaving = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.existingState?.stateName ?? '');
    _codeController = TextEditingController(text: widget.existingState?.stateCode ?? '');
  }

  @override
  void dispose() {
    _nameController.dispose();
    _codeController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    final stateName = _nameController.text.trim();
    final stateCode = _codeController.text.trim();

    setState(() {
      _isSaving = true;
      _errorMessage = null;
    });

    try {
      final repo = ref.read(stateMasterRepositoryProvider);
      final isDup = await repo.isDuplicate(
        widget.companyId,
        stateName,
        stateCode,
        excludeStateId: widget.existingState?.stateId,
      );

      if (isDup) {
        setState(() {
          _isSaving = false;
          _errorMessage = 'A state record with this State Name or State Code already exists.';
        });
        return;
      }

      if (widget.existingState != null) {
        final updated = widget.existingState!.copyWith(
          stateName: stateName,
          stateCode: stateCode,
          updatedAt: DateTime.now(),
        );
        await repo.updateState(widget.companyId, updated);
      } else {
        final newState = StateMasterModel(
          stateId: '',
          companyId: widget.companyId,
          stateName: stateName,
          stateCode: stateCode,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );
        await repo.createState(widget.companyId, newState);
      }

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(widget.existingState != null
                ? 'State updated successfully.'
                : 'State added successfully.'),
            backgroundColor: AppColors.success,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isSaving = false;
          _errorMessage = 'Error saving State: $e';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isEditing = widget.existingState != null;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480),
        child: Padding(
          padding: const EdgeInsets.all(AppSizes.p20),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: const Color(0xFF0284C7).withOpacity(0.12),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(Icons.location_on_rounded, color: Color(0xFF0284C7), size: 20),
                    ),
                    const SizedBox(width: 10),
                    Text(
                      isEditing ? 'Edit State' : 'New State',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                if (_errorMessage != null) ...[
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppColors.error.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: AppColors.error.withOpacity(0.3)),
                    ),
                    child: Text(
                      _errorMessage!,
                      style: const TextStyle(color: AppColors.error, fontSize: 12.5),
                    ),
                  ),
                  const SizedBox(height: 14),
                ],

                // State Name
                TextFormField(
                  controller: _nameController,
                  autofocus: true,
                  textCapitalization: TextCapitalization.words,
                  style: const TextStyle(fontSize: 13.5),
                  decoration: const InputDecoration(
                    labelText: 'State Name *',
                    hintText: 'e.g. Maharashtra, Karnataka',
                    prefixIcon: Icon(Icons.map_outlined, size: 20),
                  ),
                  validator: (val) {
                    if (val == null || val.trim().isEmpty) {
                      return 'State Name is required';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 14),

                // State Code (GST)
                TextFormField(
                  controller: _codeController,
                  keyboardType: TextInputType.number,
                  maxLength: 2,
                  style: const TextStyle(fontSize: 13.5, fontFamily: 'monospace'),
                  decoration: const InputDecoration(
                    labelText: 'State Code (GST) *',
                    hintText: 'e.g. 27, 29, 07',
                    counterText: '',
                    prefixIcon: Icon(Icons.pin_rounded, size: 20),
                  ),
                  validator: (val) {
                    if (val == null || val.trim().isEmpty) {
                      return 'State Code is required';
                    }
                    if (val.trim().length != 2) {
                      return 'State Code must be 2 digits';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 20),

                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: _isSaving ? null : () => Navigator.pop(context),
                      child: const Text('Cancel'),
                    ),
                    const SizedBox(width: 10),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primaryLight,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                      ),
                      onPressed: _isSaving ? null : _submit,
                      child: _isSaving
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                            )
                          : Text(isEditing ? 'Save Changes' : 'Create State'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
