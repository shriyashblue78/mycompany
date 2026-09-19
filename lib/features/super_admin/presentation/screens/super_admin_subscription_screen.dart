import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_sizes.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../auth/domain/models/company_model.dart';
import '../../../subscription/domain/models/company_subscription_model.dart';
import '../../../subscription/domain/models/subscription_duration_type.dart';
import '../../../subscription/domain/models/subscription_plan.dart';
import '../../../subscription/domain/models/app_feature.dart';
import '../../../subscription/domain/services/subscription_service.dart';
import '../../../subscription/domain/services/effective_feature_service.dart';
import '../../../subscription/presentation/providers/subscription_provider.dart';
import '../providers/super_admin_provider.dart';

class SuperAdminSubscriptionScreen extends ConsumerStatefulWidget {
  final String companyId;

  const SuperAdminSubscriptionScreen({
    super.key,
    required this.companyId,
  });

  @override
  ConsumerState<SuperAdminSubscriptionScreen> createState() => _SuperAdminSubscriptionScreenState();
}

class _SuperAdminSubscriptionScreenState extends ConsumerState<SuperAdminSubscriptionScreen> {
  final _formKey = GlobalKey<FormState>();

  bool _initialized = false;
  bool _saving = false;

  late SubscriptionPlan _selectedPlan;
  late SubscriptionDurationType _selectedDuration;
  late DateTime _startDate;
  late DateTime _calculatedExpiry;
  late TextEditingController _priceController;
  late TextEditingController _maxEmployeesController;

  // Track Super Admin overrides per featureKey (true = explicit ON, false = explicit OFF)
  final Map<String, bool> _featureOverrides = {};

  @override
  void initState() {
    super.initState();
    _selectedPlan = DefaultSubscriptionPlans.basic;
    _selectedDuration = SubscriptionDurationType.oneMonth;
    _startDate = DateTime.now();
    _calculatedExpiry = SubscriptionService.calculateExpiryDate(_startDate, _selectedDuration);
    _priceController = TextEditingController();
    _maxEmployeesController = TextEditingController(text: '50');
  }

  @override
  void dispose() {
    _priceController.dispose();
    _maxEmployeesController.dispose();
    super.dispose();
  }

  void _initializeData(CompanyModel company, CompanySubscriptionModel? existingSub) {
    if (_initialized) return;

    if (existingSub != null) {
      _selectedDuration = SubscriptionDurationType.fromLabel(existingSub.subscriptionPlan);
      _startDate = existingSub.startDate;
      _calculatedExpiry = existingSub.expiryDate;
      _priceController.text = existingSub.price != null ? existingSub.price.toString() : '';

      // Find matching plan or fallback
      final matchedPlan = DefaultSubscriptionPlans.initialPlans.firstWhere(
        (p) => p.planId == existingSub.planId || p.planName == existingSub.planName,
        orElse: () => DefaultSubscriptionPlans.basic,
      );
      _selectedPlan = matchedPlan;

      // Populate existing feature overrides
      _featureOverrides.addAll(existingSub.featureOverrides);
    } else {
      _selectedPlan = DefaultSubscriptionPlans.basic;
      _selectedDuration = SubscriptionDurationType.oneMonth;
      _startDate = DateTime.now();
      _calculatedExpiry = SubscriptionService.calculateExpiryDate(_startDate, _selectedDuration);
    }

    _maxEmployeesController.text = company.maxEmployees.toString();
    _initialized = true;
  }

  void _recalculateExpiry() {
    setState(() {
      _calculatedExpiry = SubscriptionService.calculateExpiryDate(_startDate, _selectedDuration);
    });
  }

  String _computeDynamicStatus() {
    final now = DateTime.now();
    if (!now.isBefore(_calculatedExpiry)) {
      return 'Expired';
    }
    final diff = _calculatedExpiry.difference(now);
    if (diff.inDays <= 7) {
      return 'Expiring Soon';
    }
    return 'Active';
  }

