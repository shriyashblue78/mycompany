import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_sizes.dart';
import '../../../auth/domain/models/company_model.dart';
import '../providers/super_admin_provider.dart';
import '../providers/provisioning_provider.dart';

class SuperAdminOwnerDetailScreen extends ConsumerStatefulWidget {
  final String companyId;

  const SuperAdminOwnerDetailScreen({
    super.key,
    required this.companyId,
  });

  @override
  ConsumerState<SuperAdminOwnerDetailScreen> createState() => _SuperAdminOwnerDetailScreenState();
}

class _SuperAdminOwnerDetailScreenState extends ConsumerState<SuperAdminOwnerDetailScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameController;
  late TextEditingController _emailController;
  late TextEditingController _phoneController;

  bool _isEditing = false;
  bool _saving = false;
  bool _initialized = false;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController();
    _emailController = TextEditingController();
    _phoneController = TextEditingController();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  void _initializeValues(CompanyModel company) {
    if (_initialized) return;
    _nameController.text = company.ownerName;
    _emailController.text = company.ownerEmail;
    _phoneController.text = company.ownerPhone;
    _initialized = true;
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'active':
        return AppColors.success;
      case 'suspended':
      case 'inactive':
        return AppColors.error;
      default:
        return Colors.orange;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final companyAsync = ref.watch(companyDetailsStreamProvider(widget.companyId));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Manage Primary Owner'),
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
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Header Banner
                          Text(
                            'Administrative Account Panel for: ${company.companyName}',
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: theme.colorScheme.onSurface.withAlpha(153),
                            ),
                          ),
                          const SizedBox(height: AppSizes.p24),

                          // Owner Details Display / Edit Form
                          Card(
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(AppSizes.cardRadius),
                              side: BorderSide(color: Colors.grey.shade200, width: 1),
                            ),
                            child: Padding(
                              padding: const EdgeInsets.all(AppSizes.p24),
                              child: Form(
                                key: _formKey,
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        Text(
                                          'Primary Owner Information',
                                          style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                                        ),
                                        IconButton(
                                          icon: Icon(_isEditing ? Icons.close_rounded : Icons.edit_rounded),
                                          tooltip: _isEditing ? 'Cancel Edit' : 'Edit Credentials',
                                          onPressed: () {
                                            setState(() {
                                              if (_isEditing) {
                                                // Reset values
                                                _nameController.text = company.ownerName;
                                                _emailController.text = company.ownerEmail;
                                                _phoneController.text = company.ownerPhone;
                                              }
                                              _isEditing = !_isEditing;
                                            });
                                          },
                                        ),
                                      ],
                                    ),
                                    const Divider(),
                                    const SizedBox(height: 12),

                                    // UID Read-only
                                    _buildLabel('Account ownerUid (Immutable)'),
                                    const SizedBox(height: 4),
                                    SelectableText(
                                      company.ownerUid.isNotEmpty ? company.ownerUid : 'N/A (Pending Provision)',
                                      style: theme.textTheme.bodyMedium?.copyWith(
                                        fontFamily: 'monospace',
                                        color: Colors.grey.shade600,
                                      ),
                                    ),
                                    const SizedBox(height: 16),

                                    // Owner Name
                                    _buildLabel('Full Name *'),
                                    const SizedBox(height: 6),
                                    TextFormField(
                                      controller: _nameController,
                                      enabled: _isEditing,
                                      decoration: InputDecoration(
                                        prefixIcon: const Icon(Icons.person),
                                        border: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(AppSizes.inputRadius),
                                        ),
                                      ),
                                      validator: (val) {
                                        if (val == null || val.trim().isEmpty) return 'Name is required';
                                        return null;
                                      },
                                    ),
                                    const SizedBox(height: 16),

                                    // Owner Email
                                    _buildLabel('Email Address *'),
                                    const SizedBox(height: 6),
                                    TextFormField(
                                      controller: _emailController,
                                      enabled: _isEditing,
                                      keyboardType: TextInputType.emailAddress,
                                      decoration: InputDecoration(
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
                                    const SizedBox(height: 16),

                                    // Owner Phone
                                    _buildLabel('Phone Number *'),
                                    const SizedBox(height: 6),
                                    TextFormField(
                                      controller: _phoneController,
                                      enabled: _isEditing,
                                      keyboardType: TextInputType.phone,
                                      decoration: InputDecoration(
                                        prefixIcon: const Icon(Icons.phone),
                                        border: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(AppSizes.inputRadius),
                                        ),
                                      ),
                                      validator: (val) {
                                        if (val == null || val.trim().isEmpty) return 'Phone is required';
                                        return null;
                                      },
                                    ),
                                    const SizedBox(height: 24),

                                    if (_isEditing)
                                      SizedBox(
                                        width: double.infinity,
                                        child: ElevatedButton(
                                          onPressed: () => _updateOwnerDetails(company),
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: theme.colorScheme.primary,
                                            padding: const EdgeInsets.symmetric(vertical: 16),
                                            shape: RoundedRectangleBorder(
                                              borderRadius: BorderRadius.circular(AppSizes.buttonRadius),
                                            ),
                                          ),
                                          child: const Text('Save Owner Changes', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 24),

                          // Account Status & Suspend Controls
                          Card(
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(AppSizes.cardRadius),
                              side: BorderSide(color: Colors.grey.shade200, width: 1),
                            ),
                            child: Padding(
                              padding: const EdgeInsets.all(24),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Account Status & Operations',
                                    style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                                  ),
                                  const Divider(),
                                  const SizedBox(height: 12),
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          const Text('Login State', style: TextStyle(fontWeight: FontWeight.bold)),
                                          const SizedBox(height: 4),
                                          Text(
                                            company.ownerStatus == 'Active'
                                                ? 'Account is fully authorized to log into the ERP.'
                                                : 'Account is blocked from accessing the ERP.',
                                            style: theme.textTheme.bodySmall,
                                          ),
                                        ],
                                      ),
                                      Chip(
                                        label: Text(company.ownerStatus.toUpperCase()),
                                        backgroundColor: _getStatusColor(company.ownerStatus).withAlpha(30),
                                        labelStyle: TextStyle(
                                          color: _getStatusColor(company.ownerStatus),
                                          fontWeight: FontWeight.bold,
                                          fontSize: 12,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 24),
                                  SizedBox(
                                    width: double.infinity,
                                    child: OutlinedButton.icon(
                                      onPressed: () => _toggleOwnerStatus(company),
                                      style: OutlinedButton.styleFrom(
                                        side: BorderSide(
                                          color: company.ownerStatus == 'Active' ? AppColors.error : AppColors.success,
                                        ),
                                        padding: const EdgeInsets.symmetric(vertical: 16),
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(AppSizes.buttonRadius),
                                        ),
                                      ),
                                      icon: Icon(
                                        company.ownerStatus == 'Active' ? Icons.block : Icons.check_circle_outline,
                                        color: company.ownerStatus == 'Active' ? AppColors.error : AppColors.success,
                                      ),
                                      label: Text(
                                        company.ownerStatus == 'Active' ? 'Disable Owner Account' : 'Activate Owner Account',
                                        style: TextStyle(
                                          color: company.ownerStatus == 'Active' ? AppColors.error : AppColors.success,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
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

  Widget _buildLabel(String text) {
    return Text(
      text,
      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
    );
  }

  void _updateOwnerDetails(CompanyModel company) async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _saving = true);

    try {
      final provisionService = ref.read(accountProvisioningServiceProvider);

      // Perform validation check for duplicate email if it was modified
      final newEmail = _emailController.text.trim();
      if (newEmail != company.ownerEmail) {
        // Query users collection
        final duplicateCheck = await ref.read(superAdminRepositoryProvider).isCompanyNameDuplicate(newEmail); // wait, name and email checks
        // We will run a quick email uniqueness check directly in Firestore users collection
        final emailQuery = await FirebaseFirestore.instance
            .collection('users')
            .where('email', isEqualTo: newEmail)
            .limit(1)
            .get();
        if (emailQuery.docs.isNotEmpty) {
          throw Exception('The email address is already in use by another account.');
        }
      }

      await provisionService.updateOwner(
        companyId: company.companyId,
        ownerUid: company.ownerUid,
        name: _nameController.text.trim(),
        email: newEmail,
        phone: _phoneController.text.trim(),
      );

      setState(() {
        _isEditing = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Owner credentials updated successfully.')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to update owner: ${e.toString().replaceAll('Exception: ', '')}')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }

  void _toggleOwnerStatus(CompanyModel company) async {
    final act = company.ownerStatus == 'Active' ? 'Disable' : 'Enable';
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('$act Owner Account?'),
        content: Text('Are you sure you want to $act this owner\'s credentials?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(
              foregroundColor: company.ownerStatus == 'Active' ? AppColors.error : AppColors.success,
            ),
            child: Text(act),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() => _saving = true);

    try {
      final provisionService = ref.read(accountProvisioningServiceProvider);
      if (company.ownerStatus == 'Active') {
        await provisionService.disableOwner(companyId: company.companyId, ownerUid: company.ownerUid);
      } else {
        await provisionService.enableOwner(companyId: company.companyId, ownerUid: company.ownerUid);
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Owner status updated to ${company.ownerStatus == 'Active' ? "Suspended" : "Active"}.')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to change status: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }
}
