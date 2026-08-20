import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart' show FirebaseAuth, EmailAuthProvider, EmailAuthCredential;
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_sizes.dart';
import '../../../../core/widgets/erp_drawer.dart';
import '../../../../core/widgets/responsive_layout.dart';
import '../../../../core/widgets/responsive_widgets.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../providers/settings_provider.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  final _companyFormKey = GlobalKey<FormState>();
  final _profileFormKey = GlobalKey<FormState>();

  // Company Controllers
  final _companyNameController = TextEditingController();
  final _companyOwnerController = TextEditingController();
  final _companyEmailController = TextEditingController();
  final _companyPhoneController = TextEditingController();
  final _companyAddressController = TextEditingController();
  final _companyGstController = TextEditingController();
  final _performanceDeductionController = TextEditingController();

  // Profile Controllers
  final _profileNameController = TextEditingController();
  final _profilePhoneController = TextEditingController();

  bool _initialized = false;
  bool _savingCompany = false;
  bool _savingProfile = false;

  @override
  void dispose() {
    _companyNameController.dispose();
    _companyOwnerController.dispose();
    _companyEmailController.dispose();
    _companyPhoneController.dispose();
    _companyAddressController.dispose();
    _companyGstController.dispose();
    _performanceDeductionController.dispose();
    _profileNameController.dispose();
    _profilePhoneController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    
    final authState = ref.watch(authProvider);
    final user = authState.user;

    if (user == null) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final role = user.role;
    final isOwner = role == 'Owner';
    final isEmployee = role == 'Employee';
    final isSupervisor = role == 'Supervisor';
    final canChangePassword = role == 'Owner' || role == 'HR' || role == 'Employee';

    // Watch the database streams
    final companyAsync = ref.watch(currentCompanyStreamProvider);
    final profileAsync = ref.watch(currentUserProfileStreamProvider);

    if (!_initialized && companyAsync.value != null && profileAsync.value != null) {
      final company = companyAsync.value!;
      final profile = profileAsync.value!;

      // Populate company
      _companyNameController.text = company.companyName;
      _companyOwnerController.text = company.ownerName;
      _companyEmailController.text = company.email;
      _companyPhoneController.text = company.phone;
      _companyAddressController.text = company.address;
      _companyGstController.text = company.gstNumber;
      _performanceDeductionController.text = company.performanceDeductionPerMinute.toString();

      // Populate profile
      _profileNameController.text = (profile['name'] ?? '') as String;
      _profilePhoneController.text = (profile['phone'] ?? '') as String;

      _initialized = true;
    }

    return ResponsiveScaffold(
      appBar: AppBar(
        title: const Text('Settings'),
        elevation: 0,
        backgroundColor: theme.colorScheme.surface,
        iconTheme: IconThemeData(color: theme.colorScheme.onSurface),
      ),
      drawer: const ERPDrawer(),
      body: SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(AppSizes.p24),
            child: Center(
              child: Container(
                constraints: const BoxConstraints(maxWidth: 600),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 1. My Profile Section
                    _buildSectionHeader(theme, 'My Profile', Icons.person_outline_rounded),
                    const SizedBox(height: AppSizes.p12),
                    profileAsync.when(
                      data: (profileMap) {
                        if (profileMap == null) return const Text('Error loading profile.');
                        return _buildProfileCard(theme, profileMap, isDark);
                      },
                      loading: () => const Center(child: CircularProgressIndicator()),
                      error: (err, stack) => Text('Error loading profile: $err'),
                    ),
                    const SizedBox(height: AppSizes.p32),

                    // 2. Company Profile Section (Hidden for Employees)
                    if (!isEmployee) ...[
                      _buildSectionHeader(theme, 'Company Profile', Icons.business_rounded),
                      const SizedBox(height: AppSizes.p12),
                      companyAsync.when(
                        data: (company) {
                          if (company == null) return const Text('Error loading company.');
                          return _buildCompanyCard(theme, isOwner, isDark);
                        },
                        loading: () => const Center(child: CircularProgressIndicator()),
                        error: (err, stack) => Text('Error loading company: $err'),
                      ),
                      const SizedBox(height: AppSizes.p32),
                    ],

                    // 3. App Settings / Actions Section
                    _buildSectionHeader(theme, 'App Actions', Icons.settings_applications_rounded),
                    const SizedBox(height: AppSizes.p12),
                    _buildActionsCard(context, theme, canChangePassword, isDark),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSectionHeader(ThemeData theme, String title, IconData icon) {
    return Row(
      children: [
        Icon(icon, color: theme.colorScheme.primary, size: 22),
        const SizedBox(width: 8),
        Text(
          title,
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
            color: theme.colorScheme.primary,
          ),
        ),
      ],
    );
  }

  Widget _buildProfileCard(ThemeData theme, Map<String, dynamic> profile, bool isDark) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: theme.dividerColor.withAlpha(40)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppSizes.p20),
        child: Form(
          key: _profileFormKey,
          child: Column(
            children: [
              // Avatar Placeholder
              CircleAvatar(
                radius: 40,
                backgroundColor: theme.colorScheme.primary.withAlpha(25),
                child: Icon(Icons.person_rounded, size: 48, color: theme.colorScheme.primary),
              ),
              const SizedBox(height: AppSizes.p20),

              // Name field
              TextFormField(
                controller: _profileNameController,
                decoration: InputDecoration(
                  labelText: 'Full Name *',
                  prefixIcon: const Icon(Icons.badge_outlined),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(AppSizes.inputRadius)),
                ),
                validator: (val) => val == null || val.trim().isEmpty ? 'Name is required' : null,
              ),
              const SizedBox(height: AppSizes.p16),

              // Phone field
              TextFormField(
                controller: _profilePhoneController,
                keyboardType: TextInputType.phone,
                decoration: InputDecoration(
                  labelText: 'Phone *',
                  prefixIcon: const Icon(Icons.phone_outlined),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(AppSizes.inputRadius)),
                ),
                validator: (val) => val == null || val.trim().isEmpty ? 'Phone is required' : null,
              ),
              const SizedBox(height: AppSizes.p16),

              // Read-only Details (Email, Employee ID, Department, Role)
              _buildReadOnlyTile(theme, 'Email Address', (profile['email'] ?? '') as String),
              _buildReadOnlyTile(theme, 'Employee ID', (profile['employeeId'] ?? '') as String),
              _buildReadOnlyTile(theme, 'Role', (profile['role'] ?? '') as String),
              _buildReadOnlyTile(theme, 'Department', (profile['department'] ?? '') as String),
              const SizedBox(height: AppSizes.p16),

              // Save button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _savingProfile ? null : _saveProfile,
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppSizes.buttonRadius)),
                  ),
                  child: _savingProfile
                      ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2))
                      : const Text('Update Profile'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCompanyCard(ThemeData theme, bool isOwner, bool isDark) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: theme.dividerColor.withAlpha(40)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppSizes.p20),
        child: Form(
          key: _companyFormKey,
          child: Column(
            children: [
              // Logo Placeholder
              Container(
                width: 70,
                height: 70,
                decoration: BoxDecoration(
                  color: theme.colorScheme.primary.withAlpha(20),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(Icons.business_rounded, size: 36, color: theme.colorScheme.primary),
              ),
              const SizedBox(height: AppSizes.p20),

              // Company Name
              TextFormField(
                controller: _companyNameController,
                enabled: isOwner,
                decoration: InputDecoration(
                  labelText: 'Company Name *',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(AppSizes.inputRadius)),
                ),
                validator: (val) => val == null || val.trim().isEmpty ? 'Company Name is required' : null,
              ),
              const SizedBox(height: AppSizes.p16),

              // Owner Name
              TextFormField(
                controller: _companyOwnerController,
                enabled: isOwner,
                decoration: InputDecoration(
                  labelText: 'Owner Name *',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(AppSizes.inputRadius)),
                ),
                validator: (val) => val == null || val.trim().isEmpty ? 'Owner Name is required' : null,
              ),
              const SizedBox(height: AppSizes.p16),

              // Email Address
              TextFormField(
                controller: _companyEmailController,
                enabled: isOwner,
                keyboardType: TextInputType.emailAddress,
                decoration: InputDecoration(
                  labelText: 'Email Address *',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(AppSizes.inputRadius)),
                ),
                validator: (val) => val == null || val.trim().isEmpty ? 'Email is required' : null,
              ),
              const SizedBox(height: AppSizes.p16),

              // Phone Number
              TextFormField(
                controller: _companyPhoneController,
                enabled: isOwner,
                keyboardType: TextInputType.phone,
                decoration: InputDecoration(
                  labelText: 'Phone Number *',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(AppSizes.inputRadius)),
                ),
                validator: (val) => val == null || val.trim().isEmpty ? 'Phone is required' : null,
              ),
              const SizedBox(height: AppSizes.p16),

              // Address
              TextFormField(
                controller: _companyAddressController,
                enabled: isOwner,
                maxLines: 2,
                decoration: InputDecoration(
                  labelText: 'Address *',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(AppSizes.inputRadius)),
                ),
                validator: (val) => val == null || val.trim().isEmpty ? 'Address is required' : null,
              ),
              const SizedBox(height: AppSizes.p16),

              // GST Number
              TextFormField(
                controller: _companyGstController,
                enabled: isOwner,
                decoration: InputDecoration(
                  labelText: 'GST Number (Optional)',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(AppSizes.inputRadius)),
                ),
              ),
              const SizedBox(height: AppSizes.p16),

              // Performance Deduction per late minute
              TextFormField(
                controller: _performanceDeductionController,
                enabled: isOwner,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: 'Performance Deduction per Late Minute (points) *',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(AppSizes.inputRadius)),
                  helperText: 'Deducted from late tasks (default: 1 point/minute)',
                ),
                validator: (val) {
                  if (val == null || val.trim().isEmpty) {
                    return 'Deduction per minute is required';
                  }
                  final parsed = int.tryParse(val.trim());
                  if (parsed == null || parsed < 0) {
                    return 'Please enter a valid positive number';
                  }
                  return null;
                },
              ),
              const SizedBox(height: AppSizes.p16),

              // Save Button (Only for Owners)
              if (isOwner)
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _savingCompany ? null : _saveCompany,
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppSizes.buttonRadius)),
                    ),
                    child: _savingCompany
                        ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2))
                        : const Text('Save Company Details'),
                  ),
                )
              else
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.amber.withAlpha(25),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.amber, width: 0.5),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.lock_rounded, color: Colors.amber, size: 18),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Company profile changes are locked. Only Owners can edit company info.',
                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
                        ),
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

  Widget _buildActionsCard(BuildContext context, ThemeData theme, bool canChangePassword, bool isDark) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: theme.dividerColor.withAlpha(40)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSizes.p8),
        child: Column(
          children: [
            if (canChangePassword) ...[
              ListTile(
                leading: Icon(Icons.vpn_key_outlined, color: theme.colorScheme.primary),
                title: const Text('Change Password'),
                trailing: const Icon(Icons.chevron_right_rounded),
                onTap: () => _showChangePasswordDialog(context),
              ),
              Divider(height: 1, color: theme.dividerColor.withAlpha(30)),
            ],
            ListTile(
              leading: Icon(Icons.info_outline_rounded, color: theme.colorScheme.primary),
              title: const Text('About App'),
              trailing: const Icon(Icons.chevron_right_rounded),
              onTap: () => _showAboutAppDialog(context),
            ),
            Divider(height: 1, color: theme.dividerColor.withAlpha(30)),
            ListTile(
              leading: const Icon(Icons.logout_rounded, color: AppColors.error),
              title: const Text('Logout', style: TextStyle(color: AppColors.error, fontWeight: FontWeight.bold)),
              onTap: () => ref.read(authProvider.notifier).logout(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildReadOnlyTile(ThemeData theme, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(color: theme.textTheme.bodySmall?.color?.withOpacity(0.5), fontSize: 13)),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 14)),
        ],
      ),
    );
  }

  void _saveProfile() async {
    if (!_profileFormKey.currentState!.validate()) return;

    setState(() => _savingProfile = true);

    try {
      final authState = ref.read(authProvider);
      final user = authState.user;
      if (user != null) {
        final name = _profileNameController.text.trim();
        final phone = _profilePhoneController.text.trim();

        // 1. Update /users/{uid}
        await FirebaseFirestore.instance.collection('users').doc(user.uid).update({
          'name': name,
          'phone': phone,
          'updatedAt': DateTime.now().toIso8601String(),
        });

        // 2. Sync to /companies/{companyId}/employees/{employeeId}
        if (user.role == 'Owner' || user.role == 'HR' || user.role == 'Supervisor') {
          await FirebaseFirestore.instance
              .collection('companies')
              .doc(user.companyId)
              .collection('employees')
              .doc(user.employeeId)
              .update({
                'name': name,
                'phone': phone,
                'updatedAt': DateTime.now().toIso8601String(),
              });
        }

        // Refresh Auth State so the UI reflects the new name
        await ref.read(authProvider.notifier).refreshProfile();

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Profile updated successfully.')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to update profile: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _savingProfile = false);
      }
    }
  }

  void _saveCompany() async {
    if (!_companyFormKey.currentState!.validate()) return;

    setState(() => _savingCompany = true);

    try {
      final authState = ref.read(authProvider);
      final companyId = authState.user?.companyId;
      if (companyId != null) {
        await FirebaseFirestore.instance.collection('companies').doc(companyId).update({
          'companyName': _companyNameController.text.trim(),
          'ownerName': _companyOwnerController.text.trim(),
          'email': _companyEmailController.text.trim(),
          'phone': _companyPhoneController.text.trim(),
          'address': _companyAddressController.text.trim(),
          'gstNumber': _companyGstController.text.trim(),
          'performanceDeductionPerMinute': int.tryParse(_performanceDeductionController.text.trim()) ?? 1,
          'updatedAt': FieldValue.serverTimestamp(),
        });

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Company details saved successfully.')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to save company details: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _savingCompany = false);
      }
    }
  }

  void _showChangePasswordDialog(BuildContext context) {
    final currentPasswordController = TextEditingController();
    final newPasswordController = TextEditingController();
    final confirmPasswordController = TextEditingController();
    final dialogFormKey = GlobalKey<FormState>();
    bool processing = false;

    showDialog(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('Change Password'),
              content: Form(
                key: dialogFormKey,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextFormField(
                        controller: currentPasswordController,
                        obscureText: true,
                        decoration: const InputDecoration(labelText: 'Current Password *'),
                        validator: (val) => val == null || val.isEmpty ? 'Current Password is required' : null,
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: newPasswordController,
                        obscureText: true,
                        decoration: const InputDecoration(labelText: 'New Password *'),
                        validator: (val) {
                          if (val == null || val.isEmpty) return 'New Password is required';
                          if (val.length < 6) return 'Password must be at least 6 characters';
                          return null;
                        },
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: confirmPasswordController,
                        obscureText: true,
                        decoration: const InputDecoration(labelText: 'Confirm Password *'),
                        validator: (val) {
                          if (val == null || val.isEmpty) return 'Confirm Password is required';
                          if (val != newPasswordController.text) return 'Passwords do not match';
                          return null;
                        },
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: processing ? null : () => Navigator.pop(dialogContext),
                  child: const Text('Cancel'),
                ),
                TextButton(
                  onPressed: processing
                      ? null
                      : () async {
                          if (!dialogFormKey.currentState!.validate()) return;
                          setDialogState(() => processing = true);
                          try {
                            final user = FirebaseAuth.instance.currentUser;
                            if (user == null || user.email == null) {
                              throw Exception('Auth user is null.');
                            }

                            // Reauthenticate user
                            final credential = EmailAuthProvider.credential(
                              email: user.email!,
                              password: currentPasswordController.text,
                            );
                            await user.reauthenticateWithCredential(credential);

                            // Update password
                            await user.updatePassword(newPasswordController.text);

                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Password updated successfully.')),
                              );
                              Navigator.pop(dialogContext);
                            }
                          } catch (e) {
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text('Password update failed: $e')),
                              );
                            }
                          } finally {
                            setDialogState(() => processing = false);
                          }
                        },
                  child: processing
                      ? const SizedBox(height: 16, width: 16, child: CircularProgressIndicator(strokeWidth: 2))
                      : const Text('Save'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _showAboutAppDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.info_outline_rounded, color: AppColors.primaryLight),
              SizedBox(width: 8),
              Text('About App'),
            ],
          ),
          content: const Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Manufacturing ERP v1.0.0',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              SizedBox(height: 8),
              Text(
                'All-in-One Enterprise Platform customized for small and medium manufacturing companies.\n\n'
                'Provides workforce management, real-time attendance check-ins, job delegations, inventory controls, purchase receipts, and sales dispatch workflows.',
                style: TextStyle(fontSize: 13, height: 1.4),
              ),
              SizedBox(height: 16),
              Text(
                '© 2026 MyCompany Inc.',
                style: TextStyle(fontSize: 11, color: Colors.grey),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Close'),
            ),
          ],
        );
      },
    );
  }
}
