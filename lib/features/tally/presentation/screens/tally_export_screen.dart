import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/constants/app_sizes.dart';
import '../../../../core/widgets/erp_drawer.dart';
import '../../../../core/widgets/responsive_widgets.dart';

class TallySectionItem {
  final String title;
  final IconData icon;
  final Color color;
  final Color bgColor;

  const TallySectionItem({
    required this.title,
    required this.icon,
    required this.color,
    required this.bgColor,
  });
}

class MasterItem {
  final String title;
  final IconData icon;
  final String route;

  const MasterItem(this.title, this.icon, this.route);
}

class TallyExportScreen extends StatefulWidget {
  const TallyExportScreen({super.key});

  @override
  State<TallyExportScreen> createState() => _TallyExportScreenState();
}

class _TallyExportScreenState extends State<TallyExportScreen> {
  bool _showingMasters = false;

  static const List<TallySectionItem> _sections = [
    TallySectionItem(
      title: 'MASTERS',
      icon: Icons.account_tree_outlined,
      color: Color(0xFF1E88E5),
      bgColor: Color(0xFFE3F2FD),
    ),
    TallySectionItem(
      title: 'MATERIAL INWARD',
      icon: Icons.move_to_inbox_outlined,
      color: Color(0xFF00897B),
      bgColor: Color(0xFFE0F2F1),
    ),
    TallySectionItem(
      title: 'MATERIAL OUTWARD',
      icon: Icons.unarchive_outlined,
      color: Color(0xFF8E24AA),
      bgColor: Color(0xFFF3E5F5),
    ),
    TallySectionItem(
      title: 'GST REPORTS',
      icon: Icons.receipt_long_outlined,
      color: Color(0xFFE65100),
      bgColor: Color(0xFFFFF3E0),
    ),
    TallySectionItem(
      title: 'REPORTS',
      icon: Icons.assessment_outlined,
      color: Color(0xFFD32F2F),
      bgColor: Color(0xFFFFEBEE),
    ),
    TallySectionItem(
      title: 'OUTSTANDING',
      icon: Icons.pending_actions_outlined,
      color: Color(0xFF6D4C41),
      bgColor: Color(0xFFEFEBE9),
    ),
    TallySectionItem(
      title: 'UTILITIES',
      icon: Icons.build_circle_outlined,
      color: Color(0xFF546E7A),
      bgColor: Color(0xFFECEFF1),
    ),
  ];

