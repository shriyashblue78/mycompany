import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/constants/app_sizes.dart';
import '../../domain/models/company_subscription_model.dart';
import '../../domain/models/subscription_plan.dart';
import '../../domain/models/subscription_duration_type.dart';
import '../../domain/models/app_feature.dart';
import '../providers/subscription_provider.dart';

class CustomerSubscriptionPlansScreen extends ConsumerStatefulWidget {
  const CustomerSubscriptionPlansScreen({super.key});

  @override
  ConsumerState<CustomerSubscriptionPlansScreen> createState() => _CustomerSubscriptionPlansScreenState();
}

class _CustomerSubscriptionPlansScreenState extends ConsumerState<CustomerSubscriptionPlansScreen> {
  SubscriptionDurationType _selectedDuration = SubscriptionDurationType.oneYear;

  // Module category tag pills matching Figma header reference
  static const List<String> _modulePillTags = [
    'Workforce',
    'Attendance',
    'Inventory',
    'Production',
    'Machines',
    'Tooling',
    'Programs',
    'Sales',
    'Analytics',
    'Project Tracker',
  ];

  double _calculatePlanPrice(SubscriptionPlan plan, SubscriptionDurationType duration) {
    final basePrice = plan.price ?? (plan.planId == 'basic' ? 1999.0 : plan.planId == 'professional' ? 4999.0 : 9999.0);
    switch (duration) {
      case SubscriptionDurationType.oneMonth:
        return basePrice;
      case SubscriptionDurationType.threeMonths:
        return basePrice * 2.8;
      case SubscriptionDurationType.sixMonths:
        return basePrice * 5.2;
      case SubscriptionDurationType.oneYear:
        return basePrice * 9.6;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final plansAsync = ref.watch(subscriptionPlansStreamProvider);
    final currentSubAsync = ref.watch(currentCompanySubscriptionProvider);

    return Scaffold(
      backgroundColor: isDark ? theme.colorScheme.surface : const Color(0xFFFAFAFA),
      appBar: AppBar(
        title: const Text('Subscription & Plans'),
        elevation: 0,
        backgroundColor: theme.colorScheme.surface,
      ),
      body: currentSubAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) => Center(child: Text('Error loading subscription: $err')),
        data: (currentSub) {
          return SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: AppSizes.p20, vertical: AppSizes.p32),
            child: Center(
              child: Container(
                constraints: const BoxConstraints(maxWidth: 1150),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Figma-Style Main Title & Prices Note
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: CrossAxisAlignment.baseline,
                      textBaseline: TextBaseline.alphabetic,
                      children: [
                        Text(
                          'Pricing and plans',
                          style: theme.textTheme.headlineLarge?.copyWith(
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.5,
                            color: theme.colorScheme.onSurface,
                          ),
                        ),
                        Text(
                          'Prices in INR (₹)',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            color: theme.colorScheme.onSurface.withAlpha(140),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Choose the plan that fits your business.',
                      style: theme.textTheme.bodyLarge?.copyWith(
                        color: theme.colorScheme.onSurface.withAlpha(160),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Feature / Module Category Chips Row (Figma Reference)
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      physics: const BouncingScrollPhysics(),
                      child: Row(
                        children: _modulePillTags.map((tag) {
                          return Container(
                            margin: const EdgeInsets.only(right: 8),
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              color: isDark ? const Color(0xFF1E293B) : Colors.grey.shade100,
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: isDark ? Colors.grey.shade800 : Colors.grey.shade300,
                                width: 1,
                              ),
                            ),
                            child: Text(
                              tag,
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                                color: theme.colorScheme.onSurface.withAlpha(200),
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                    const SizedBox(height: AppSizes.p28),

                    // Centered Segmented Duration Selector
                    Center(
                      child: _buildDurationPillSelector(theme, isDark),
                    ),
                    const SizedBox(height: 36.0),

                    // ALL Subscription Plans Cards (Never hidden, always complete)
                    plansAsync.when(
                      loading: () => const Center(child: CircularProgressIndicator()),
                      error: (err, _) => Center(child: Text('Error loading plans: $err')),
                      data: (plans) {
                        final allActivePlans = (plans.isNotEmpty ? plans : DefaultSubscriptionPlans.initialPlans)
                            .where((p) => p.isActive)
                            .toList();

                        return _buildFigmaPlansLayout(
                          context,
                          theme,
                          isDark,
                          allActivePlans,
                          currentSub,
                        );
                      },
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  // Duration Selector Pill Segment
  Widget _buildDurationPillSelector(ThemeData theme, bool isDark) {
    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.grey.shade200,
        borderRadius: BorderRadius.circular(30),
        border: Border.all(color: isDark ? Colors.grey.shade800 : Colors.grey.shade300),
      ),
      padding: const EdgeInsets.all(4),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: SubscriptionDurationType.values.map((dur) {
            final isSelected = _selectedDuration == dur;
            final isYearly = dur == SubscriptionDurationType.oneYear;

            return GestureDetector(
              onTap: () => setState(() => _selectedDuration = dur),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                decoration: BoxDecoration(
                  color: isSelected
                      ? (isDark ? theme.colorScheme.primary : Colors.black)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(24),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      dur.label,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                        color: isSelected ? Colors.white : theme.colorScheme.onSurface,
                      ),
                    ),
                    if (isYearly) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: isSelected ? Colors.amber.shade700 : Colors.green.shade600,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Text(
                          'Save 20%',
                          style: TextStyle(fontSize: 10, color: Colors.white, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  // Responsive Layout: Grid/Row on Web/Tablet, Stack on Mobile
  Widget _buildFigmaPlansLayout(
    BuildContext context,
    ThemeData theme,
    bool isDark,
    List<SubscriptionPlan> plans,
    CompanySubscriptionModel? currentSub,
  ) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final screenWidth = constraints.maxWidth;
        final isDesktop = screenWidth >= 900;
        final isTablet = screenWidth >= 600 && screenWidth < 900;

        if (isDesktop || isTablet) {
          // Desktop / Tablet Horizontal Row
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: plans.map((plan) {
              return Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 10.0),
                  child: _PlanCardWidget(
                    plan: plan,
                    allPlans: plans,
                    selectedDuration: _selectedDuration,
                    calculatedPrice: _calculatePlanPrice(plan, _selectedDuration),
                    currentSub: currentSub,
                    isDark: isDark,
                    theme: theme,
                    onSelect: (price) => _onSelectPlan(context, plan, price),
                    onShowFeatures: () => _showAllFeaturesModal(context, plan, theme, isDark),
                  ),
                ),
              );
            }).toList(),
          );
        }

        // Mobile Layout: Clean vertical stack
        return Column(
          children: plans.map((plan) {
            return Padding(
              padding: const EdgeInsets.only(bottom: AppSizes.p20),
              child: _PlanCardWidget(
                plan: plan,
                allPlans: plans,
                selectedDuration: _selectedDuration,
                calculatedPrice: _calculatePlanPrice(plan, _selectedDuration),
                currentSub: currentSub,
                isDark: isDark,
                theme: theme,
                onSelect: (price) => _onSelectPlan(context, plan, price),
                onShowFeatures: () => _showAllFeaturesModal(context, plan, theme, isDark),
              ),
            );
          }).toList(),
        );
      },
    );
  }

  void _onSelectPlan(BuildContext context, SubscriptionPlan plan, double price) {
    final currentSub = ref.read(currentCompanySubscriptionProvider).asData?.value;
    if (currentSub != null && !currentSub.isExpired) {
      final isCurrent = currentSub.planId.toLowerCase() == plan.planId.toLowerCase() ||
          currentSub.planName.toLowerCase() == plan.planName.toLowerCase();
      if (isCurrent) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('This is your current active plan.'),
            backgroundColor: Colors.green,
          ),
        );
        return;
      }
    }
    context.push(
      '/subscription/checkout?planId=${plan.planId}&duration=${_selectedDuration.label}&amount=${price.toStringAsFixed(0)}',
    );
  }

  // Modal Sheet for Grouped Feature Breakdown
  void _showAllFeaturesModal(BuildContext context, SubscriptionPlan plan, ThemeData theme, bool isDark) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        final groupedMap = FeatureMaster.groupedFeatures;
        final enabledSet = plan.enabledFeatures.toSet();

        return Container(
          height: MediaQuery.of(context).size.height * 0.82,
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF0F172A) : Colors.white,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            children: [
              Container(
                margin: const EdgeInsets.only(top: 12, bottom: 8),
                width: 40,
                height: 4,
                decoration: BoxDecoration(color: Colors.grey.shade400, borderRadius: BorderRadius.circular(2)),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                child: Row(
                  children: [
                    CircleAvatar(
                      backgroundColor: theme.colorScheme.primary.withAlpha(25),
                      child: Icon(Icons.stars_rounded, color: theme.colorScheme.primary),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('${plan.planName} — Complete Features', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: isDark ? Colors.white : null)),
                          Text('${plan.enabledFeatures.length} of ${FeatureMaster.allFeatures.length} features included', style: TextStyle(fontSize: 12, color: isDark ? Colors.grey.shade400 : Colors.grey.shade600)),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: Icon(Icons.close, color: isDark ? Colors.white : null),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
              ),
              const Divider(),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.all(20),
                  children: groupedMap.entries.map((groupEntry) {
                    final groupName = groupEntry.key;
                    final groupFeatures = groupEntry.value;

                    return Container(
                      margin: const EdgeInsets.only(bottom: 16),
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF1E293B) : Colors.grey.shade50,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: isDark ? Colors.grey.shade800 : Colors.grey.shade200),
                      ),
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(_getGroupIcon(groupName), size: 18, color: theme.colorScheme.primary),
                              const SizedBox(width: 8),
                              Text(groupName, style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black87)),
                            ],
                          ),
                          const SizedBox(height: 10),
                          ...groupFeatures.map((feat) {
                            final isIncluded = enabledSet.contains(feat.featureKey);
                            return Padding(
                              padding: const EdgeInsets.symmetric(vertical: 4),
                              child: Row(
                                children: [
                                  Icon(
                                    isIncluded ? Icons.check_circle : Icons.lock_outline_rounded,
                                    size: 16,
                                    color: isIncluded ? Colors.green : Colors.grey.shade400,
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          feat.displayName,
                                          style: TextStyle(
                                            fontSize: 13,
                                            fontWeight: isIncluded ? FontWeight.w600 : FontWeight.normal,
                                            color: isIncluded ? (isDark ? Colors.white : Colors.black87) : Colors.grey,
                                          ),
                                        ),
                                        Text(
                                          feat.description,
                                          style: TextStyle(fontSize: 11, color: isDark ? Colors.grey.shade400 : Colors.grey.shade600),
                                        ),
                                      ],
                                    ),
                                  ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: isIncluded ? Colors.green.withAlpha(20) : Colors.grey.withAlpha(20),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Text(
                                      isIncluded ? 'Included' : 'Not Included',
                                      style: TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.bold,
                                        color: isIncluded ? Colors.green : Colors.grey,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            );
                          }),
                        ],
                      ),
                    );
                  }).toList(),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  IconData _getGroupIcon(String groupName) {
    switch (groupName) {
      case 'Workforce':
        return Icons.badge_rounded;
      case 'Attendance':
        return Icons.access_time_rounded;
      case 'Tasks':
        return Icons.task_alt_rounded;
      case 'Inventory':
        return Icons.inventory_2_rounded;
      case 'Production':
        return Icons.precision_manufacturing_rounded;
      case 'Machines':
        return Icons.build_rounded;
      case 'Tooling':
        return Icons.construction_rounded;
      case 'Programs':
        return Icons.code_rounded;
      case 'Sales':
        return Icons.shopping_bag_rounded;
      case 'Project Tracker':
        return Icons.account_tree_rounded;
      case 'Reports':
        return Icons.assessment_rounded;
      case 'Analytics':
        return Icons.insights_rounded;
      default:
        return Icons.extension_rounded;
    }
  }
}

// Stateful Plan Card Component with Hover animation (Web/Desktop)
class _PlanCardWidget extends StatefulWidget {
  final SubscriptionPlan plan;
  final List<SubscriptionPlan> allPlans;
  final SubscriptionDurationType selectedDuration;
  final double calculatedPrice;
  final CompanySubscriptionModel? currentSub;
  final bool isDark;
  final ThemeData theme;
  final ValueChanged<double> onSelect;
  final VoidCallback onShowFeatures;

