import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_sizes.dart';
import '../../../auth/domain/models/company_model.dart';
import '../providers/super_admin_provider.dart';

class SuperAdminCompanySettingsScreen extends ConsumerStatefulWidget {
  final String companyId;

  const SuperAdminCompanySettingsScreen({
    super.key,
    required this.companyId,
  });

  @override
  ConsumerState<SuperAdminCompanySettingsScreen> createState() => _SuperAdminCompanySettingsScreenState();
}

class _SuperAdminCompanySettingsScreenState extends ConsumerState<SuperAdminCompanySettingsScreen> {
  final _formKey = GlobalKey<FormState>();

  late TextEditingController _timezoneController;
  late TextEditingController _workingHoursController;
  late TextEditingController _logoUrlController;

  bool _saving = false;
  bool _initialized = false;
  CompanyModel? _originalCompany;

  @override
  void initState() {
    super.initState();
    _timezoneController = TextEditingController();
    _workingHoursController = TextEditingController();
    _logoUrlController = TextEditingController();
  }

  @override
  void dispose() {
    _timezoneController.dispose();
    _workingHoursController.dispose();
    _logoUrlController.dispose();
    super.dispose();
  }

  void _initializeValues(CompanyModel company) {
    if (_initialized) return;
    _originalCompany = company;
    _timezoneController.text = company.timezone;
    _workingHoursController.text = company.workingHours;
    _logoUrlController.text = company.logoUrl;
    _initialized = true;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final companyAsync = ref.watch(companyDetailsStreamProvider(widget.companyId));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Company Global Settings'),
        elevation: 0,
        backgroundColor: theme.colorScheme.surface,
        iconTheme: IconThemeData(color: theme.colorScheme.onSurface),
      ),
      body: companyAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, stack) => Center(child: Text('Error: $err')),
        data: (company) {
          if (company == null) {
            return const Center(child: Text('Company record not found.'));
          }

          _initializeValues(company);

          return _saving
              ? const Center(child: CircularProgressIndicator())
              : Center(
                  child: Container(
                    constraints: const BoxConstraints(maxWidth: 800),
                    padding: const EdgeInsets.all(AppSizes.p24),
                    child: SingleChildScrollView(
                      child: Form(
                        key: _formKey,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Configure localized metadata and preferences for: ${company.companyName}',
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: theme.colorScheme.onSurface.withAlpha(153),
                              ),
                            ),
                            const SizedBox(height: AppSizes.p24),

                            // Timezone
                            TextFormField(
                              controller: _timezoneController,
                              decoration: InputDecoration(
                                labelText: 'Standard Timezone',
                                hintText: 'e.g., Asia/Kolkata, UTC',
                                prefixIcon: const Icon(Icons.access_time_rounded),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(AppSizes.inputRadius),
                                ),
                              ),
                              validator: (val) {
                                if (val == null || val.trim().isEmpty) return 'Timezone is required';
                                return null;
                              },
                            ),
                            const SizedBox(height: AppSizes.p16),

                            // Working Hours
                            TextFormField(
                              controller: _workingHoursController,
                              decoration: InputDecoration(
                                labelText: 'Operational Working Hours',
                                hintText: 'e.g., 09:00 AM - 06:00 PM',
                                prefixIcon: const Icon(Icons.work_history_rounded),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(AppSizes.inputRadius),
                                ),
                              ),
                              validator: (val) {
                                if (val == null || val.trim().isEmpty) return 'Working Hours is required';
                                return null;
                              },
                            ),
                            const SizedBox(height: AppSizes.p16),

                            // Logo URL
                            TextFormField(
                              controller: _logoUrlController,
                              decoration: InputDecoration(
                                labelText: 'Company Logo URL',
                                hintText: 'e.g., https://apex.com/logo.png',
                                prefixIcon: const Icon(Icons.image_search_rounded),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(AppSizes.inputRadius),
                                ),
                              ),
                            ),
                            const SizedBox(height: AppSizes.p32),

                            // Save button
                            SizedBox(
                              width: double.infinity,
                              child: ElevatedButton(
                                onPressed: _submitForm,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: theme.colorScheme.primary,
                                  padding: const EdgeInsets.symmetric(vertical: AppSizes.p16),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(AppSizes.buttonRadius),
                                  ),
                                ),
                                child: const Text(
                                  'Save Operational Settings',
                                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
                                ),
                              ),
                            ),
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

  void _submitForm() async {
    if (!_formKey.currentState!.validate()) return;
    if (_originalCompany == null) return;

    setState(() => _saving = true);

    try {
      final repo = ref.read(superAdminRepositoryProvider);

      final updatedCompany = _originalCompany!.copyWith(
        timezone: _timezoneController.text.trim(),
        workingHours: _workingHoursController.text.trim(),
        logoUrl: _logoUrlController.text.trim(),
        updatedAt: DateTime.now(),
      );

      await repo.updateCompany(updatedCompany);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Company settings saved successfully.')),
        );
        context.pop(); // Return to detail screen
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to save settings: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }
}
