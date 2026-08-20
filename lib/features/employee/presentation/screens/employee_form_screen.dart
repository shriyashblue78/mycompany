import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_sizes.dart';
import '../../../../core/widgets/custom_button.dart';
import '../../../../core/widgets/responsive_widgets.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../domain/models/employee_model.dart';
import '../providers/employee_provider.dart';
import '../../../notifications/presentation/providers/notifications_provider.dart';

class EmployeeFormScreen extends ConsumerStatefulWidget {
  final String? employeeId;
  final EmployeeModel? employee;

  const EmployeeFormScreen({
    super.key,
    this.employeeId,
    this.employee,
  });

  @override
  ConsumerState<EmployeeFormScreen> createState() => _EmployeeFormScreenState();
}

class _EmployeeFormScreenState extends ConsumerState<EmployeeFormScreen> {
  final _formKey = GlobalKey<FormState>();

  // Text Controllers
  late final TextEditingController _idController;
  late final TextEditingController _nameController;
  late final TextEditingController _emailController;
  late final TextEditingController _phoneController;
  late final TextEditingController _designationController;
  late final TextEditingController _passwordController;
  late final TextEditingController _confirmPasswordController;

  // Selected State variables
  String? _selectedDept;
  String? _selectedRole;
  String _selectedStatus = 'Active';
  DateTime _joiningDate = DateTime.now();
  String? _selectedAvatarUrl;

  bool _isLoading = false;
  bool _isEditMode = false;
  String? _formErrorMessage;

  // Predefined high-quality user avatars
  final List<String> _avatars = [
    'https://images.unsplash.com/photo-1534528741775-53994a69daeb?auto=format&fit=crop&w=150&q=80',
    'https://images.unsplash.com/photo-1507003211169-0a1dd7228f2d?auto=format&fit=crop&w=150&q=80',
    'https://images.unsplash.com/photo-1494790108377-be9c29b29330?auto=format&fit=crop&w=150&q=80',
    'https://images.unsplash.com/photo-1500648767791-00dcc994a43e?auto=format&fit=crop&w=150&q=80',
    'https://images.unsplash.com/photo-1522075469751-3a6694fb2f61?auto=format&fit=crop&w=150&q=80',
  ];

  @override
  void initState() {
    super.initState();
    _isEditMode = widget.employeeId != null;

    _idController = TextEditingController();
    _nameController = TextEditingController();
    _emailController = TextEditingController();
    _phoneController = TextEditingController();
    _designationController = TextEditingController();
    _passwordController = TextEditingController();
    _confirmPasswordController = TextEditingController();

    if (_isEditMode) {
      _prepopulateForm();
    } else {
      _generateUniqueId();
    }
  }

  void _prepopulateForm() {
    final emp = widget.employee;
    if (emp != null) {
      _idController.text = emp.employeeId;
      _nameController.text = emp.name;
      _emailController.text = emp.email;
      _phoneController.text = emp.phone;
      _designationController.text = emp.designation;
      _selectedDept = emp.department;
      _selectedRole = emp.role;
      _selectedStatus = emp.status;
      _joiningDate = emp.joiningDate;
      _selectedAvatarUrl = emp.photoUrl;
    }
  }

  Future<void> _generateUniqueId() async {
    final random = Random();
    final nextId = 'EMP-${random.nextInt(9000) + 1000}';
    _idController.text = nextId;
  }