  const _PlanCardWidget({
    required this.plan,
    required this.allPlans,
    required this.selectedDuration,
    required this.calculatedPrice,
    required this.currentSub,
    required this.isDark,
    required this.theme,
    required this.onSelect,
    required this.onShowFeatures,
  });

  @override
  State<_PlanCardWidget> createState() => _PlanCardWidgetState();
}

class _PlanCardWidgetState extends State<_PlanCardWidget> {
  bool _isHovered = false;

  int _getCurrentPlanTier() {
    if (widget.currentSub == null || widget.currentSub!.isExpired) return 0;
    try {
      final matched = widget.allPlans.firstWhere(
        (p) =>
            p.planId.toLowerCase() == widget.currentSub!.planId.toLowerCase() ||
            p.planName.toLowerCase() == widget.currentSub!.planName.toLowerCase(),
      );
      return matched.tier;
    } catch (_) {
      return 0;
    }
  }

  @override
  Widget build(BuildContext context) {
    final isCurrentSubActive = widget.currentSub != null && !widget.currentSub!.isExpired;
    final isCurrentPlan = isCurrentSubActive &&
        (widget.currentSub!.planId.toLowerCase() == widget.plan.planId.toLowerCase() ||
            widget.currentSub!.planName.toLowerCase() == widget.plan.planName.toLowerCase());

    final currentTier = _getCurrentPlanTier();
    final isUpgrade = isCurrentSubActive && widget.plan.tier > currentTier;

    final isPopular = !isCurrentPlan &&
        (widget.plan.planId == 'professional' || widget.plan.planName.toLowerCase().contains('pro'));

    final isEnterpriseCard = widget.plan.planId == 'enterprise' || widget.plan.planName.toLowerCase().contains('enterprise');

    // Accent colors matching Figma reference
    final cardBgColor = widget.isDark
        ? (isEnterpriseCard ? const Color(0xFF1E293B) : const Color(0xFF0F172A))
        : (isEnterpriseCard ? const Color(0xFF18181B) : Colors.white);

    final textColor = isEnterpriseCard && !widget.isDark ? Colors.white : widget.theme.colorScheme.onSurface;
    final subTextColor = isEnterpriseCard && !widget.isDark
        ? Colors.grey.shade400
        : widget.theme.colorScheme.onSurface.withAlpha(150);

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        transform: Matrix4.translationValues(0, _isHovered ? -4 : 0, 0),
        decoration: BoxDecoration(
          color: cardBgColor,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isCurrentPlan
                ? Colors.green
                : (_isHovered
                    ? widget.theme.colorScheme.primary
                    : (isPopular
                        ? (widget.isDark ? widget.theme.colorScheme.primary : Colors.grey.shade400)
                        : (widget.isDark ? Colors.grey.shade800 : Colors.grey.shade200))),
            width: (isCurrentPlan || _isHovered) ? 2 : 1,
          ),
          boxShadow: [
            BoxShadow(
              color: isCurrentPlan
                  ? Colors.green.withAlpha(25)
                  : (_isHovered
                      ? widget.theme.colorScheme.primary.withAlpha(30)
                      : Colors.black.withAlpha(8)),
              blurRadius: (_isHovered || isCurrentPlan) ? 14 : 6,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(AppSizes.p24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header Row: Plan Title + Badge
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    widget.plan.planName,
                    style: widget.theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: textColor,
                    ),
                  ),
                  if (isCurrentPlan)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.green,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.check_circle, color: Colors.white, size: 12),
                          SizedBox(width: 4),
                          Text(
                            'CURRENT PLAN',
                            style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                    )
                  else if (isPopular)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.orange.shade700,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Text(
                        'Popular',
                        style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 12),

              // Price Block
              Row(
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  Text(
                    '₹${widget.calculatedPrice.toStringAsFixed(0)}',
                    style: widget.theme.textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                      color: isCurrentPlan ? Colors.green : textColor,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    '/ ${widget.selectedDuration.label}',
                    style: TextStyle(
                      fontSize: 12,
                      color: subTextColor,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),

              // Subtitle Description
              Text(
                widget.plan.description,
                style: TextStyle(
                  fontSize: 12,
                  color: subTextColor,
                  height: 1.3,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 20),

              Divider(height: 1, color: isEnterpriseCard && !widget.isDark ? Colors.grey.shade800 : (widget.isDark ? Colors.grey.shade800 : Colors.grey.shade200)),
              const SizedBox(height: 16),

              // Key Features Header
              Text(
                'Includes:',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: textColor,
                ),
              ),
              const SizedBox(height: 10),

              // Key Feature Ticks
              ...widget.plan.enabledFeatures.take(5).map((featKey) {
                final feat = FeatureMaster.getFeature(featKey);
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    children: [
                      const Icon(Icons.check_circle_rounded, size: 16, color: Colors.green),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          feat?.displayName ?? featKey,
                          style: TextStyle(
                            fontSize: 13,
                            color: textColor,
                            fontWeight: FontWeight.w500,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                );
              }),
              const SizedBox(height: 12),

              // Expandable View All Features Link
              InkWell(
                onTap: widget.onShowFeatures,
                borderRadius: BorderRadius.circular(6),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    children: [
                      Icon(Icons.unfold_more_rounded, size: 16, color: isEnterpriseCard && !widget.isDark ? Colors.blue.shade300 : widget.theme.colorScheme.primary),
                      const SizedBox(width: 6),
                      Text(
                        'View all features (${widget.plan.enabledFeatures.length})',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: isEnterpriseCard && !widget.isDark ? Colors.blue.shade300 : widget.theme.colorScheme.primary,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // Primary Action Button (Bottom of Card)
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => widget.onSelect(widget.calculatedPrice),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: isCurrentPlan
                        ? Colors.green
                        : (isEnterpriseCard
                            ? Colors.white
                            : (isPopular
                                ? (widget.isDark ? widget.theme.colorScheme.primary : Colors.black)
                                : (widget.isDark ? Colors.grey.shade800 : Colors.grey.shade100))),
                    foregroundColor: isCurrentPlan
                        ? Colors.white
                        : (isEnterpriseCard
                            ? Colors.black
                            : (isPopular || widget.isDark ? Colors.white : Colors.black87)),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    elevation: isCurrentPlan ? 0 : (_isHovered ? 3 : 1),
                  ),
                  child: Text(
                    isCurrentPlan
                        ? 'Current Plan'
                        : (isUpgrade ? 'Upgrade Plan' : 'Select ${widget.plan.planName}'),
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
