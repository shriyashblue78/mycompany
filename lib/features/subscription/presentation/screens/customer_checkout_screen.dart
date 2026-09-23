import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_sizes.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../domain/models/subscription_plan.dart';
import '../../domain/models/subscription_duration_type.dart';
import '../../domain/services/subscription_service.dart';
import '../../domain/services/payment_service.dart';
import '../../domain/models/app_feature.dart';
import '../providers/subscription_provider.dart';

class CustomerCheckoutScreen extends ConsumerStatefulWidget {
  final String planId;
  final String durationLabel;
  final double amount;

  const CustomerCheckoutScreen({
    super.key,
    required this.planId,
    required this.durationLabel,
    required this.amount,
  });

  @override
  ConsumerState<CustomerCheckoutScreen> createState() => _CustomerCheckoutScreenState();
}

class _CustomerCheckoutScreenState extends ConsumerState<CustomerCheckoutScreen> {
  bool _submitting = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final authState = ref.watch(authProvider);
    final companyId = authState.user?.companyId ?? '';

    final plansAsync = ref.watch(subscriptionPlansStreamProvider);
    final duration = SubscriptionDurationType.fromLabel(widget.durationLabel);
    final startDate = DateTime.now();
    final calculatedExpiry = SubscriptionService.calculateExpiryDate(startDate, duration);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Order Review & Checkout'),
        elevation: 0,
        backgroundColor: theme.colorScheme.surface,
      ),
      body: plansAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) => Center(child: Text('Error loading plans: $err')),
        data: (plans) {
          final plan = plans.firstWhere(
            (p) => p.planId == widget.planId || p.planName.toLowerCase() == widget.planId.toLowerCase(),
            orElse: () => DefaultSubscriptionPlans.basic,
          );

          return SingleChildScrollView(
            padding: const EdgeInsets.all(AppSizes.p24),
            child: Center(
              child: Container(
                constraints: const BoxConstraints(maxWidth: 750),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Order Stepper Header (Active Step 3: Order Review)
                    _buildCheckoutStepper(theme, activeStep: 3),
                    const SizedBox(height: AppSizes.p24),

                    // Title
                    Text(
                      'Review Your Order',
                      style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Confirm plan details before proceeding to payment.',
                      style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurface.withAlpha(150)),
                    ),
                    const SizedBox(height: AppSizes.p24),

                    // Order Summary Card
                    Card(
                      elevation: 1,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                        side: BorderSide(color: isDark ? Colors.grey.shade800 : Colors.grey.shade200),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(AppSizes.p20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text('Company Account', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                  decoration: BoxDecoration(color: theme.colorScheme.primary.withAlpha(20), borderRadius: BorderRadius.circular(12)),
                                  child: Text(authState.companyName ?? 'Your Company', style: TextStyle(color: theme.colorScheme.primary, fontWeight: FontWeight.bold)),
                                ),
                              ],
                            ),
                            const Divider(height: 24),

                            _buildSummaryRow(theme, 'Selected Plan', plan.planName, isBold: true),
                            _buildSummaryRow(theme, 'Duration', duration.label),
                            _buildSummaryRow(theme, 'Start Date', DateFormat('yyyy-MM-dd').format(startDate)),
                            _buildSummaryRow(theme, 'Expiry Date', DateFormat('yyyy-MM-dd').format(calculatedExpiry), isHighlight: true),
                            const Divider(height: 24),

                            _buildSummaryRow(
                              theme,
                              'Total Amount Payable',
                              '₹${widget.amount.toStringAsFixed(0)}',
                              isPrice: true,
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: AppSizes.p24),

                    // Included Features Accordion / Card
                    Card(
                      elevation: 1,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                        side: BorderSide(color: isDark ? Colors.grey.shade800 : Colors.grey.shade200),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(AppSizes.p20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Included Features (${plan.enabledFeatures.length})', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                            const SizedBox(height: 12),
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: plan.enabledFeatures.map((featKey) {
                                final feat = FeatureMaster.getFeature(featKey);
                                return Chip(
                                  avatar: const Icon(Icons.check_circle, size: 16, color: Colors.green),
                                  label: Text(feat?.displayName ?? featKey, style: const TextStyle(fontSize: 12)),
                                  backgroundColor: isDark ? Colors.grey.shade900 : Colors.grey.shade100,
                                );
                              }).toList(),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: AppSizes.p24),

                    // Payment Integration Card
                    Card(
                      elevation: 1,
                      color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF0F9FF),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                        side: BorderSide(color: isDark ? Colors.blue.shade900 : Colors.blue.shade300, width: 1.5),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(AppSizes.p20),
                        child: Row(
                          children: [
                            const CircleAvatar(
                              radius: 22,
                              backgroundColor: Colors.blue,
                              child: Icon(Icons.payment_rounded, color: Colors.white, size: 22),
                            ),
                            const SizedBox(width: AppSizes.p16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'Payment Integration Ready',
                                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Colors.blue),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'Submitting this order creates a pending transaction record for your account.',
                                    style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurface.withAlpha(160)),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: AppSizes.p32),

                    // Submit Order Action Button
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _submitting ? null : () => _submitPendingOrder(companyId, plan, duration),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: isDark ? theme.colorScheme.primary : Colors.black,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        child: _submitting
                            ? const CircularProgressIndicator(color: Colors.white)
                            : const Text(
                                'Proceed to Payment',
                                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                              ),
                      ),
                    ),
                    const SizedBox(height: 12),

                    Center(
                      child: TextButton.icon(
                        icon: const Icon(Icons.arrow_back),
                        label: const Text('Back to Plans'),
                        onPressed: () => context.pop(),
                      ),
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

  Widget _buildCheckoutStepper(ThemeData theme, {required int activeStep}) {
    final steps = ['1. Choose Plan', '2. Duration', '3. Order Review', '4. Payment'];
    return Center(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          borderRadius: BorderRadius.circular(16),
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
                    backgroundColor: isCurrent ? theme.colorScheme.primary : (isDone ? Colors.green : Colors.grey.withAlpha(50)),
                    child: isDone
                        ? const Icon(Icons.check, size: 14, color: Colors.white)
                        : Text('${index + 1}', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: isCurrent ? Colors.white : Colors.grey)),
                  ),
                  const SizedBox(width: 6),
                  Flexible(
                    child: Text(
                      steps[index].substring(3),
                      style: TextStyle(fontSize: 12, fontWeight: isCurrent ? FontWeight.bold : FontWeight.w400, color: isCurrent ? theme.colorScheme.primary : Colors.grey),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (index < steps.length - 1) const Padding(padding: EdgeInsets.symmetric(horizontal: 4), child: Icon(Icons.chevron_right, size: 16, color: Colors.grey)),
                ],
              ),
            );
          }),
        ),
      ),
    );
  }

  Widget _buildSummaryRow(ThemeData theme, String label, String value, {bool isBold = false, bool isHighlight = false, bool isPrice = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: theme.textTheme.bodyMedium?.copyWith(color: Colors.grey.shade700)),
          Text(
            value,
            style: TextStyle(
              fontWeight: (isBold || isPrice) ? FontWeight.bold : FontWeight.w500,
              fontSize: isPrice ? 20 : (isHighlight ? 15 : 14),
              color: isPrice ? theme.colorScheme.primary : (isHighlight ? Colors.green.shade700 : theme.colorScheme.onSurface),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _submitPendingOrder(String companyId, SubscriptionPlan plan, SubscriptionDurationType duration) async {
    if (companyId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Company ID missing.')));
      return;
    }

    setState(() => _submitting = true);

    try {
      final paymentRepo = ref.read(paymentRepositoryProvider);

      // Create modular Pending Payment Transaction
      final pendingPayment = PaymentService.createPendingPayment(
        companyId: companyId,
        plan: plan,
        duration: duration,
        calculatedAmount: widget.amount,
      );

      await paymentRepo.createPaymentTransaction(pendingPayment);

      if (mounted) {
        showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Row(
              children: [
                Icon(Icons.mark_email_read_rounded, color: Colors.blue),
                SizedBox(width: 8),
                Text('Order Placed Successfully'),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Order ID: ${pendingPayment.paymentId}'),
                const SizedBox(height: 8),
                Text('Plan: ${plan.planName} (${duration.label})'),
                Text('Amount: ₹${widget.amount.toStringAsFixed(0)}'),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(color: Colors.blue.withAlpha(20), borderRadius: BorderRadius.circular(8)),
                  child: const Text(
                    'Status: Pending Payment Integration.\nYour order details have been stored safely.',
                    style: TextStyle(fontSize: 12, color: Colors.blue),
                  ),
                ),
              ],
            ),
            actions: [
              ElevatedButton(
                onPressed: () {
                  Navigator.of(ctx).pop();
                  final role = ref.read(authProvider).selectedRole;
                  String target = '/employee-dashboard';
                  if (role == 'super_admin') {
                    target = '/super-admin';
                  } else if (role == 'Owner') {
                    target = '/owner-dashboard';
                  } else if (role == 'HR' || role == 'Supervisor') {
                    target = '/hr-dashboard';
                  } else if (role == 'Accountant') {
                    target = '/sales';
                  }
                  context.go(target);
                },
                child: const Text('Return to Dashboard'),
              ),
            ],
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error placing order: $e')));
      }
    } finally {
      if (mounted) {
        setState(() => _submitting = false);
      }
    }
  }
}
