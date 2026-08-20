import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_sizes.dart';
import '../../../auth/domain/models/company_model.dart';
import '../providers/super_admin_provider.dart';

class SuperAdminEditCompanyScreen extends ConsumerStatefulWidget {
  final String companyId;

  const SuperAdminEditCompanyScreen({
    super.key,
    required this.companyId,
  });

  @override
  ConsumerState<SuperAdminEditCompanyScreen> createState() => _SuperAdminEditCompanyScreenState();
}

class _SuperAdminEditCompanyScreenState extends ConsumerState<SuperAdminEditCompanyScreen> {
  final _formKey = GlobalKey<FormState>();
  
  late TextEditingController _nameController;
  late TextEditingController _industryController;
  late TextEditingController _emailController;
  late TextEditingController _phoneController;
  late TextEditingController _gstController;
  late TextEditingController _addressController;
  late TextEditingController _cityController;
  late TextEditingController _stateController;
  late TextEditingController _countryController;
  late TextEditingController _timezoneController;
  late TextEditingController _workingHoursController;
  late TextEditingController _logoUrlController;

  bool _saving = false;
  bool _initialized = false;
  CompanyModel? _originalCompany;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController();
    _industryController = TextEditingController();
    _emailController = TextEditingController();
    _phoneController = TextEditingController();
    _gstController = TextEditingController();
    _addressController = TextEditingController();
    _cityController = TextEditingController();
    _stateController = TextEditingController();
    _countryController = TextEditingController();
    _timezoneController = TextEditingController();
    _workingHoursController = TextEditingController();
    _logoUrlController = TextEditingController();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _industryController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _gstController.dispose();
    _addressController.dispose();
    _cityController.dispose();
    _stateController.dispose();
    _countryController.dispose();
    _timezoneController.dispose();
    _workingHoursController.dispose();
    _logoUrlController.dispose();
    super.dispose();
  }

  void _initializeValues(CompanyModel company) {
    if (_initialized) return;
    _originalCompany = company;
    _nameController.text = company.companyName;
    _industryController.text = company.industry;
    _emailController.text = company.email;
    _phoneController.text = company.phone;
    _gstController.text = company.gstNumber;
    _addressController.text = company.address;
    _cityController.text = company.city;
    _stateController.text = company.state;
    _countryController.text = company.country;
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
        title: const Text('Edit Company Workspace'),
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
                              'Edit metadata attributes for company identifier code: ${company.companyCode}',
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: theme.colorScheme.onSurface.withAlpha(153),
                              ),
                            ),
                            const SizedBox(height: AppSizes.p24),

                            // Company Name
                            TextFormField(
                              controller: _nameController,
                              decoration: InputDecoration(
                                labelText: 'Company Name *',
                                prefixIcon: const Icon(Icons.business),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(AppSizes.inputRadius),
                                ),
                              ),
                              validator: (val) {
                                if (val == null || val.trim().isEmpty) return 'Company Name is required';
                                return null;
                              },
                            ),
                            const SizedBox(height: AppSizes.p16),

                            // Industry Sector
                            TextFormField(
                              controller: _industryController,
                              decoration: InputDecoration(
                                labelText: 'Industry Sector *',
                                prefixIcon: const Icon(Icons.category),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(AppSizes.inputRadius),
                                ),
                              ),
                              validator: (val) {
                                if (val == null || val.trim().isEmpty) return 'Industry Sector is required';
                                return null;
                              },
                            ),
                            const SizedBox(height: AppSizes.p16),

                            // Email
                            TextFormField(
                              controller: _emailController,
                              keyboardType: TextInputType.emailAddress,
                              decoration: InputDecoration(
                                labelText: 'Primary Contact Email *',
                                prefixIcon: const Icon(Icons.email),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(AppSizes.inputRadius),
                                ),
                              ),
                              validator: (val) {
                                if (val == null || val.trim().isEmpty) return 'Email is required';
                                if (!val.contains('@')) return 'Enter a valid email address';
                                return null;
                              },
                            ),
                            const SizedBox(height: AppSizes.p16),

                            // Phone
                            TextFormField(
                              controller: _phoneController,
                              keyboardType: TextInputType.phone,
                              decoration: InputDecoration(
                                labelText: 'Contact Phone Number',
                                prefixIcon: const Icon(Icons.phone),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(AppSizes.inputRadius),
                                ),
                              ),
                            ),
                            const SizedBox(height: AppSizes.p16),

                            // GST Number
                            TextFormField(
                              controller: _gstController,
                              decoration: InputDecoration(
                                labelText: 'GST Number (Optional)',
                                prefixIcon: const Icon(Icons.receipt_long),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(AppSizes.inputRadius),
                                ),
                              ),
                            ),
                            const SizedBox(height: AppSizes.p16),

                            // Address, City, State, Country
                            TextFormField(
                              controller: _addressController,
                              decoration: InputDecoration(
                                labelText: 'Street Address',
                                prefixIcon: const Icon(Icons.location_on),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(AppSizes.inputRadius),
                                ),
                              ),
                            ),
                            const SizedBox(height: AppSizes.p16),

                            Row(
                              children: [
                                Expanded(
                                  child: TextFormField(
                                    controller: _cityController,
                                    decoration: InputDecoration(
                                      labelText: 'City',
                                      border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(AppSizes.inputRadius),
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: AppSizes.p12),
                                Expanded(
                                  child: TextFormField(
                                    controller: _stateController,
                                    decoration: InputDecoration(
                                      labelText: 'State',
                                      border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(AppSizes.inputRadius),
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: AppSizes.p16),

                            TextFormField(
                              controller: _countryController,
                              decoration: InputDecoration(
                                labelText: 'Country',
                                prefixIcon: const Icon(Icons.public),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(AppSizes.inputRadius),
                                ),
                              ),
                            ),
                            const SizedBox(height: AppSizes.p16),

                            // Timezone, Working Hours, Logo URL
                            Row(
                              children: [
                                Expanded(
                                  child: TextFormField(
                                    controller: _timezoneController,
                                    decoration: InputDecoration(
                                      labelText: 'Timezone',
                                      border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(AppSizes.inputRadius),
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: AppSizes.p12),
                                Expanded(
                                  child: TextFormField(
                                    controller: _workingHoursController,
                                    decoration: InputDecoration(
                                      labelText: 'Working Hours',
                                      border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(AppSizes.inputRadius),
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: AppSizes.p16),

                            TextFormField(
                              controller: _logoUrlController,
                              decoration: InputDecoration(
                                labelText: 'Logo URL',
                                prefixIcon: const Icon(Icons.image),
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
                                  'Save Workspace Updates',
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

      // Name duplicate validation (only if the name is modified)
      final newName = _nameController.text.trim();
      if (newName != _originalCompany!.companyName) {
        final duplicate = await repo.isCompanyNameDuplicate(newName);
        if (duplicate) {
          throw Exception('A company with this name is already registered.');
        }
      }

      final updatedCompany = _originalCompany!.copyWith(
        companyName: newName,
        industry: _industryController.text.trim(),
        gstNumber: _gstController.text.trim(),
        email: _emailController.text.trim(),
        phone: _phoneController.text.trim(),
        address: _addressController.text.trim(),
        city: _cityController.text.trim(),
        state: _stateController.text.trim(),
        country: _countryController.text.trim(),
        timezone: _timezoneController.text.trim(),
        workingHours: _workingHoursController.text.trim(),
        logoUrl: _logoUrlController.text.trim(),
        updatedAt: DateTime.now(),
      );

      await repo.updateCompany(updatedCompany);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Company details updated successfully.')),
        );
        context.pop(); // Return to detail screen
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to update: ${e.toString().replaceAll('Exception: ', '')}')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }
}