  Color _getStatusBadgeColor(String status) {
    switch (status) {
      case 'Active':
        return Colors.green;
      case 'Expiring Soon':
        return Colors.orange;
      case 'Expired':
        return Colors.red;
      default:
        return Colors.blue;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final authState = ref.watch(authProvider);

    // SECURITY CHECK: Strict Super Admin Access Authorization
    if (authState.selectedRole != 'super_admin') {
      return Scaffold(
        appBar: AppBar(title: const Text('Access Denied')),
        body: const Center(
          child: Padding(
            padding: EdgeInsets.all(24.0),
            child: Text(
              'Security Violation: Only Super Admin users can modify subscription controls.',
              style: TextStyle(color: Colors.red, fontSize: 16, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
          ),
        ),
      );
    }

    final companyAsync = ref.watch(companyDetailsStreamProvider(widget.companyId));
    final subAsync = ref.watch(companySubscriptionStreamProvider(widget.companyId));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Super Admin Subscription Controls'),
        elevation: 0,
        backgroundColor: theme.colorScheme.surface,
        iconTheme: IconThemeData(color: theme.colorScheme.onSurface),
      ),
      body: companyAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, stack) => Center(child: Text('Error loading company: $err')),
        data: (company) {
          if (company == null) {
            return const Center(child: Text('Company record not found.'));
          }

          final existingSub = subAsync.value;
          _initializeData(company, existingSub);

          final currentStatus = _computeDynamicStatus();
          final statusColor = _getStatusBadgeColor(currentStatus);

          return _saving
              ? const Center(child: CircularProgressIndicator())
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(AppSizes.p24),
                  child: Center(
                    child: Container(
                      constraints: const BoxConstraints(maxWidth: 900),
                      child: Form(
                        key: _formKey,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Header Banner
                            Card(
                              elevation: 2,
                              color: theme.colorScheme.surface,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              child: Padding(
                                padding: const EdgeInsets.all(AppSizes.p20),
                                child: Row(
                                  children: [
                                    CircleAvatar(
                                      radius: 28,
                                      backgroundColor: theme.colorScheme.primary.withAlpha(30),
                                      child: Text(
                                        company.companyName.isNotEmpty ? company.companyName[0].toUpperCase() : 'C',
                                        style: TextStyle(
                                          fontSize: 24,
                                          fontWeight: FontWeight.bold,
                                          color: theme.colorScheme.primary,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: AppSizes.p16),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            company.companyName,
                                            style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                                          ),
                                          const SizedBox(height: 4),
                                          Text('Code: ${company.companyCode} | Owner: ${company.ownerName}'),
                                        ],
                                      ),
                                    ),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                                      decoration: BoxDecoration(
                                        color: statusColor.withAlpha(30),
                                        borderRadius: BorderRadius.circular(20),
                                        border: Border.all(color: statusColor, width: 1.5),
                                      ),
                                      child: Text(
                                        currentStatus,
                                        style: TextStyle(
                                          color: statusColor,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 14,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(height: AppSizes.p24),

                            // Section 1: Plan & Duration Selection
                            Text('1. Subscription Plan & Duration', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                            const SizedBox(height: 12),
                            Card(
                              elevation: 1,
                              child: Padding(
                                padding: const EdgeInsets.all(AppSizes.p16),
                                child: Column(
                                  children: [
                                    // Subscription Plan Dropdown
                                    DropdownButtonFormField<SubscriptionPlan>(
                                      value: _selectedPlan,
                                      decoration: const InputDecoration(
                                        labelText: 'Subscription Plan *',
                                        prefixIcon: Icon(Icons.stars_rounded),
                                        border: OutlineInputBorder(),
                                      ),
                                      items: DefaultSubscriptionPlans.initialPlans.map((plan) {
                                        return DropdownMenuItem(
                                          value: plan,
                                          child: Text('${plan.planName} (${plan.description})'),
                                        );
                                      }).toList(),
                                      onChanged: (newPlan) {
                                        if (newPlan != null) {
                                          setState(() {
                                            _selectedPlan = newPlan;
                                          });
                                        }
                                      },
                                    ),
                                    const SizedBox(height: AppSizes.p16),

                                    // Duration Dropdown
                                    DropdownButtonFormField<SubscriptionDurationType>(
                                      value: _selectedDuration,
                                      decoration: const InputDecoration(
                                        labelText: 'Subscription Duration *',
                                        prefixIcon: Icon(Icons.timelapse_rounded),
                                        border: OutlineInputBorder(),
                                      ),
                                      items: SubscriptionDurationType.values.map((dur) {
                                        return DropdownMenuItem(
                                          value: dur,
                                          child: Text(dur.label),
                                        );
                                      }).toList(),
                                      onChanged: (newDuration) {
                                        if (newDuration != null) {
                                          _selectedDuration = newDuration;
                                          _recalculateExpiry();
                                        }
                                      },
                                    ),
                                    const SizedBox(height: AppSizes.p16),

                                    // Configurable Price
                                    TextFormField(
                                      controller: _priceController,
                                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                      decoration: const InputDecoration(
                                        labelText: 'Configurable Price (Optional)',
                                        hintText: 'Enter agreed plan price (e.g., 5000)',
                                        prefixIcon: Icon(Icons.currency_rupee_rounded),
                                        border: OutlineInputBorder(),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(height: AppSizes.p24),

                            // Section 2: Start Date & Expiry Date Calculation
                            Text('2. Subscription Dates & Expiry', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                            const SizedBox(height: 12),
                            Card(
                              elevation: 1,
                              child: Padding(
                                padding: const EdgeInsets.all(AppSizes.p16),
                                child: Column(
                                  children: [
                                    ListTile(
                                      leading: const Icon(Icons.calendar_today_rounded, color: AppColors.primaryLight),
                                      title: const Text('Start Date'),
                                      subtitle: Text(DateFormat('yyyy-MM-dd HH:mm').format(_startDate)),
                                      trailing: TextButton(
                                        onPressed: () async {
                                          final picked = await showDatePicker(
                                            context: context,
                                            initialDate: _startDate,
                                            firstDate: DateTime(2020),
                                            lastDate: DateTime(2040),
                                          );
                                          if (picked != null) {
                                            setState(() {
                                              _startDate = DateTime(
                                                picked.year,
                                                picked.month,
                                                picked.day,
                                                _startDate.hour,
                                                _startDate.minute,
                                              );
                                              _recalculateExpiry();
                                            });
                                          }
                                        },
                                        child: const Text('Change Date'),
                                      ),
                                    ),
                                    const Divider(),
                                    ListTile(
                                      leading: const Icon(Icons.event_available_rounded, color: Colors.green),
                                      title: const Text('Calculated Expiry Date'),
                                      subtitle: Text(
                                        DateFormat('yyyy-MM-dd HH:mm').format(_calculatedExpiry),
                                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                                      ),
                                      trailing: Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                        decoration: BoxDecoration(
                                          color: statusColor.withAlpha(20),
                                          borderRadius: BorderRadius.circular(12),
                                        ),
                                        child: Text(
                                          currentStatus,
                                          style: TextStyle(color: statusColor, fontWeight: FontWeight.bold),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(height: AppSizes.p24),

                            // Section 3: Employee Seat Limit
                            Text('3. Employee Seat Limit', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                            const SizedBox(height: 12),
                            Card(
                              elevation: 1,
                              child: Padding(
                                padding: const EdgeInsets.all(AppSizes.p16),
                                child: TextFormField(
                                  controller: _maxEmployeesController,
                                  keyboardType: TextInputType.number,
                                  decoration: const InputDecoration(
                                    labelText: 'Maximum Employee Limit *',
                                    hintText: 'e.g., 50',
                                    prefixIcon: Icon(Icons.people_alt_rounded),
                                    border: OutlineInputBorder(),
                                  ),
                                  validator: (val) {
                                    if (val == null || val.trim().isEmpty) return 'Employee limit is required';
                                    if (int.tryParse(val.trim()) == null) return 'Enter a valid number';
                                    return null;
                                  },
                                ),
                              ),
                            ),
                            const SizedBox(height: AppSizes.p24),

                            // Section 4: Feature Access Switches (Hierarchy Evaluation)
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text('4. Feature Access & Super Admin Overrides', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                                TextButton.icon(
                                  icon: const Icon(Icons.restart_alt_rounded, size: 18),
                                  label: const Text('Reset to Plan Defaults'),
                                  onPressed: () {
                                    setState(() {
                                      _featureOverrides.clear();
                                    });
                                  },
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Hierarchy: PLAN DEFAULT → SUPER ADMIN OVERRIDE → EFFECTIVE ACCESS',
                              style: theme.textTheme.bodySmall?.copyWith(color: Colors.grey.shade600),
                            ),
                            const SizedBox(height: 12),

                            Card(
                              elevation: 1,
                              child: ListView.separated(
                                shrinkWrap: true,
                                physics: const NeverScrollableScrollPhysics(),
                                itemCount: FeatureMaster.allFeatures.length,
                                separatorBuilder: (_, __) => const Divider(height: 1),
                                itemBuilder: (context, index) {
                                  final feature = FeatureMaster.allFeatures[index];
                                  final isPlanDefaultOn = _selectedPlan.enabledFeatures.contains(feature.featureKey);

                                  final hasOverride = _featureOverrides.containsKey(feature.featureKey);
                                  final effectiveState = hasOverride
                                      ? _featureOverrides[feature.featureKey]!
                                      : isPlanDefaultOn;

                                  return SwitchListTile(
                                    title: Row(
                                      children: [
                                        Text(feature.displayName, style: const TextStyle(fontWeight: FontWeight.bold)),
                                        const SizedBox(width: 8),
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                          decoration: BoxDecoration(
                                            color: isPlanDefaultOn ? Colors.blue.withAlpha(20) : Colors.grey.withAlpha(30),
                                            borderRadius: BorderRadius.circular(4),
                                          ),
                                          child: Text(
                                            'Plan: ${isPlanDefaultOn ? "ON" : "OFF"}',
                                            style: TextStyle(
                                              fontSize: 10,
                                              color: isPlanDefaultOn ? Colors.blue : Colors.grey.shade700,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ),
                                        if (hasOverride) ...[
                                          const SizedBox(width: 6),
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                            decoration: BoxDecoration(
                                              color: Colors.purple.withAlpha(20),
                                              borderRadius: BorderRadius.circular(4),
                                            ),
                                            child: const Text(
                                              'Override Active',
                                              style: TextStyle(fontSize: 10, color: Colors.purple, fontWeight: FontWeight.bold),
                                            ),
                                          ),
                                        ],
                                      ],
                                    ),
                                    subtitle: Text(feature.description),
                                    secondary: Icon(
                                      effectiveState ? Icons.check_circle_rounded : Icons.block_rounded,
                                      color: effectiveState ? Colors.green : Colors.grey,
                                    ),
                                    value: effectiveState,
                                    onChanged: (bool value) {
                                      setState(() {
                                        if (value == isPlanDefaultOn) {
                                          _featureOverrides.remove(feature.featureKey);
                                        } else {
                                          _featureOverrides[feature.featureKey] = value;
                                        }
                                      });
                                    },
                                  );
                                },
                              ),
                            ),
                            const SizedBox(height: AppSizes.p32),

                            // Save Button
                            SizedBox(
                              width: double.infinity,
                              child: ElevatedButton.icon(
                                icon: const Icon(Icons.save_rounded, color: Colors.white),
                                label: const Text(
                                  'Save Subscription Controls',
                                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
                                ),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: theme.colorScheme.primary,
                                  padding: const EdgeInsets.symmetric(vertical: AppSizes.p16),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(AppSizes.buttonRadius),
                                  ),
                                ),
                                onPressed: _saveSubscriptionSettings,
                              ),
                            ),
                            const SizedBox(height: AppSizes.p32),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
        },
      ),
    );
  }

  Future<void> _saveSubscriptionSettings() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _saving = true);

    try {
      final double? parsedPrice = _priceController.text.trim().isNotEmpty
          ? double.tryParse(_priceController.text.trim())
          : null;

      final dynamicStatus = _computeDynamicStatus();

      // Compute Effective Features
      final effectiveFeaturesList = EffectiveFeatureService.calculateEffectiveFeatures(
        planDefaultFeatures: _selectedPlan.enabledFeatures,
        featureOverrides: _featureOverrides,
      );

      // 1. Build & Save CompanySubscriptionModel
      final updatedSub = CompanySubscriptionModel(
        id: 'current',
        companyId: widget.companyId,
        planId: _selectedPlan.planId,
        planName: _selectedPlan.planName,
        subscriptionPlan: _selectedDuration.label,
        price: parsedPrice,
        startDate: _startDate,
        expiryDate: _calculatedExpiry,
        enabledFeatures: _selectedPlan.enabledFeatures,
        featureOverrides: _featureOverrides,
        updatedAt: DateTime.now(),
      );

      final subRepo = ref.read(subscriptionRepositoryProvider);
      await subRepo.setCompanySubscription(updatedSub);

      // 2. Update CompanyModel in Firestore (subscription status, planName, maxEmployees, enabledModules)
      final superAdminRepo = ref.read(superAdminRepositoryProvider);
      final currentCompany = await superAdminRepo.streamCompanyById(widget.companyId).first;

      if (currentCompany != null) {
        final updatedCompany = currentCompany.copyWith(
          subscriptionPlan: _selectedPlan.planName,
          status: dynamicStatus == 'Expired' ? 'Expired' : 'Active',
          maxEmployees: int.parse(_maxEmployeesController.text.trim()),
          enabledModules: effectiveFeaturesList,
          updatedAt: DateTime.now(),
        );

        await superAdminRepo.updateCompany(updatedCompany);
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Subscription & Feature Access updated successfully!'),
            backgroundColor: Colors.green,
          ),
        );
        context.pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to save subscription settings: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }
}
