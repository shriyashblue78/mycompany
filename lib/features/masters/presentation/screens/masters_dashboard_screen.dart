import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_sizes.dart';
import '../../../../core/widgets/erp_drawer.dart';
import '../../../../core/widgets/responsive_layout.dart';
import '../../../../core/widgets/responsive_widgets.dart';

class MastersDashboardScreen extends ConsumerWidget {
  const MastersDashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final isMobile = ResponsiveLayout.isMobile(context);

    final sections = [
      _MasterSectionItem(
        title: 'Party Master',
        description: 'Manage customers, vendors, suppliers, GSTIN, and billing addresses.',
        icon: Icons.business_rounded,
        color: const Color(0xFF3B82F6), // Blue
        route: '/parties',
      ),
      _MasterSectionItem(
        title: 'Category Master',
        description: 'Organize raw materials, consumables, finished goods, and components.',
        icon: Icons.category_rounded,
        color: const Color(0xFF8B5CF6), // Purple
        route: '/masters/categories',
      ),
      _MasterSectionItem(
        title: 'Group Master',
        description: 'Establish hierarchical item and account groups with parent-child nesting.',
        icon: Icons.folder_special_rounded,
        color: const Color(0xFF14B8A6), // Teal
        route: '/masters/groups',
      ),
      _MasterSectionItem(
        title: 'Update Item Group',
        description: 'Manage item-to-group associations in a spreadsheet-style table with material numbers.',
        icon: Icons.edit_note_rounded,
        color: const Color(0xFF0D9488), // Deep Teal
        route: '/masters/update-item-group',
      ),
      _MasterSectionItem(
        title: 'Unit Master',
        description: 'Define units of measurement (UOM) such as KG, Nos, Meters, Liters.',
        icon: Icons.straighten_rounded,
        color: const Color(0xFF10B981), // Emerald
        route: '/masters/units',
      ),
      _MasterSectionItem(
        title: 'Item Master',
        description: 'Catalog items, parts, specifications, SKU codes, and stock parameters.',
        icon: Icons.inventory_2_rounded,
        color: const Color(0xFFF59E0B), // Amber
        route: '/masters/items',
      ),
      _MasterSectionItem(
        title: 'Tax Master',
        description: 'Configure GST slabs, IGST, CGST, SGST, and tax rate definitions.',
        icon: Icons.account_balance_rounded,
        color: const Color(0xFFEC4899), // Pink
        route: '/masters/taxes',
      ),
      _MasterSectionItem(
        title: 'HSN/SAC Master',
        description: 'Maintain Harmonized System of Nomenclature & Service Accounting Codes.',
        icon: Icons.tag_rounded,
        color: const Color(0xFF06B6D4), // Cyan
        route: '/masters/hsn-sac',
      ),
      _MasterSectionItem(
        title: 'Process Master',
        description: 'Configure manufacturing operations, job-work stages, SAC codes, and assembly flags.',
        icon: Icons.alt_route_rounded,
        color: const Color(0xFF059669), // Emerald Green
        route: '/masters/processes',
      ),
      _MasterSectionItem(
        title: 'Transaction Type Master',
        description: 'Set up inward, outward, purchase, sales, and internal transfer transaction types.',
        icon: Icons.swap_horiz_rounded,
        color: const Color(0xFF6366F1), // Indigo
        route: '/masters/transaction-types',
      ),
      _MasterSectionItem(
        title: 'Rejection Reason Master',
        description: 'Define standard reasons for material and process rejections.',
        icon: Icons.assignment_late_rounded,
        color: const Color(0xFFEF4444), // Red
        route: '/masters/rejection-reasons',
      ),
      _MasterSectionItem(
        title: 'Opening Balance Entry',
        description: 'Set initial stock valuation, quantities, and store/WIP locations by item group.',
        icon: Icons.account_balance_wallet_rounded,
        color: const Color(0xFF10B981), // Emerald
        route: '/masters/opening-balance',
      ),
      _MasterSectionItem(
        title: 'PDI Master',
        description: 'Pre-delivery inspection parts and tracking.',
        icon: Icons.fact_check_rounded,
        color: const Color(0xFF6366F1), // Indigo
        route: '/masters/pdi',
      ),
      _MasterSectionItem(
        title: 'State Master',
        description: 'Indian states, union territories, and GST state codes.',
        icon: Icons.location_on_rounded,
        color: const Color(0xFF0284C7), // Light Blue / Sky
        route: '/masters/states',
      ),
      _MasterSectionItem(
        title: 'Clearance Type Master',
        description: 'Customs, domestic, export clearance tax rules, and bond details.',
        icon: Icons.verified_user_rounded,
        color: const Color(0xFF0D9488), // Teal
        route: '/masters/clearance-types',
      ),
      _MasterSectionItem(
        title: 'Update HSN/SAC',
        description: 'Batch update HSN/SAC codes across group items.',
        icon: Icons.tune_rounded,
        color: const Color(0xFF8B5CF6), // Purple
        route: '/masters/update-hsn-sac',
      ),
    ];

