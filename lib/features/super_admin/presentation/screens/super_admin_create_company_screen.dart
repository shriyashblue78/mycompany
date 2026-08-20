import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_sizes.dart';
import '../../../../core/services/storage_service.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../auth/domain/models/company_model.dart';
import '../providers/super_admin_provider.dart';
import '../providers/provisioning_provider.dart';

class SuperAdminCreateCompanyScreen extends ConsumerStatefulWidget {
  const SuperAdminCreateCompanyScreen({super.key});

  @override
  ConsumerState<SuperAdminCreateCompanyScreen> createState() => _SuperAdminCreateCompanyScreenState();
}

class _SuperAdminCreateCompanyScreenState extends ConsumerState<SuperAdminCreateCompanyScreen> {
  final _formKey = GlobalKey<FormState>();
  
  // Company Info Controllers
  final _nameController = TextEditingController();
  final _industryController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _gstController = TextEditingController();
  final _addressController = TextEditingController();
  final _cityController = TextEditingController();
  final _stateController = TextEditingController();
  final _countryController = TextEditingController(text: 'India');
  final _timezoneController = TextEditingController(text: 'Asia/Kolkata');
  final _workingHoursController = TextEditingController(text: '09:00 AM - 06:00 PM');

  // Logo upload state
  Uint8List? _logoBytes;
  String? _logoContentType;

  // Owner Info Controllers
  final _ownerNameController = TextEditingController();
  final _ownerEmailController = TextEditingController();
  final _ownerPhoneController = TextEditingController();
  final _ownerPasswordController = TextEditingController();

  String _generatedCode = '';
  bool _loadingCode = true;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _loadNextCompanyCode();
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