  static const List<MasterItem> _masterItems = [
    MasterItem('Party Master', Icons.business_rounded, '/parties'),
    MasterItem('Category Master', Icons.category_rounded, '/masters/categories'),
    MasterItem('Group Master', Icons.folder_special_rounded, '/masters/groups'),
    MasterItem('Update Item Group', Icons.edit_note_rounded, '/masters/update-item-group'),
    MasterItem('Unit Master', Icons.straighten_rounded, '/masters/units'),
    MasterItem('Item Master', Icons.inventory_2_rounded, '/masters/items'),
    MasterItem('Tax Master', Icons.account_balance_rounded, '/masters/taxes'),
    MasterItem('HSN/SAC Master', Icons.tag_rounded, '/masters/hsn-sac'),
    MasterItem('Process Master', Icons.alt_route_rounded, '/masters/processes'),
    MasterItem('Transaction Type Master', Icons.swap_horiz_rounded, '/masters/transaction-types'),
    MasterItem('Rejection Reason Master', Icons.assignment_late_rounded, '/masters/rejection-reasons'),
    MasterItem('Opening Balance Entry', Icons.account_balance_wallet_rounded, '/masters/opening-balance'),
    MasterItem('PDI Master', Icons.fact_check_rounded, '/masters/pdi'),
    MasterItem('State Master', Icons.location_on_rounded, '/masters/states'),
    MasterItem('Clearance Type Master', Icons.verified_user_rounded, '/masters/clearance-types'),
    MasterItem('Update HSN/SAC', Icons.tune_rounded, '/masters/update-hsn-sac'),
  ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return ResponsiveScaffold(
      appBar: AppBar(
        title: Text(_showingMasters ? 'Tally - Masters' : 'Tally'),
        elevation: 0,
        backgroundColor: theme.colorScheme.surface,
        leading: _showingMasters
            ? IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: () => setState(() => _showingMasters = false),
              )
            : null,
      ),
      drawer: const ERPDrawer(),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppSizes.p24),
          child: Center(
            child: Container(
              constraints: const BoxConstraints(maxWidth: AppSizes.maxContentWidth),
              child: _showingMasters
                  ? _buildMastersView(context, isDark, theme)
                  : _buildSectionsView(context, isDark, theme),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSectionsView(BuildContext context, bool isDark, ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Tally Modules',
          style: theme.textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          'Select a section to proceed',
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.textTheme.bodyMedium?.color?.withValues(alpha: 0.6),
          ),
        ),
        const SizedBox(height: AppSizes.p24),
        LayoutBuilder(
          builder: (context, constraints) {
            int crossAxisCount = 3;
            if (constraints.maxWidth < 600) {
              crossAxisCount = 1;
            } else if (constraints.maxWidth < 950) {
              crossAxisCount = 2;
            }

            return GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _sections.length,
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: crossAxisCount,
                mainAxisSpacing: AppSizes.p16,
                crossAxisSpacing: AppSizes.p16,
                childAspectRatio: 2.3,
              ),
              itemBuilder: (context, index) {
                final item = _sections[index];
                return _buildSectionBox(context, item, isDark, theme);
              },
            );
          },
        ),
      ],
    );
  }

  Widget _buildMastersView(BuildContext context, bool isDark, ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            OutlinedButton.icon(
              onPressed: () => setState(() => _showingMasters = false),
              icon: const Icon(Icons.arrow_back, size: 18),
              label: const Text('Back to Tally'),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Masters',
                    style: theme.textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'All master setups and records',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.textTheme.bodyMedium?.color?.withValues(alpha: 0.6),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSizes.p24),
        LayoutBuilder(
          builder: (context, constraints) {
            int crossAxisCount = 3;
            if (constraints.maxWidth < 600) {
              crossAxisCount = 1;
            } else if (constraints.maxWidth < 950) {
              crossAxisCount = 2;
            }

            return GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _masterItems.length,
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: crossAxisCount,
                mainAxisSpacing: AppSizes.p16,
                crossAxisSpacing: AppSizes.p16,
                childAspectRatio: 2.4,
              ),
              itemBuilder: (context, index) {
                final item = _masterItems[index];
                return _buildMasterTile(context, item, isDark, theme);
              },
            );
          },
        ),
      ],
    );
  }

  Widget _buildSectionBox(
    BuildContext context,
    TallySectionItem item,
    bool isDark,
    ThemeData theme,
  ) {
    final isMasters = item.title == 'MASTERS';

    return Material(
      color: isDark ? theme.cardColor : item.bgColor,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: () {
          if (isMasters) {
            setState(() {
              _showingMasters = true;
            });
          }
        },
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: AppSizes.p20, vertical: AppSizes.p16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isDark ? Colors.white10 : item.color.withValues(alpha: 0.25),
              width: 1.5,
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: isDark ? item.color.withValues(alpha: 0.2) : Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: isDark
                      ? null
                      : [
                          BoxShadow(
                            color: item.color.withValues(alpha: 0.12),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                ),
                child: Icon(
                  item.icon,
                  color: item.color,
                  size: 26,
                ),
              ),
              const SizedBox(width: AppSizes.p16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      item.title,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.5,
                        color: isDark ? Colors.white : theme.colorScheme.onSurface,
                      ),
                    ),
                    if (isMasters) ...[
                      const SizedBox(height: 2),
                      Text(
                        '16 Masters',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: item.color,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              if (isMasters)
                Icon(
                  Icons.arrow_forward_ios_rounded,
                  size: 16,
                  color: item.color,
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMasterTile(
    BuildContext context,
    MasterItem item,
    bool isDark,
    ThemeData theme,
  ) {
    return Material(
      color: isDark ? theme.cardColor : Colors.white,
      borderRadius: BorderRadius.circular(14),
      elevation: isDark ? 0 : 1,
      shadowColor: Colors.black12,
      child: InkWell(
        onTap: () {
          context.push(item.route);
        },
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: isDark ? Colors.white12 : Colors.grey.shade200,
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: theme.colorScheme.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  item.icon,
                  color: theme.colorScheme.primary,
                  size: 22,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  item.title,
                  style: theme.textTheme.bodyLarge?.copyWith(
                    fontWeight: FontWeight.w600,
                    fontSize: 14.5,
                  ),
                ),
              ),
              Icon(
                Icons.arrow_forward_ios_rounded,
                size: 14,
                color: theme.textTheme.bodyMedium?.color?.withValues(alpha: 0.35),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
