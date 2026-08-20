import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_sizes.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../auth/domain/models/user_model.dart';
import '../../../employee/domain/models/employee_model.dart';
import '../../domain/models/notification_model.dart';
import '../providers/notifications_provider.dart';
import '../../../employee/presentation/providers/employee_provider.dart'; // for kDepartments
import '../../../tasks/presentation/providers/tasks_provider.dart'; // for companyEmployeesProvider

class CreateAnnouncementScreen extends ConsumerStatefulWidget {
  final NotificationModel? notification;
  const CreateAnnouncementScreen({super.key, this.notification});

  @override
  ConsumerState<CreateAnnouncementScreen> createState() => _CreateAnnouncementScreenState();
}

class _CreateAnnouncementScreenState extends ConsumerState<CreateAnnouncementScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _messageController = TextEditingController();

  String _selectedType = 'Announcement';
  String _selectedPriority = 'Medium';
  String _selectedTargetType = 'Company';
  String? _selectedDepartment;
  List<String> _selectedEmployeeIds = [];

  bool _isPinned = false;
  bool _isScheduled = false;
  bool _hasExpiry = false;

  DateTime? _scheduledDate;
  TimeOfDay? _scheduledTime;
  DateTime? _expiryDate;

  bool _loading = false;
  bool _initialized = false;

  @override
  void dispose() {
    _titleController.dispose();
    _messageController.dispose();
    super.dispose();
  }

  void _initializeValues() {
    if (_initialized) return;
    final notif = widget.notification;
    if (notif != null) {
      _titleController.text = notif.title;
      _messageController.text = notif.message;
      _selectedType = notif.type;
      _selectedPriority = notif.priority;
      _selectedTargetType = notif.targetType;
      _selectedDepartment = notif.targetDepartment;
      _selectedEmployeeIds = List<String>.from(notif.targetEmployeeIds);
      _isPinned = notif.isPinned;

      if (notif.scheduledAt != null) {
        _isScheduled = true;
        _scheduledDate = notif.scheduledAt;
        _scheduledTime = TimeOfDay.fromDateTime(notif.scheduledAt!);
      }
      if (notif.expiresAt != null) {
        _hasExpiry = true;
        _expiryDate = notif.expiresAt;
      }
    }
    _initialized = true;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isEditing = widget.notification != null;

    final authState = ref.watch(authProvider);
    final user = authState.user;
    if (user == null) {
      return const Scaffold(body: Center(child: Text('Not Authenticated')));
    }

    _initializeValues();

    final employeesAsync = ref.watch(companyEmployeesProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(isEditing ? 'Edit Announcement' : 'Create Announcement'),
        elevation: 0,
        backgroundColor: theme.colorScheme.surface,
        iconTheme: IconThemeData(color: theme.colorScheme.onSurface),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : SafeArea(
              child: Center(
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
                            isEditing ? 'Modify your active announcement attributes.' : 'Draft and send general updates or targeted alerts.',
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: theme.colorScheme.onSurface.withAlpha(153),
                            ),
                          ),
                          const SizedBox(height: AppSizes.p24),

                          // Title Field
                          TextFormField(
                            controller: _titleController,
                            decoration: InputDecoration(
                              labelText: 'Announcement Title',
                              hintText: 'Enter title...',
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(AppSizes.inputRadius),
                              ),
                            ),
                            validator: (val) {
                              if (val == null || val.trim().isEmpty) {
                                return 'Title is required';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: AppSizes.p16),

                          // Message Field
                          TextFormField(
                            controller: _messageController,
                            maxLines: 5,
                            decoration: InputDecoration(
                              labelText: 'Message Body',
                              hintText: 'Type announcement content...',
                              alignLabelWithHint: true,
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(AppSizes.inputRadius),
                              ),
                            ),
                            validator: (val) {
                              if (val == null || val.trim().isEmpty) {
                                return 'Message is required';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: AppSizes.p20),

                          // Type & Priority Row
                          Row(
                            children: [
                              Expanded(
                                child: DropdownButtonFormField<String>(
                                  value: _selectedType,
                                  decoration: InputDecoration(
                                    labelText: 'Type',
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(AppSizes.inputRadius),
                                    ),
                                  ),
                                  items: kNotificationTypes.map((type) {
                                    return DropdownMenuItem(value: type, child: Text(type));
                                  }).toList(),
                                  onChanged: (val) {
                                    if (val != null) setState(() => _selectedType = val);
                                  },
                                ),
                              ),
                              const SizedBox(width: AppSizes.p16),
                              Expanded(
                                child: DropdownButtonFormField<String>(
                                  value: _selectedPriority,
                                  decoration: InputDecoration(
                                    labelText: 'Priority',
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(AppSizes.inputRadius),
                                    ),
                                  ),
                                  items: kNotificationPriorities.map((p) {
                                    return DropdownMenuItem(value: p, child: Text(p));
                                  }).toList(),
                                  onChanged: (val) {
                                    if (val != null) setState(() => _selectedPriority = val);
                                  },
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: AppSizes.p20),

                          // Targeting Category
                          Text(
                            'Target Audience',
                            style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: AppSizes.p8),
                          DropdownButtonFormField<String>(
                            value: _selectedTargetType,
                            decoration: InputDecoration(
                              labelText: 'Target Scope',
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(AppSizes.inputRadius),
                              ),
                            ),
                            items: const [
                              DropdownMenuItem(value: 'Company', child: Text('Company-Wide')),
                              DropdownMenuItem(value: 'Department', child: Text('Specific Department')),
                              DropdownMenuItem(value: 'Employee', child: Text('Specific Employees')),
                            ],
                            onChanged: (val) {
                              if (val != null) {
                                setState(() {
                                  _selectedTargetType = val;
                                  if (val != 'Department') _selectedDepartment = null;
                                  if (val != 'Employee') _selectedEmployeeIds = [];
                                });
                              }
                            },
                          ),
                          const SizedBox(height: AppSizes.p16),

                          // Conditional Targeting Options
                          if (_selectedTargetType == 'Department') ...[
                            DropdownButtonFormField<String>(
                              value: _selectedDepartment,
                              hint: const Text('Select Target Department'),
                              decoration: InputDecoration(
                                labelText: 'Department',
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(AppSizes.inputRadius),
                                ),
                              ),
                              items: kDepartments.map((dept) {
                                return DropdownMenuItem(value: dept, child: Text(dept));
                              }).toList(),
                              onChanged: (val) {
                                if (val != null) setState(() => _selectedDepartment = val);
                              },
                              validator: (val) {
                                if (_selectedTargetType == 'Department' && val == null) {
                                  return 'Please select a department';
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: AppSizes.p16),
                          ],

                          if (_selectedTargetType == 'Employee') ...[
                            employeesAsync.when(
                              loading: () => const CircularProgressIndicator(),
                              error: (e, s) => Text('Error loading employees: $e'),
                              data: (employees) {
                                return _buildEmployeeMultiSelector(employees, theme);
                              },
                            ),
                            const SizedBox(height: AppSizes.p16),
                          ],

                          // Pinned Switch
                          SwitchListTile(
                            title: const Text('Pin Announcement'),
                            subtitle: const Text('Keep this announcement featured at the top of employee dashboards.'),
                            value: _isPinned,
                            onChanged: (val) => setState(() => _isPinned = val),
                            contentPadding: EdgeInsets.zero,
                          ),
                          const Divider(height: AppSizes.p32),

                          // Scheduling Switches (Architecture & UI setup)
                          Text(
                            'Scheduling & Expiration (Optional)',
                            style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: AppSizes.p8),

                          // Schedule For Later
                          CheckboxListTile(
                            title: const Text('Schedule for later'),
                            subtitle: const Text('Specify future broadcast time.'),
                            value: _isScheduled,
                            onChanged: (val) {
                              setState(() {
                                _isScheduled = val ?? false;
                                if (_isScheduled && _scheduledDate == null) {
                                  _scheduledDate = DateTime.now();
                                  _scheduledTime = TimeOfDay.now();
                                }
                              });
                            },
                            contentPadding: EdgeInsets.zero,
                          ),
                          if (_isScheduled) ...[
                            Padding(
                              padding: const EdgeInsets.only(left: 16.0, bottom: 16.0),
                              child: Row(
                                children: [
                                  OutlinedButton.icon(
                                    onPressed: _pickScheduledDate,
                                    icon: const Icon(Icons.date_range),
                                    label: Text(
                                      _scheduledDate == null
                                          ? 'Pick Date'
                                          : DateFormat('MMM d, yyyy').format(_scheduledDate!),
                                    ),
                                  ),
                                  const SizedBox(width: AppSizes.p12),
                                  OutlinedButton.icon(
                                    onPressed: _pickScheduledTime,
                                    icon: const Icon(Icons.access_time),
                                    label: Text(
                                      _scheduledTime == null
                                          ? 'Pick Time'
                                          : _scheduledTime!.format(context),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],

                          // Expiration Date
                          CheckboxListTile(
                            title: const Text('Set expiration date'),
                            subtitle: const Text('Automatically archive/hide announcement after a specific date.'),
                            value: _hasExpiry,
                            onChanged: (val) {
                              setState(() {
                                _hasExpiry = val ?? false;
                                if (_hasExpiry && _expiryDate == null) {
                                  _expiryDate = DateTime.now().add(const Duration(days: 7));
                                }
                              });
                            },
                            contentPadding: EdgeInsets.zero,
                          ),
                          if (_hasExpiry) ...[
                            Padding(
                              padding: const EdgeInsets.only(left: 16.0, bottom: 16.0),
                              child: OutlinedButton.icon(
                                onPressed: _pickExpiryDate,
                                icon: const Icon(Icons.date_range),
                                label: Text(
                                  _expiryDate == null
                                      ? 'Pick Date'
                                      : DateFormat('MMM d, yyyy').format(_expiryDate!),
                                ),
                              ),
                            ),
                          ],

                          const SizedBox(height: AppSizes.p32),

                          // Save Button
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton(
                              onPressed: () => _saveForm(user),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: theme.colorScheme.primary,
                                padding: const EdgeInsets.symmetric(vertical: AppSizes.p16),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(AppSizes.buttonRadius),
                                ),
                              ),
                              child: Text(
                                isEditing ? 'Update Announcement' : 'Broadcast Announcement',
                                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
    );
  }

  Widget _buildEmployeeMultiSelector(List<EmployeeModel> employees, ThemeData theme) {
    final selectedEmployeesText = _selectedEmployeeIds.isEmpty
        ? 'No Employees Selected'
        : '${_selectedEmployeeIds.length} Selected';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text('Select Target Employees:'),
            TextButton.icon(
              icon: const Icon(Icons.people_alt_outlined, size: 16),
              label: const Text('Select'),
              onPressed: () => _showEmployeeSelectionDialog(employees),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            border: Border.all(color: Colors.grey.shade300),
            borderRadius: BorderRadius.circular(AppSizes.inputRadius),
          ),
          child: _selectedEmployeeIds.isEmpty
              ? Text(
                  selectedEmployeesText,
                  style: TextStyle(color: theme.hintColor),
                )
              : Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: _selectedEmployeeIds.map((id) {
                    final emp = employees.firstWhere((e) => e.employeeId == id, orElse: () => EmployeeModel(employeeId: id, uid: '', companyId: '', name: id, email: '', phone: '', role: '', department: '', designation: '', status: '', joiningDate: DateTime.now(), createdAt: DateTime.now(), updatedAt: DateTime.now()));
                    return InputChip(
                      label: Text(emp.name, style: const TextStyle(fontSize: 11)),
                      onDeleted: () {
                        setState(() {
                          _selectedEmployeeIds.remove(id);
                        });
                      },
                    );
                  }).toList(),
                ),
        ),
      ],
    );
  }

  void _showEmployeeSelectionDialog(List<EmployeeModel> employees) {
    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('Select Target Employees'),
              content: SizedBox(
                width: double.maxFinite,
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: employees.length,
                  itemBuilder: (context, index) {
                    final emp = employees[index];
                    final isChecked = _selectedEmployeeIds.contains(emp.employeeId);
                    return CheckboxListTile(
                      title: Text(emp.name),
                      subtitle: Text('${emp.designation} (${emp.department})'),
                      value: isChecked,
                      onChanged: (val) {
                        setDialogState(() {
                          if (val == true) {
                            _selectedEmployeeIds.add(emp.employeeId);
                          } else {
                            _selectedEmployeeIds.remove(emp.employeeId);
                          }
                        });
                        setState(() {}); // sync main screen state
                      },
                    );
                  },
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Done'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _pickScheduledDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _scheduledDate ?? DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime(2101),
    );
    if (picked != null) {
      setState(() => _scheduledDate = picked);
    }
  }

  Future<void> _pickScheduledTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _scheduledTime ?? TimeOfDay.now(),
    );
    if (picked != null) {
      setState(() => _scheduledTime = picked);
    }
  }

  Future<void> _pickExpiryDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _expiryDate ?? DateTime.now().add(const Duration(days: 7)),
      firstDate: DateTime.now(),
      lastDate: DateTime(2101),
    );
    if (picked != null) {
      setState(() => _expiryDate = picked);
    }
  }

  void _saveForm(UserModel user) async {
    if (!_formKey.currentState!.validate()) return;

    if (_selectedTargetType == 'Employee' && _selectedEmployeeIds.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select at least one employee')),
      );
      return;
    }

    setState(() => _loading = true);

    try {
      DateTime? scheduledDateTime;
      if (_isScheduled && _scheduledDate != null && _scheduledTime != null) {
        scheduledDateTime = DateTime(
          _scheduledDate!.year,
          _scheduledDate!.month,
          _scheduledDate!.day,
          _scheduledTime!.hour,
          _scheduledTime!.minute,
        );
      }

      final notifId = widget.notification?.notificationId ??
          FirebaseFirestore.instance.collection('companies').doc(user.companyId).collection('notifications').doc().id;

      final newNotification = NotificationModel(
        notificationId: notifId,
        companyId: user.companyId,
        title: _titleController.text.trim(),
        message: _messageController.text.trim(),
        type: _selectedType,
        priority: _selectedPriority,
        targetType: _selectedTargetType,
        targetDepartment: _selectedDepartment,
        targetEmployeeIds: _selectedEmployeeIds,
        createdByUid: user.uid,
        createdByName: user.name,
        createdAt: widget.notification?.createdAt ?? DateTime.now(),
        scheduledAt: scheduledDateTime,
        expiresAt: _hasExpiry ? _expiryDate : null,
        isPinned: _isPinned,
      );

      final repo = ref.read(notificationRepositoryProvider);
      if (widget.notification != null) {
        await repo.updateNotification(user.companyId, newNotification);
      } else {
        await repo.createNotification(user.companyId, newNotification);
      }

      if (mounted) {
        context.pop(); // return to dashboard or history list
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to save: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }
}