    _ownerNameController.dispose();
    _ownerEmailController.dispose();
    _ownerPhoneController.dispose();
    _ownerPasswordController.dispose();
    super.dispose();
  }

  Future<void> _loadNextCompanyCode() async {
    try {
      final code = await ref.read(superAdminRepositoryProvider).generateNextCompanyCode();
      if (mounted) {
        setState(() {
          _generatedCode = code;
          _loadingCode = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _generatedCode = 'Error generating code';
          _loadingCode = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error generating code: $e')),
        );
      }
    }
  }

  Future<void> _pickLogo() async {
    try {
      final ImagePicker picker = ImagePicker();
      final XFile? image = await picker.pickImage(source: ImageSource.gallery, imageQuality: 85);
      if (image != null) {
        final bytes = await image.readAsBytes();
        setState(() {
          _logoBytes = bytes;
          _logoContentType = image.mimeType ?? 'image/jpeg';
        });
      }
    } catch (e) {
      debugPrint("Company Logo picker error: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to pick logo: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Register New Company'),
        elevation: 0,
        backgroundColor: theme.colorScheme.surface,
        iconTheme: IconThemeData(color: theme.colorScheme.onSurface),
      ),
      body: _saving
          ? const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text('Provisioning company & owner workspace...', style: TextStyle(fontWeight: FontWeight.bold)),
                ],
              ),
            )
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
                          'Onboard a brand-new tenant company. This assigns a unique code and prepares metadata.',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: theme.colorScheme.onSurface.withAlpha(153),
                          ),
                        ),
                        const SizedBox(height: AppSizes.p24),

                        // Section 1: Company Details
                        Text(
                          '1. Company General Details',
                          style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold, color: theme.colorScheme.primary),
                        ),
                        const SizedBox(height: AppSizes.p16),

                        // Code Field (Disabled, Auto-generated)
                        TextFormField(
                          controller: TextEditingController(text: _loadingCode ? 'Generating...' : _generatedCode),
                          enabled: false,
                          decoration: InputDecoration(
                            labelText: 'Auto-Generated Company Code',
                            prefixIcon: const Icon(Icons.pin_rounded),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(AppSizes.inputRadius),
                            ),
                          ),
                        ),
                        const SizedBox(height: AppSizes.p16),

                        // Company Name
                        TextFormField(
                          controller: _nameController,
                          decoration: InputDecoration(
                            labelText: 'Company Name *',
                            hintText: 'e.g., Apex Industries Ltd.',
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
                            hintText: 'e.g., Manufacturing, Logistics',
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
                            hintText: 'e.g., admin@apex.com',
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
                            hintText: 'e.g., +91 9876543210',
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
                            hintText: 'e.g., 22AAAAA0000A1Z5',
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

                        // Timezone, Working Hours
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

                        // Company Logo Pick Area
                        Text(
                          'Company Logo (Optional)',
                          style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: AppSizes.p8),
                        Row(
                          children: [
                            if (_logoBytes != null)
                              ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: Image.memory(
                                  _logoBytes!,
                                  width: 80,
                                  height: 80,
                                  fit: BoxFit.cover,
                                ),
                              )
                            else
                              Container(
                                width: 80,
                                height: 80,
                                decoration: BoxDecoration(
                                  color: theme.colorScheme.surfaceContainerHighest,
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: theme.dividerColor),
                                ),
                                child: Icon(Icons.business_rounded, size: 40, color: theme.colorScheme.onSurfaceVariant),
                              ),
                            const SizedBox(width: AppSizes.p16),
                            ElevatedButton.icon(
                              onPressed: _pickLogo,
                              icon: const Icon(Icons.photo_library_rounded),
                              label: const Text('Select Logo Image'),
                              style: ElevatedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                              ),
                            ),
                            if (_logoBytes != null) ...[
                              const SizedBox(width: AppSizes.p8),
                              TextButton.icon(
                                onPressed: () {
                                  setState(() {
                                    _logoBytes = null;
                                    _logoContentType = null;
                                  });
                                },
                                icon: const Icon(Icons.delete_outline, color: Colors.red),
                                label: const Text('Remove', style: TextStyle(color: Colors.red)),
                              ),
                            ],
                          ],
                        ),
                        const SizedBox(height: AppSizes.p24),

                        // Section 2: Owner Information
                        const Divider(),
                        const SizedBox(height: AppSizes.p8),
                        Text(
                          '2. Primary Owner Credentials',
                          style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold, color: theme.colorScheme.primary),
                        ),
                        const SizedBox(height: AppSizes.p16),

                        // Owner Name
                        TextFormField(
                          controller: _ownerNameController,
                          decoration: InputDecoration(
                            labelText: 'Owner Full Name *',
                            hintText: 'e.g., Rajesh Sharma',
                            prefixIcon: const Icon(Icons.person),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(AppSizes.inputRadius),
                            ),
                          ),
                          validator: (val) {
                            if (val == null || val.trim().isEmpty) return 'Owner Name is required';
                            return null;
                          },
                        ),
                        const SizedBox(height: AppSizes.p16),

                        // Owner Email
                        TextFormField(
                          controller: _ownerEmailController,
                          keyboardType: TextInputType.emailAddress,
                          decoration: InputDecoration(
                            labelText: 'Owner Account Email *',
                            hintText: 'e.g., rajesh@apex.com',
                            prefixIcon: const Icon(Icons.alternate_email_rounded),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(AppSizes.inputRadius),
                            ),
                          ),
                          validator: (val) {
                            if (val == null || val.trim().isEmpty) return 'Owner Email is required';
                            if (!val.contains('@')) return 'Enter a valid email address';
                            return null;
                          },
                        ),
                        const SizedBox(height: AppSizes.p16),

                        // Owner Phone
                        TextFormField(
                          controller: _ownerPhoneController,
                          keyboardType: TextInputType.phone,
                          decoration: InputDecoration(
                            labelText: 'Owner Phone Number *',
                            hintText: 'e.g., +91 9999988888',
                            prefixIcon: const Icon(Icons.phone_android_rounded),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(AppSizes.inputRadius),
                            ),
                          ),
                          validator: (val) {
                            if (val == null || val.trim().isEmpty) return 'Owner Phone is required';
                            final phoneRegex = RegExp(r'^\+?[0-9]{10,15}$');
                            if (!phoneRegex.hasMatch(val.trim())) {
                              return 'Enter a valid phone number (10-15 digits)';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: AppSizes.p16),

                        // Temporary Password
                        TextFormField(
                          controller: _ownerPasswordController,
                          obscureText: true,
                          decoration: InputDecoration(
                            labelText: 'Temporary Account Password *',
                            hintText: 'At least 6 characters...',
                            prefixIcon: const Icon(Icons.lock_reset_rounded),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(AppSizes.inputRadius),
                            ),
                          ),
                          validator: (val) {
                            if (val == null || val.trim().isEmpty) return 'Temporary password is required';
                            if (val.length < 6) return 'Password must be at least 6 characters';
                            return null;
                          },
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
                              'Onboard Company Instance',
                              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
    );
  }

  void _submitForm() async {
    if (!_formKey.currentState!.validate()) return;
    if (_loadingCode || _generatedCode.isEmpty || _generatedCode.startsWith('Error')) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please wait for the company code to generate.')),
      );
      return;
    }

    setState(() => _saving = true);

    try {
      final repo = ref.read(superAdminRepositoryProvider);
      final provisionService = ref.read(accountProvisioningServiceProvider);

      // 1. Validation for Duplicate Company Name
      final nameDup = await repo.isCompanyNameDuplicate(_nameController.text.trim());
      if (nameDup) {
        throw Exception('A company with this name is already registered.');
      }

      // 2. Validation for Duplicate Company Code
      final codeDup = await repo.isCompanyCodeDuplicate(_generatedCode);
      if (codeDup) {
        throw Exception('Duplicate company code generated. Please retry.');
      }

      final companyId = FirebaseFirestore.instance.collection('companies').doc().id;

      // Upload logo image if selected
      String? uploadedLogoUrl;
      if (_logoBytes != null) {
        final storage = ref.read(storageServiceProvider);
        final path = 'companies/$companyId/logo.jpg';
        uploadedLogoUrl = await storage.uploadBytes(
          path: path,
          bytes: _logoBytes!,
          contentType: _logoContentType ?? 'image/jpeg',
        );
      }

      // 3. Provision Owner Account (Creates mock documents under users & employees)
      final ownerUid = await provisionService.createOwner(
        companyId: companyId,
        name: _ownerNameController.text.trim(),
        email: _ownerEmailController.text.trim(),
        phone: _ownerPhoneController.text.trim(),
        temporaryPassword: _ownerPasswordController.text,
      );

      final newCompany = CompanyModel(
        companyId: companyId,
        companyCode: _generatedCode,
        companyName: _nameController.text.trim(),
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
        logoUrl: uploadedLogoUrl ?? '',
        companyLogoUrl: uploadedLogoUrl,
        status: 'Trial', // Default status is Trial
        subscriptionPlan: 'Trial',
        ownerName: _ownerNameController.text.trim(),
        ownerEmail: _ownerEmailController.text.trim(),
        ownerPhone: _ownerPhoneController.text.trim(),
        ownerUid: ownerUid,
        ownerStatus: 'Active',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      // 4. Create Company record in Firestore
      await repo.createCompany(newCompany);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Company and Owner onboarded successfully!')),
        );
        context.pop(); // Return to dashboard
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to onboard: ${e.toString().replaceAll('Exception: ', '')}')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }
}
