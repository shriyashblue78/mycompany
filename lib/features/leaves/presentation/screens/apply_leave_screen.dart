import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_sizes.dart';
import '../../../../core/widgets/responsive_widgets.dart';
import '../../../../core/services/storage_service.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../domain/models/leave_model.dart';
import '../providers/leaves_provider.dart';

class ApplyLeaveScreen extends ConsumerStatefulWidget {
  const ApplyLeaveScreen({super.key});

  @override
  ConsumerState<ApplyLeaveScreen> createState() => _ApplyLeaveScreenState();
}

class _ApplyLeaveScreenState extends ConsumerState<ApplyLeaveScreen> {
  final _formKey = GlobalKey<FormState>();
  final _reasonController = TextEditingController();

  String _selectedType = 'Casual Leave';
  DateTime _startDate = DateTime.now();
  DateTime _endDate = DateTime.now();
  double _totalDays = 1.0;

  String? _uploadedDocumentUrl;
  String? _uploadedDocumentName;
  bool _uploadingFile = false;
  bool _submitting = false;

  @override
  void dispose() {
    _reasonController.dispose();
    super.dispose();
  }

  void _calculateTotalDays() {
    if (_selectedType == 'Half Day') {
      setState(() {
        _totalDays = 0.5;
      });
      return;
    }

    final start = DateTime(_startDate.year, _startDate.month, _startDate.day);
    final end = DateTime(_endDate.year, _endDate.month, _endDate.day);
    final diff = end.difference(start).inDays + 1;
    setState(() {
      _totalDays = diff.toDouble();
    });
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final user = authState.user;
    if (user == null) {
      return const Scaffold(body: Center(child: Text('Not Authenticated')));
    }

    return ResponsiveScaffold(
      appBar: AppBar(
        title: const Text('Apply For Leave'),
        elevation: 0,
        backgroundColor: theme.colorScheme.surface,
        iconTheme: IconThemeData(color: theme.colorScheme.onSurface),
      ),
      body: _submitting
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
                            'Submit a request for leaves, sick plans, or work from home programs.',
                            style: theme.textTheme.titleMedium?.copyWith(color: Colors.grey.shade600),
                          ),
                          const SizedBox(height: AppSizes.p24),

                          // Leave Type
                          _buildLabel('Leave Type *'),
                          DropdownButtonFormField<String>(
                            value: _selectedType,
                            decoration: InputDecoration(
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(AppSizes.inputRadius),
                              ),
                              contentPadding: const EdgeInsets.symmetric(horizontal: 12),
                            ),
                            items: kLeaveTypes.map((type) {
                              return DropdownMenuItem(value: type, child: Text(type));
                            }).toList(),
                            onChanged: (val) {
                              if (val != null) {
                                setState(() {
                                  _selectedType = val;
                                  if (_selectedType == 'Half Day') {
                                    _endDate = _startDate;
                                  }
                                  _calculateTotalDays();
                                });
                              }
                            },
                          ),
                          const SizedBox(height: AppSizes.p16),