  @override
  void dispose() {
    _idController.dispose();
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _designationController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _selectJoiningDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _joiningDate,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked != null && picked != _joiningDate) {
      setState(() {
        _joiningDate = picked;
      });
    }
  }

  Future<void> _saveForm() async {
    setState(() {
      _formErrorMessage = null;
    });

    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
    });

    final authState = ref.read(authProvider);
    final companyId = authState.user?.companyId;
    final repository = ref.read(employeeRepositoryProvider);

    if (companyId == null) {
      setState(() {
        _isLoading = false;
        _formErrorMessage = 'Unauthorized company context.';
      });
      return;
    }

    final empId = _idController.text.trim();
    final email = _emailController.text.trim();

    try {
      if (_isEditMode) {
        // Edit flow
        final existingEmp = widget.employee;
        if (existingEmp == null) throw Exception('Employee metadata not loaded.');

        final updatedModel = EmployeeModel(
          employeeId: existingEmp.employeeId,
          uid: existingEmp.uid,
          companyId: companyId,
          name: _nameController.text.trim(),
          email: existingEmp.email,
          phone: _phoneController.text.trim(),
          role: _selectedRole!,
          department: _selectedDept!,
          designation: _designationController.text.trim(),
          status: _selectedStatus,
          photoUrl: _selectedAvatarUrl,
          joiningDate: _joiningDate,
          createdAt: existingEmp.createdAt,
          updatedAt: DateTime.now(),
          lastLogin: existingEmp.lastLogin,
        );

        await repository.updateEmployee(
          companyId: companyId,
          employee: updatedModel,
        );

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Employee profile updated successfully.'),
              backgroundColor: AppColors.success,
            ),
          );
          context.pop();
        }
      } else {
        // Add flow
        // 1. Check duplicate ID
        final isIdDuplicate = await repository.isEmployeeIdExists(companyId, empId);
        if (isIdDuplicate) {
          setState(() {
            _isLoading = false;
            _formErrorMessage = 'Employee ID "$empId" is already in use by this company.';
          });
          return;
        }

        // 2. Check duplicate email
        final isEmailDuplicate = await repository.isEmailExists(email);
        if (isEmailDuplicate) {
          setState(() {
            _isLoading = false;
            _formErrorMessage = 'Email "$email" is already registered in the system.';
          });
          return;
        }

        // 3. Create the employee model
        final newEmployee = EmployeeModel(
          employeeId: empId,
          uid: '', // Populated client-side in transaction
          companyId: companyId,
          name: _nameController.text.trim(),
          email: email,
          phone: _phoneController.text.trim(),
          role: _selectedRole!,
          department: _selectedDept!,
          designation: _designationController.text.trim(),
          status: _selectedStatus,
          photoUrl: _selectedAvatarUrl,
          joiningDate: _joiningDate,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );

        await repository.createEmployee(
          companyId: companyId,
          employee: newEmployee,
          password: _passwordController.text,
        );

        // Trigger new employee notification
        await ref.read(notificationServiceProvider).notifyNewEmployeeAdded(
          companyId: companyId,
          employeeId: empId,
          employeeName: newEmployee.name,
          designation: newEmployee.designation,
          department: newEmployee.department,
          userUid: authState.user?.uid ?? '',
          userName: authState.user?.name ?? 'System',
        );

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Employee registered successfully in Auth & Firestore.'),
              backgroundColor: AppColors.success,
            ),
          );
          context.pop();
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _formErrorMessage = e.toString().replaceAll('Exception: ', '');
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Stack(
      children: [
        ResponsiveScaffold(
          appBar: AppBar(
            title: Text(_isEditMode ? 'Edit Employee' : 'Add Employee'),
            elevation: 0,
            backgroundColor: theme.colorScheme.surface,
            iconTheme: IconThemeData(color: theme.colorScheme.onSurface),
          ),
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(AppSizes.p24),
            child: Center(
              child: Container(
                constraints: const BoxConstraints(maxWidth: 600),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Form Header
                      Text(
                        _isEditMode ? 'Modify Employee Profile' : 'Register New Employee',
                        style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: AppSizes.p8),
                      Text(
                        _isEditMode
                            ? 'Update personal info, roles, or status.'
                            : 'This will automatically register a new Firebase Auth account and construct Firestore profiles.',
                        style: theme.textTheme.bodyMedium?.copyWith(color: Colors.grey.shade500),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: AppSizes.p24),

                      if (_formErrorMessage != null) ...[
                        Container(
                          padding: const EdgeInsets.all(AppSizes.p12),
                          decoration: BoxDecoration(
                            color: AppColors.error.withAlpha(26),
                            borderRadius: BorderRadius.circular(AppSizes.inputRadius),
                            border: Border.all(color: AppColors.error.withAlpha(77)),
                          ),
                          child: Text(
                            _formErrorMessage!,
                            style: TextStyle(
                              color: isDark ? Colors.red.shade300 : Colors.red.shade700,
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        const SizedBox(height: AppSizes.p20),
                      ],

                      // Avatar Selection
                      Text(
                        'Select Profile Picture',
                        style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: AppSizes.p8),
                      SizedBox(
                        height: 70,
                        child: ListView(
                          scrollDirection: Axis.horizontal,
                          children: [
                            GestureDetector(
                              onTap: () {
                                setState(() {
                                  _selectedAvatarUrl = null;
                                });
                              },
                              child: Container(
                                margin: const EdgeInsets.only(right: 12),
                                width: 60,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: _selectedAvatarUrl == null
                                        ? theme.colorScheme.primary
                                        : Colors.grey.shade300,
                                    width: _selectedAvatarUrl == null ? 3.0 : 1.0,
                                  ),
                                  color: isDark ? Colors.white.withAlpha(20) : Colors.grey.shade100,
                                ),
                                child: Icon(Icons.person_outline_rounded, color: Colors.grey.shade600),
                              ),
                            ),
                            ..._avatars.map((url) {
                              final isSelected = _selectedAvatarUrl == url;
                              return GestureDetector(
                                onTap: () {
                                  setState(() {
                                    _selectedAvatarUrl = url;
                                  });
                                },
                                child: Container(
                                  margin: const EdgeInsets.only(right: 12),
                                  width: 60,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: isSelected ? theme.colorScheme.primary : Colors.grey.shade300,
                                      width: isSelected ? 3.0 : 1.0,
                                    ),
                                    image: DecorationImage(
                                      image: NetworkImage(url),
                                      fit: BoxFit.cover,
                                    ),
                                  ),
                                ),
                              );
                            }),
                          ],
                        ),
                      ),
                      const SizedBox(height: AppSizes.p24),

                      // Employee ID field
                      _buildLabel('Employee ID *'),
                      TextFormField(
                        controller: _idController,
                        readOnly: _isEditMode,
                        style: TextStyle(
                          color: _isEditMode ? Colors.grey : theme.textTheme.bodyLarge?.color,
                          fontFamily: 'monospace',
                        ),
                        decoration: InputDecoration(
                          hintText: 'e.g. EMP-101',
                          prefixIcon: const Icon(Icons.badge_outlined),
                          fillColor: _isEditMode
                              ? (isDark ? Colors.white.withAlpha(5) : Colors.grey.shade50)
                              : null,
                        ),
                        validator: (val) {
                          if (val == null || val.trim().isEmpty) return 'Employee ID is required';
                          return null;
                        },
                      ),
                      const SizedBox(height: AppSizes.p16),

                      // Name field
                      _buildLabel('Full Name *'),
                      TextFormField(
                        controller: _nameController,
                        decoration: const InputDecoration(
                          hintText: 'John Doe',
                          prefixIcon: Icon(Icons.person_outline_rounded),
                        ),
                        validator: (val) {
                          if (val == null || val.trim().isEmpty) return 'Full Name is required';
                          return null;
                        },
                      ),
                      const SizedBox(height: AppSizes.p16),

                      // Email field
                      _buildLabel('Email Address *'),
                      TextFormField(
                        controller: _emailController,
                        readOnly: _isEditMode,
                        keyboardType: TextInputType.emailAddress,
                        style: TextStyle(
                          color: _isEditMode ? Colors.grey : theme.textTheme.bodyLarge?.color,
                        ),
                        decoration: InputDecoration(
                          hintText: 'john.doe@company.com',
                          prefixIcon: const Icon(Icons.email_outlined),
                          fillColor: _isEditMode
                              ? (isDark ? Colors.white.withAlpha(5) : Colors.grey.shade50)
                              : null,
                        ),
                        validator: (val) {
                          if (val == null || val.trim().isEmpty) return 'Email is required';
                          if (!val.contains('@')) return 'Enter a valid email address';
                          return null;
                        },
                      ),
                      const SizedBox(height: AppSizes.p16),

                      // Phone field
                      _buildLabel('Phone Number *'),
                      TextFormField(
                        controller: _phoneController,
                        keyboardType: TextInputType.phone,
                        decoration: const InputDecoration(
                          hintText: 'e.g. +12345678900',
                          prefixIcon: Icon(Icons.phone_outlined),
                        ),
                         validator: (val) {
                           if (val == null || val.trim().isEmpty) return 'Phone number is required';
                           final phoneRegex = RegExp(r'^\+?[0-9]{10,15}$');
                           if (!phoneRegex.hasMatch(val.trim())) {
                             return 'Enter a valid phone number (10-15 digits)';
                           }
                           return null;
                         },
                      ),
                      const SizedBox(height: AppSizes.p16),

                      // Row of Dept & Role
                      ResponsiveFormRow(
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _buildLabel('Department *'),
                              DropdownButtonFormField<String>(
                                initialValue: _selectedDept,
                                decoration: const InputDecoration(
                                  contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                                ),
                                items: kDepartments.map((d) {
                                  return DropdownMenuItem(value: d, child: Text(d, style: const TextStyle(fontSize: 14)));
                                }).toList(),
                                validator: (val) => val == null ? 'Required' : null,
                                onChanged: (val) {
                                  setState(() {
                                    _selectedDept = val;
                                  });
                                },
                              ),
                            ],
                          ),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _buildLabel('System Role *'),
                              DropdownButtonFormField<String>(
                                initialValue: _selectedRole,
                                decoration: const InputDecoration(
                                  contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                                ),
                                items: kRoles.where((r) => r != 'Owner').map((r) {
                                  return DropdownMenuItem(value: r, child: Text(r, style: const TextStyle(fontSize: 14)));
                                }).toList(),
                                validator: (val) => val == null ? 'Required' : null,
                                onChanged: (val) {
                                  setState(() {
                                    _selectedRole = val;
                                  });
                                },
                              ),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: AppSizes.p16),

                      // Designation field
                      _buildLabel('Designation *'),
                      TextFormField(
                        controller: _designationController,
                        decoration: const InputDecoration(
                          hintText: 'e.g. Senior Software Engineer',
                          prefixIcon: Icon(Icons.work_outline_rounded),
                        ),
                        validator: (val) {
                          if (val == null || val.trim().isEmpty) return 'Designation is required';
                          return null;
                        },
                      ),
                      const SizedBox(height: AppSizes.p16),

                      // Joining Date field
                      _buildLabel('Joining Date *'),
                      InkWell(
                        onTap: () => _selectJoiningDate(context),
                        borderRadius: BorderRadius.circular(AppSizes.inputRadius),
                        child: InputDecorator(
                          decoration: const InputDecoration(
                            prefixIcon: Icon(Icons.calendar_today_outlined),
                          ),
                          child: Text(
                            DateFormat('MMMM dd, yyyy').format(_joiningDate),
                            style: theme.textTheme.bodyLarge,
                          ),
                        ),
                      ),
                      const SizedBox(height: AppSizes.p16),

                      // Password fields (only on Add)
                      if (!_isEditMode) ...[
                        ResponsiveFormRow(
                          children: [
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _buildLabel('Password *'),
                                TextFormField(
                                  controller: _passwordController,
                                  obscureText: true,
                                  decoration: const InputDecoration(
                                    hintText: '••••••••',
                                    prefixIcon: Icon(Icons.lock_outline_rounded),
                                  ),
                                  validator: (val) {
                                    if (val == null || val.isEmpty) return 'Password is required';
                                    
                                    // Password strength validation:
                                    // min 8 chars, 1 uppercase, 1 lowercase, 1 number, 1 special char
                                    final passwordRegex = RegExp(
                                        r'^(?=.*[a-z])(?=.*[A-Z])(?=.*\d)(?=.*[@$!%*?&])[A-Za-z\d@$!%*?&]{8,}$');
                                    if (!passwordRegex.hasMatch(val)) {
                                      return 'Must be 8+ chars with uppercase, lowercase, number, and special char';
                                    }
                                    return null;
                                  },
                                ),
                              ],
                            ),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _buildLabel('Confirm Password *'),
                                TextFormField(
                                  controller: _confirmPasswordController,
                                  obscureText: true,
                                  decoration: const InputDecoration(
                                    hintText: '••••••••',
                                    prefixIcon: Icon(Icons.lock_outline_rounded),
                                  ),
                                  validator: (val) {
                                    if (val == null || val.isEmpty) return 'Please confirm your password';
                                    if (val != _passwordController.text) return 'Passwords do not match';
                                    return null;
                                  },
                                ),
                              ],
                            ),
                          ],
                        ),
                        const SizedBox(height: AppSizes.p16),
                      ],

                      // Status (Toggle)
                      _buildLabel('Account Status'),
                      DropdownButtonFormField<String>(
                        initialValue: _selectedStatus,
                        decoration: const InputDecoration(
                          contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                        ),
                        items: kStatuses.map((s) {
                          return DropdownMenuItem(value: s, child: Text(s, style: const TextStyle(fontSize: 14)));
                        }).toList(),
                        onChanged: (val) {
                          if (val != null) {
                            setState(() {
                              _selectedStatus = val;
                            });
                          }
                        },
                      ),
                      const SizedBox(height: AppSizes.p32),

                      // Submit button
                      CustomButton(
                        text: _isEditMode ? 'Update Employee' : 'Create Employee',
                        onPressed: _saveForm,
                      ),
                      const SizedBox(height: AppSizes.p24),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
        if (_isLoading)
          const Positioned.fill(
            child: ModalBarrier(
              dismissible: false,
              color: Colors.black26,
            ),
          ),
        if (_isLoading)
          const Center(
            child: CircularProgressIndicator(),
          ),
      ],
    );
  }

  Widget _buildLabel(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSizes.p8),
      child: Text(
        text,
        style: const TextStyle(
          fontWeight: FontWeight.w600,
          fontSize: 13,
        ),
      ),
    );
  }
}