    final body = SingleChildScrollView(
      padding: EdgeInsets.all(isMobile ? AppSizes.p16 : AppSizes.p24),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1200),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header Banner Card
              Container(
                width: double.infinity,
                padding: EdgeInsets.all(isMobile ? AppSizes.p16 : AppSizes.p24),
                decoration: BoxDecoration(
                  gradient: isDark
                      ? AppColors.darkCardGradient
                      : const LinearGradient(
                          colors: [Color(0xFF0F5E36), Color(0xFF1B804B)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                  borderRadius: BorderRadius.circular(AppSizes.cardRadius),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(isDark ? 0.4 : 0.08),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.18),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.settings_suggest_rounded,
                        color: Colors.white,
                        size: 32,
                      ),
                    ),
                    const SizedBox(width: AppSizes.p16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'ERP Masters Management',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Centralized master data configuration for parties, catalogs, taxes, and transaction categories.',
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.9),
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSizes.p24),

              // Section Heading
              Text(
                'Available Master Catalogs',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.2,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Select a master catalog to view or manage configurations.',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.textTheme.bodySmall?.color?.withOpacity(0.7),
                ),
              ),
              const SizedBox(height: AppSizes.p16),

              // Grid of Masters
              ResponsiveGrid(
                mobileCrossAxisCount: 1,
                tabletCrossAxisCount: 2,
                desktopCrossAxisCount: 3,
                spacing: AppSizes.p16,
                mainAxisExtent: isMobile ? 124 : 140,
                children: sections.map((item) {
                  return _MasterCatalogCard(item: item, isDark: isDark);
                }).toList(),
              ),
            ],
          ),
        ),
      ),
    );

    return ResponsiveScaffold(
      appBar: AppBar(
        title: const Text(
          'Masters',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
        ),
        elevation: 0,
      ),
      drawer: const ERPDrawer(),
      body: body,
    );
  }
}

class _MasterSectionItem {
  final String title;
  final String description;
  final IconData icon;
  final Color color;
  final String route;

  const _MasterSectionItem({
    required this.title,
    required this.description,
    required this.icon,
    required this.color,
    required this.route,
  });
}

class _MasterCatalogCard extends StatelessWidget {
  final _MasterSectionItem item;
  final bool isDark;

  const _MasterCatalogCard({
    required this.item,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return ResponsiveCard(
      padding: EdgeInsets.zero,
      child: InkWell(
        borderRadius: BorderRadius.circular(AppSizes.cardRadius),
        onTap: () => context.push(item.route),
        child: Padding(
          padding: const EdgeInsets.all(AppSizes.p16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: item.color.withOpacity(isDark ? 0.22 : 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  item.icon,
                  color: item.color,
                  size: 24,
                ),
              ),
              const SizedBox(width: AppSizes.p16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            item.title,
                            style: theme.textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.bold,
                              fontSize: 15,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        Icon(
                          Icons.arrow_forward_ios_rounded,
                          size: 13,
                          color: isDark ? Colors.white38 : Colors.grey.shade400,
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      item.description,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: isDark ? Colors.white60 : Colors.grey.shade600,
                        fontSize: 12,
                        height: 1.3,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
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
}