                          // Date Selectors
                          ResponsiveFormRow(
                            children: [
                              // Start Date
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  _buildLabel('Start Date *'),
                                  SizedBox(
                                    width: double.infinity,
                                    child: OutlinedButton.icon(
                                      onPressed: () => _pickStartDate(context),
                                      icon: const Icon(Icons.calendar_today),
                                      label: Text(
                                        '${_startDate.year}-${_startDate.month.toString().padLeft(2, '0')}-${_startDate.day.toString().padLeft(2, '0')}',
                                      ),
                                      style: OutlinedButton.styleFrom(
                                        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
                                        alignment: Alignment.centerLeft,
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(AppSizes.buttonRadius),
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),

                              // End Date (disable if half day)
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  _buildLabel('End Date *'),
                                  SizedBox(
                                    width: double.infinity,
                                    child: OutlinedButton.icon(
                                      onPressed: _selectedType == 'Half Day' ? null : () => _pickEndDate(context),
                                      icon: const Icon(Icons.calendar_month_rounded),
                                      label: Text(
                                        '${_endDate.year}-${_endDate.month.toString().padLeft(2, '0')}-${_endDate.day.toString().padLeft(2, '0')}',
                                      ),
                                      style: OutlinedButton.styleFrom(
                                        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
                                        alignment: Alignment.centerLeft,
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(AppSizes.buttonRadius),
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                          const SizedBox(height: AppSizes.p16),

                          // Total Days Calculated
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: theme.colorScheme.primary.withAlpha(15),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.info_outline_rounded, size: 18, color: AppColors.info),
                                const SizedBox(width: 8),
                                Text(
                                  'Total Request Days: ',
                                  style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.bold),
                                ),
                                Text(
                                  '$_totalDays Days',
                                  style: theme.textTheme.bodyMedium?.copyWith(
                                    fontWeight: FontWeight.bold,
                                    color: theme.colorScheme.primary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: AppSizes.p16),

                          // Reason Input
                          _buildLabel('Reason for Leave *'),
                          TextFormField(
                            controller: _reasonController,
                            maxLines: 3,
                            decoration: InputDecoration(
                              hintText: 'Enter reason description details...',
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(AppSizes.inputRadius),
                              ),
                            ),
                            validator: (val) {
                              if (val == null || val.trim().isEmpty) {
                                return 'Reason is required';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: AppSizes.p24),

                          // Supporting Document File Uploader
                          _buildLabel('Supporting Document (Optional)'),
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: isDark ? Colors.white.withAlpha(5) : Colors.grey.shade50,
                              borderRadius: BorderRadius.circular(AppSizes.cardRadius),
                              border: Border.all(color: Colors.grey.shade300),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.picture_as_pdf_rounded, color: AppColors.error, size: 36),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        _uploadedDocumentName ?? 'No Document Attached',
                                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        _uploadedDocumentUrl != null
                                            ? 'Attachment successfully uploaded'
                                            : 'Upload certificate/slip slips to justify leave request',
                                        style: TextStyle(color: Colors.grey.shade600, fontSize: 11),
                                      ),
                                    ],
                                  ),
                                ),
                                if (_uploadingFile)
                                  const CircularProgressIndicator()
                                else if (_uploadedDocumentUrl != null)
                                  IconButton(
                                    icon: const Icon(Icons.delete_forever_rounded, color: AppColors.error),
                                    onPressed: () {
                                      setState(() {
                                        _uploadedDocumentUrl = null;
                                        _uploadedDocumentName = null;
                                      });
                                    },
                                  )
                                else
                                  ElevatedButton.icon(
                                    onPressed: () => _simulateFileUpload(user.companyId, user.employeeId),
                                    icon: const Icon(Icons.upload_file_rounded),
                                    label: const Text('Attach File'),
                                    style: ElevatedButton.styleFrom(
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                          const SizedBox(height: AppSizes.p32),

                          // Submit Button
                          SizedBox(
                            width: double.infinity,
                            height: 52,
                            child: ElevatedButton(
                              onPressed: () => _submitForm(user),
                              style: ElevatedButton.styleFrom(
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(AppSizes.buttonRadius),
                                ),
                              ),
                              child: const Text(
                                'Dispatch Leave Request',
                                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
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

  Widget _buildLabel(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6, left: 4),
      child: Text(
        text,
        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
      ),
    );
  }

  void _pickStartDate(BuildContext context) async {
    final date = await showDatePicker(
      context: context,
      initialDate: _startDate,
      firstDate: DateTime.now().subtract(const Duration(days: 30)),
      lastDate: DateTime(2030),
    );
    if (date != null) {
      setState(() {
        _startDate = date;
        if (_selectedType == 'Half Day') {
          _endDate = _startDate;
        } else if (_endDate.isBefore(_startDate)) {
          _endDate = _startDate;
        }
        _calculateTotalDays();
      });
    }
  }

  void _pickEndDate(BuildContext context) async {
    final date = await showDatePicker(
      context: context,
      initialDate: _endDate,
      firstDate: _startDate,
      lastDate: DateTime(2030),
    );
    if (date != null) {
      setState(() {
        _endDate = date;
        _calculateTotalDays();
      });
    }
  }

  void _simulateFileUpload(String companyId, String employeeId) async {
    setState(() => _uploadingFile = true);
    try {
      final storage = ref.read(storageServiceProvider);
      
      // Simulate file picker content (dummy bytes representing a medical note or support statement)
      final dummyBytes = Uint8List.fromList([77, 101, 100, 105, 99, 97, 108, 32, 78, 111, 116, 101]);
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final fileName = 'cert_${employeeId}_$timestamp.pdf';
      final path = 'companies/$companyId/leaves/$fileName';

      final downloadUrl = await storage.uploadBytes(
        path: path,
        bytes: dummyBytes,
        contentType: 'application/pdf',
      );

      setState(() {
        _uploadedDocumentUrl = downloadUrl;
        _uploadedDocumentName = fileName;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Document attachment successfully uploaded!')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Upload failed: $e')),
      );
    } finally {
      setState(() => _uploadingFile = false);
    }
  }

  void _submitForm(dynamic user) async {
    if (!_formKey.currentState!.validate()) return;

    // Business Rule 1: End Date before Start Date checking
    if (_endDate.isBefore(_startDate) && _selectedType != 'Half Day') {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('End Date cannot be before Start Date.')),
      );
      return;
    }

    setState(() => _submitting = true);

    try {
      final companyId = user.companyId;
      final existingLeaves = ref.read(companyLeavesStreamProvider).value ?? [];

      // Business Rule 2: Overlapping leave request check
      final hasOverlap = existingLeaves.any((leave) {
        if (leave.employeeId != user.employeeId) return false;
        if (leave.status == 'Cancelled' || leave.status == 'Rejected') return false;

        final leaveStart = DateTime(leave.startDate.year, leave.startDate.month, leave.startDate.day);
        final leaveEnd = DateTime(leave.endDate.year, leave.endDate.month, leave.endDate.day);
        final curStart = DateTime(_startDate.year, _startDate.month, _startDate.day);
        final curEnd = DateTime(_endDate.year, _endDate.month, _endDate.day);

        return !curStart.isAfter(leaveEnd) && !curEnd.isBefore(leaveStart);
      });

      if (hasOverlap) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Overlap Error: You already have a pending/approved leave request overlapping these dates.'),
          ),
        );
        setState(() => _submitting = false);
        return;
      }

      final leaveId = FirebaseFirestore.instance.collection('companies').doc(companyId).collection('leaves').doc().id;

      final leave = LeaveModel(
        leaveId: leaveId,
        companyId: companyId,
        employeeId: user.employeeId,
        uid: user.uid,
        employeeName: user.name ?? 'Employee',
        department: user.department,
        leaveType: _selectedType,
        reason: _reasonController.text.trim(),
        startDate: _startDate,
        endDate: _endDate,
        totalDays: _totalDays,
        status: 'Pending',
        appliedAt: DateTime.now(),
        updatedAt: DateTime.now(),
        supportingDocumentUrl: _uploadedDocumentUrl,
      );

      await ref.read(leaveRepositoryProvider).createLeave(companyId, leave);
      LeaveNotificationService.notifyLeaveApplied(ref, leave);

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Leave request dispatched successfully!')),
      );

      context.pop();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to submit leave request: $e')),
      );
    } finally {
      setState(() => _submitting = false);
    }
  }
}
