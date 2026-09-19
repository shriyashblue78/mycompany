import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../../core/constants/app_sizes.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../domain/models/company_subscription_model.dart';
import '../../domain/models/subscription_plan.dart';
import '../../domain/models/subscription_duration_type.dart';
import '../../domain/models/payment_transaction_model.dart';
import '../../domain/models/app_feature.dart';
import '../../domain/services/payment_service.dart';
import '../providers/subscription_provider.dart';
import '../../../super_admin/presentation/providers/super_admin_provider.dart';

class CustomerSubscriptionPlansScreen extends ConsumerStatefulWidget {
  const CustomerSubscriptionPlansScreen({super.key});

  @override
  ConsumerState<CustomerSubscriptionPlansScreen> createState() => _CustomerSubscriptionPlansScreenState();
}

class _CustomerSubscriptionPlansScreenState extends ConsumerState<CustomerSubscriptionPlansScreen> {
  SubscriptionDurationType _selectedDuration = SubscriptionDurationType.oneYear;

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
    final authState = ref.watch(authProvider);
    final companyId = authState.user?.companyId ?? '';

    final plansAsync = ref.watch(subscriptionPlansStreamProvider);
    final currentSubAsync = ref.watch(currentCompanySubscriptionProvider);
    final paymentsAsync = ref.watch(companyPaymentsStreamProvider(companyId));

    return Scaffold(
      backgroundColor: isDark ? theme.colorScheme.surface : const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text('Subscription & Feature Plans'),
        elevation: 0,
        backgroundColor: theme.colorScheme.surface,
      ),
      body: currentSubAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) => Center(child: Text('Error loading subscription: $err')),
        data: (currentSub) {
          final pendingPayments = paymentsAsync.asData?.value.where((p) => p.status == PaymentStatus.pending).toList() ?? [];

          return SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: AppSizes.p20, vertical: AppSizes.p24),
            child: Center(
              child: Container(
                constraints: const BoxConstraints(maxWidth: 1200),
                child: Column(
                  children: [
                    // Current Active Subscription Banner
                    if (currentSub != null) ...[
                      _buildCurrentSubscriptionCard(theme, isDark, currentSub),
                      const SizedBox(height: AppSizes.p20),
                    ],

                    // Pending Orders Alert Banner
                    if (pendingPayments.isNotEmpty) ...[
                      _buildPendingOrdersBanner(context, theme, isDark, pendingPayments.first, currentSub),
                      const SizedBox(height: AppSizes.p20),
                    ],

                    // Stepper Progress Header
                    _buildPurchaseStepper(theme, activeStep: 1),
                    const SizedBox(height: AppSizes.p24),

                    // Header Title & Description
                    Text(
                      'Flexible Plans for Manufacturing & Enterprise',
                      style: theme.textTheme.headlineMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: theme.colorScheme.onSurface,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Scale your operations with complete workforce, inventory, production, and analytics features',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurface.withAlpha(160),
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: AppSizes.p24),

                    // Duration Selector Pill
                    _buildDurationPillSelector(theme, isDark),
                    const SizedBox(height: AppSizes.p32),

                    // Plans Cards Grid
                    plansAsync.when(
                      loading: () => const Center(child: CircularProgressIndicator()),
                      error: (err, _) => Center(child: Text('Error loading plans: $err')),
                      data: (plans) {
                        final allActivePlans = (plans.isNotEmpty ? plans : DefaultSubscriptionPlans.initialPlans)
                            .where((p) => p.isActive)
                            .toList();

                        // Filter plans by tier if there is an active subscription
                        final filteredPlans = _filterPlansByTier(allActivePlans, currentSub);

                        // Determine current active plan tier (0 = none)
                        final currentPlanTier = _getCurrentPlanTier(allActivePlans, currentSub);

                        // Show "upgrade only" notice when lower-tier plans are hidden
                        final hiddenCount = allActivePlans.length - filteredPlans.length;

                        return Column(
                          children: [
                            if (hiddenCount > 0) ...[
                              _buildUpgradeNotice(theme, isDark, currentSub!),
                              const SizedBox(height: AppSizes.p16),
                            ],
                            _buildCleanModernCards(
                              context,
                              theme,
                              isDark,
                              filteredPlans,
                              currentSub,
                              currentPlanTier,
                            ),
                          ],
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

  Widget _buildDurationPillSelector(ThemeData theme, bool isDark) {
    return Container(
      decoration: BoxDecoration(
        color: isDark ? theme.colorScheme.surface : Colors.grey.shade200,
        borderRadius: BorderRadius.circular(30),
      ),
      padding: const EdgeInsets.all(4),
      child: Wrap(
        alignment: WrapAlignment.center,
        spacing: 4,
        children: SubscriptionDurationType.values.map((dur) {
          final isSelected = _selectedDuration == dur;
          final isYearly = dur == SubscriptionDurationType.oneYear;

          return GestureDetector(
            onTap: () => setState(() => _selectedDuration = dur),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: isSelected ? theme.colorScheme.primary : Colors.transparent,
                borderRadius: BorderRadius.circular(24),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    dur.label,
                    style: TextStyle(
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
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
    );
  }

  // --- DESIGN 1: Clean Modern Cards ---
  Widget _buildCleanModernCards(
    BuildContext context,
    ThemeData theme,
    bool isDark,
    List<SubscriptionPlan> plans,
    CompanySubscriptionModel? currentSub,
    int currentPlanTier,
  ) {
    final isCurrentSubActive = currentSub != null && !currentSub.isExpired;

    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth > 900;
        final isMedium = constraints.maxWidth > 600;

        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: isWide ? 3 : (isMedium ? 2 : 1),
            crossAxisSpacing: AppSizes.p20,
            mainAxisSpacing: AppSizes.p20,
            childAspectRatio: isWide ? 0.64 : (isMedium ? 0.68 : 0.72),
          ),
          itemCount: plans.length,
          itemBuilder: (context, index) {
            final plan = plans[index];
            final planTier = plan.tier;
            final isCurrentPlan = isCurrentSubActive &&
                (currentSub.planId.toLowerCase() == plan.planId.toLowerCase() ||
                    currentSub.planName.toLowerCase() == plan.planName.toLowerCase());
            final isUpgrade = currentPlanTier > 0 && planTier > currentPlanTier;
            final isWasCurrentPlanExpired = currentSub != null &&
                currentSub.isExpired &&
                (currentSub.planId.toLowerCase() == plan.planId.toLowerCase() ||
                    currentSub.planName.toLowerCase() == plan.planName.toLowerCase());
            // "Popular" only if it's not already the current plan
            final isPopular = !isCurrentPlan &&
                (plan.planId == 'professional' || plan.planName.toLowerCase().contains('pro'));
            final price = _calculatePlanPrice(plan, _selectedDuration);

            return Container(
              decoration: BoxDecoration(
                color: isDark ? theme.colorScheme.surface : Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: isCurrentPlan
                      ? Colors.green
                      : (isPopular ? theme.colorScheme.primary : (isDark ? Colors.grey.shade800 : Colors.grey.shade300)),
                  width: (isCurrentPlan || isPopular) ? 2.5 : 1,
                ),
                boxShadow: [
                  BoxShadow(
                    color: isCurrentPlan
                        ? Colors.green.withAlpha(25)
                        : (isPopular ? theme.colorScheme.primary.withAlpha(25) : Colors.black.withAlpha(8)),
                    blurRadius: (isCurrentPlan || isPopular) ? 16 : 8,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  if (isCurrentPlan)
                    Positioned(
                      top: -12,
                      right: 24,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.green,
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: const [
                            BoxShadow(color: Colors.green, blurRadius: 6),
                          ],
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.check_circle_rounded, color: Colors.white, size: 13),
                            SizedBox(width: 4),
                            Text(
                              'Current Plan',
                              style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                      ),
                    )
                  else if (isPopular)
                    Positioned(
                      top: -12,
                      right: 24,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.primary,
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: [
                            BoxShadow(color: theme.colorScheme.primary.withAlpha(100), blurRadius: 6),
                          ],
                        ),
                        child: const Text(
                          'Most Popular',
                          style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                  Padding(
                    padding: const EdgeInsets.all(AppSizes.p24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            CircleAvatar(
                              radius: 20,
                              backgroundColor: isCurrentPlan
                                  ? Colors.green.withAlpha(30)
                                  : (isPopular ? theme.colorScheme.primary.withAlpha(30) : Colors.blue.withAlpha(20)),
                              child: Icon(
                                isCurrentPlan
                                    ? Icons.stars_rounded
                                    : (isPopular ? Icons.rocket_launch_rounded : (plan.planId == 'enterprise' ? Icons.business_center_rounded : Icons.flash_on_rounded)),
                                color: isCurrentPlan ? Colors.green : (isPopular ? theme.colorScheme.primary : Colors.blue),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    plan.planName,
                                    style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                                  ),
                                  if (isCurrentPlan) ...[
                                    const SizedBox(height: 2),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: Colors.green.withAlpha(30),
                                        borderRadius: BorderRadius.circular(4),
                                        border: Border.all(color: Colors.green.withAlpha(100)),
                                      ),
                                      child: const Text('Current Plan', style: TextStyle(fontSize: 10, color: Colors.green, fontWeight: FontWeight.bold)),
                                    ),
                                  ] else if (isWasCurrentPlanExpired) ...[
                                    const SizedBox(height: 2),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: Colors.red.withAlpha(30),
                                        borderRadius: BorderRadius.circular(4),
                                        border: Border.all(color: Colors.red.withAlpha(100)),
                                      ),
                                      child: const Text('Expired Plan', style: TextStyle(fontSize: 10, color: Colors.red, fontWeight: FontWeight.bold)),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Text(
                          plan.description,
                          style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurface.withAlpha(140)),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 16),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.baseline,
                          textBaseline: TextBaseline.alphabetic,
                          children: [
                            Text(
                              '₹${price.toStringAsFixed(0)}',
                              style: theme.textTheme.headlineMedium?.copyWith(
                                fontWeight: FontWeight.w800,
                                color: isCurrentPlan ? Colors.green : theme.colorScheme.primary,
                              ),
                            ),
                            const SizedBox(width: 4),
                            Text(
                              '/ ${_selectedDuration.label}',
                              style: theme.textTheme.bodySmall?.copyWith(color: Colors.grey),
                            ),
                          ],
                        ),
                        const Divider(height: 24),
                        Text('Key Included Features:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: theme.colorScheme.onSurface.withAlpha(180))),
                        const SizedBox(height: 8),

                        // Limited 4 Key Features Display
                        Expanded(
                          child: ListView(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            children: [
                              ...plan.enabledFeatures.take(4).map((featKey) {
                                final feat = FeatureMaster.getFeature(featKey);
                                return Padding(
                                  padding: const EdgeInsets.symmetric(vertical: 3),
                                  child: Row(
                                    children: [
                                      const Icon(Icons.check_circle_rounded, size: 16, color: Colors.green),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Text(
                                          feat?.displayName ?? featKey,
                                          style: theme.textTheme.bodyMedium,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              }),
                              const SizedBox(height: 8),
                              // Expandable View All Features Button
                              InkWell(
                                onTap: () => _showAllFeaturesModal(context, plan, theme, isDark),
                                borderRadius: BorderRadius.circular(8),
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(vertical: 4),
                                  child: Row(
                                    children: [
                                      Icon(Icons.unfold_more_rounded, size: 16, color: theme.colorScheme.primary),
                                      const SizedBox(width: 6),
                                      Text(
                                        'View all features (${plan.enabledFeatures.length})',
                                        style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.bold,
                                          color: theme.colorScheme.primary,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: isCurrentPlan ? null : () => _onSelectPlan(context, plan, price),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: isCurrentPlan
                                  ? (isDark ? Colors.grey.shade800 : Colors.grey.shade300)
                                  : isUpgrade
                                      ? const Color(0xFFF59E0B) // amber for upgrade
                                      : (isPopular ? theme.colorScheme.primary : theme.colorScheme.surfaceContainerHighest),
                              foregroundColor: isCurrentPlan
                                  ? (isDark ? Colors.grey.shade400 : Colors.grey.shade700)
                                  : isUpgrade
                                      ? Colors.white
                                      : (isPopular ? Colors.white : theme.colorScheme.onSurfaceVariant),
                              disabledBackgroundColor: isDark ? Colors.grey.shade800 : Colors.grey.shade300,
                              disabledForegroundColor: isDark ? Colors.grey.shade400 : Colors.grey.shade700,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                if (isUpgrade) ...[
                                  const Icon(Icons.arrow_upward_rounded, size: 16),
                                  const SizedBox(width: 6),
                                ],
                                Text(
                                  isCurrentPlan
                                      ? 'Current Plan'
                                      : (isUpgrade
                                          ? 'Upgrade Plan'
                                          : (isWasCurrentPlanExpired ? 'Reactivate Plan' : 'Select Plan')),
                                  style: const TextStyle(fontWeight: FontWeight.bold),
                                ),
                              ],
                            ),
                          ),
                        ),
                        if (isCurrentPlan) ...[
                          const SizedBox(height: 6),
                          Center(
                            child: Text(
                              'Active • ${currentSub.remainingTimeFormatted}',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: Colors.green.shade700,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  // ---------------------------------------------------------------------------
  // Tier-Based Plan Visibility Helpers
  // ---------------------------------------------------------------------------

  /// Returns the subset of plans that should be visible given the company's
  /// current active subscription tier.
  ///
  /// Rules:
  ///  - No active sub (null) or expired sub → show ALL active plans.
  ///  - Active sub → show current plan + all plans with higher tier.
  ///    (Plans with tier 0 are treated as unordered and always shown.)
  List<SubscriptionPlan> _filterPlansByTier(
    List<SubscriptionPlan> allPlans,
    CompanySubscriptionModel? currentSub,
  ) {
    if (currentSub == null || currentSub.isExpired) return allPlans;

    final currentTier = _getCurrentPlanTier(allPlans, currentSub);
    if (currentTier == 0) return allPlans; // unordered plans – show all

    return allPlans.where((p) {
      // Always show unordered plans (tier 0) and plans at/above current tier
      return p.tier == 0 || p.tier >= currentTier;
    }).toList();
  }

  /// Resolves the tier integer of the plan matching the current subscription.
  /// Returns 0 if no active subscription, or if the matched plan has no tier.
  int _getCurrentPlanTier(
    List<SubscriptionPlan> allPlans,
    CompanySubscriptionModel? currentSub,
  ) {
    if (currentSub == null || currentSub.isExpired) return 0;

    try {
      final matched = allPlans.firstWhere(
        (p) =>
            p.planId.toLowerCase() == currentSub.planId.toLowerCase() ||
            p.planName.toLowerCase() == currentSub.planName.toLowerCase(),
      );
      return matched.tier;
    } catch (_) {
      return 0;
    }
  }

  /// Informational upgrade notice shown when lower-tier plans are hidden.
  Widget _buildUpgradeNotice(ThemeData theme, bool isDark, CompanySubscriptionModel currentSub) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : const Color(0xFFFFFBEB),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: const Color(0xFFF59E0B).withAlpha(120),
          width: 1.5,
        ),
      ),
      child: Row(
        children: [
          const Icon(Icons.info_outline_rounded, color: Color(0xFFF59E0B), size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: RichText(
              text: TextSpan(
                style: TextStyle(
                  fontSize: 13,
                  color: isDark ? Colors.white70 : Colors.brown.shade800,
                ),
                children: [
                  TextSpan(
                    text: 'You are on the ',
                    style: TextStyle(color: isDark ? Colors.white54 : Colors.brown.shade600),
                  ),
                  TextSpan(
                    text: currentSub.planName,
                    style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFFF59E0B)),
                  ),
                  TextSpan(
                    text: ' plan. Lower-tier plans are not available for purchase. Choose an upgrade below.',
                    style: TextStyle(color: isDark ? Colors.white54 : Colors.brown.shade600),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // --- Expandable Feature Details Sheet / Modal ---
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
              // Modal Grab Handle
              Container(
                margin: const EdgeInsets.only(top: 12, bottom: 8),
                width: 40,
                height: 4,
                decoration: BoxDecoration(color: Colors.grey.shade400, borderRadius: BorderRadius.circular(2)),
              ),
              // Header
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                child: Row(
                  children: [
                    CircleAvatar(
                      backgroundColor: theme.colorScheme.primary.withAlpha(25),
                      child: Icon(Icons.all_inclusive_rounded, color: theme.colorScheme.primary),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('${plan.planName} Plan — Complete Features', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: isDark ? Colors.white : null)),
                          Text('${plan.enabledFeatures.length} of ${FeatureMaster.allFeatures.length} features enabled', style: TextStyle(fontSize: 12, color: isDark ? Colors.grey.shade400 : Colors.grey)),
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
              // Feature Groups List
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
                                    isIncluded ? Icons.check_circle_rounded : Icons.lock_outline_rounded,
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

  void _onSelectPlan(BuildContext context, SubscriptionPlan plan, double price) {
    final currentSub = ref.read(currentCompanySubscriptionProvider).asData?.value;
    if (currentSub != null && !currentSub.isExpired) {
      final isCurrent = currentSub.planId.toLowerCase() == plan.planId.toLowerCase() ||
          currentSub.planName.toLowerCase() == plan.planName.toLowerCase();
      if (isCurrent) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('You are already subscribed to this active plan.'),
            backgroundColor: Colors.orange,
          ),
        );
        return;
      }
    }
    context.push(
      '/subscription/checkout?planId=${plan.planId}&duration=${_selectedDuration.label}&amount=${price.toStringAsFixed(0)}',
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

  Widget _buildCurrentSubscriptionCard(ThemeData theme, bool isDark, CompanySubscriptionModel sub) {
    final statusColor = sub.isExpired ? Colors.red : (sub.isExpiringSoon ? Colors.orange : Colors.green);

    return Container(
      width: double.infinity,
      constraints: const BoxConstraints(maxWidth: 1200),
      decoration: BoxDecoration(
        color: isDark ? theme.colorScheme.surface : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: statusColor.withAlpha(100), width: 1.5),
        boxShadow: [
          BoxShadow(color: statusColor.withAlpha(15), blurRadius: 10, offset: const Offset(0, 4)),
        ],
      ),
      padding: const EdgeInsets.all(AppSizes.p16),
      child: Row(
        children: [
          CircleAvatar(
            radius: 22,
            backgroundColor: statusColor.withAlpha(25),
            child: Icon(Icons.stars_rounded, color: statusColor, size: 26),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      'Current Active Plan: ${sub.planName}',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(color: statusColor.withAlpha(20), borderRadius: BorderRadius.circular(12)),
                      child: Text(
                        sub.status,
                        style: TextStyle(color: statusColor, fontWeight: FontWeight.bold, fontSize: 11),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  'Duration: ${sub.subscriptionPlan} • Expires: ${DateFormat('yyyy-MM-dd').format(sub.expiryDate)} (${sub.remainingTimeFormatted})',
                  style: TextStyle(
                    fontSize: 12,
                    color: theme.colorScheme.onSurface.withAlpha(150),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPendingOrdersBanner(
    BuildContext context,
    ThemeData theme,
    bool isDark,
    PaymentTransactionModel pendingPayment,
    CompanySubscriptionModel? currentSub,
  ) {
    return Container(
      width: double.infinity,
      constraints: const BoxConstraints(maxWidth: 1200),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : const Color(0xFFEFF6FF),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.blue.shade400, width: 1.5),
      ),
      padding: const EdgeInsets.all(AppSizes.p16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.pending_actions_rounded, color: Colors.blue, size: 24),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Pending Order #${pendingPayment.paymentId}',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Colors.blue),
                    ),
                    Text(
                      'Plan: ${pendingPayment.planName} (${pendingPayment.durationLabel}) • Amount: ₹${pendingPayment.amount.toStringAsFixed(0)}',
                      style: TextStyle(fontSize: 13, color: theme.colorScheme.onSurface.withAlpha(170)),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(color: Colors.blue.withAlpha(30), borderRadius: BorderRadius.circular(12)),
                child: const Text('Pending Gateway', style: TextStyle(color: Colors.blue, fontWeight: FontWeight.bold, fontSize: 11)),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Note: Gateway integration ready. You can test instant activation below.',
                style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
              ),
              ElevatedButton.icon(
                icon: const Icon(Icons.check_circle_outline, size: 16),
                label: const Text('Simulate Gateway Approval', style: TextStyle(fontSize: 12)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                ),
                onPressed: () => _simulateGatewayApproval(context, pendingPayment, currentSub),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _simulateGatewayApproval(
    BuildContext context,
    PaymentTransactionModel payment,
    CompanySubscriptionModel? currentSub,
  ) async {
    try {
      final paymentRepo = ref.read(paymentRepositoryProvider);
      final subRepo = ref.read(subscriptionRepositoryProvider);
      final superAdminRepo = ref.read(superAdminRepositoryProvider);

      await paymentRepo.updatePaymentStatus(
        companyId: payment.companyId,
        paymentId: payment.paymentId,
        status: PaymentStatus.successful,
        transactionReference: 'TXN_${DateTime.now().millisecondsSinceEpoch}',
      );

      final matchedPlan = DefaultSubscriptionPlans.initialPlans.firstWhere(
        (p) => p.planId == payment.planId || p.planName.toLowerCase() == payment.planName.toLowerCase(),
        orElse: () => DefaultSubscriptionPlans.basic,
      );

      final activatedSub = PaymentService.activateSubscriptionFromPayment(
        payment: payment,
        plan: matchedPlan,
        existingOverrides: currentSub?.featureOverrides ?? const {},
      );

      await subRepo.setCompanySubscription(activatedSub);

      final history = PaymentService.createHistoryEntry(
        subscription: activatedSub,
        paymentId: payment.paymentId,
      );
      await paymentRepo.addSubscriptionHistory(history);

      final currentCompany = await superAdminRepo.streamCompanyById(payment.companyId).first;
      if (currentCompany != null) {
        await superAdminRepo.updateCompany(
          currentCompany.copyWith(
            subscriptionPlan: activatedSub.planName,
            status: 'Active',
            enabledModules: activatedSub.effectiveFeatures,
            updatedAt: DateTime.now(),
          ),
        );
      }

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Payment confirmed & Subscription activated!'), backgroundColor: Colors.green),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error activating subscription: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Widget _buildPurchaseStepper(ThemeData theme, {required int activeStep}) {
    final steps = ['1. Choose Plan', '2. Duration', '3. Order Review', '4. Payment'];
    return Center(
      child: Container(
        constraints: const BoxConstraints(maxWidth: 700),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(color: Colors.black.withAlpha(10), blurRadius: 10, offset: const Offset(0, 4)),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: List.generate(steps.length, (index) {
            final isCurrent = index + 1 == activeStep;
            final isDone = index + 1 < activeStep;
            return Expanded(
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 14,
                    backgroundColor: isCurrent
                        ? theme.colorScheme.primary
                        : isDone
                            ? Colors.green
                            : Colors.grey.withAlpha(50),
                    child: isDone
                        ? const Icon(Icons.check, size: 14, color: Colors.white)
                        : Text(
                            '${index + 1}',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: isCurrent ? Colors.white : Colors.grey,
                            ),
                          ),
                  ),
                  const SizedBox(width: 6),
                  Flexible(
                    child: Text(
                      steps[index].substring(3),
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: isCurrent ? FontWeight.bold : FontWeight.normal,
                        color: isCurrent ? theme.colorScheme.primary : Colors.grey,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (index < steps.length - 1)
                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 4),
                      child: Icon(Icons.chevron_right, size: 16, color: Colors.grey),
                    ),
                ],
              ),
            );
          }),
        ),
      ),
    );
  }
}
