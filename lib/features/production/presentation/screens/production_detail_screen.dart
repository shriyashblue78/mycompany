import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_sizes.dart';
import '../../../../core/widgets/responsive_widgets.dart';
import '../../../../core/widgets/polish_widgets.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../employee/domain/models/employee_model.dart';
import '../../domain/models/production_model.dart';
import '../providers/production_provider.dart';
import '../../../notifications/presentation/providers/notifications_provider.dart';

class ProductionDetailScreen extends ConsumerStatefulWidget {
  final String productionId;
  const ProductionDetailScreen({super.key, required this.productionId});

  @override
  ConsumerState<ProductionDetailScreen> createState() => _ProductionDetailScreenState();
}

class _ProductionDetailScreenState extends ConsumerState<ProductionDetailScreen> {
  final _rejectionReasonController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  
  bool _submittingAction = false;
  bool _showRejectionInput = false;

  @override
  void dispose() {
    _rejectionReasonController.dispose();
    super.dispose();
  }

  Future<void> _openFileUrl(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      if (mounted) {
        showFeedbackSnackBar(
          context: context,
          message: 'Could not open blueprint link.',
          isError: true,
        );
      }
    }
  }

  void _acceptAssignment(ProductionModel prod, String companyId, String userUid, String userName) async {
    setState(() => _submittingAction = true);
    try {
      final repo = ref.read(productionRepositoryProvider);
      final updated = prod.copyWith(
        status: 'In Progress',
        updatedAt: DateTime.now(),
      );
      await repo.updateProduction(companyId, updated);

      // Trigger notification
      await ref.read(notificationServiceProvider).notifyProductionAddedUpdatedCompleted(
        companyId: companyId,
        productionId: prod.productionId,
        productName: prod.productName,
        quantity: prod.quantity.toDouble(),
        status: 'In Progress',
        userUid: userUid,
        userName: userName,
        isEdit: true,
      );

      if (mounted) {
        showFeedbackSnackBar(
          context: context,
          message: 'Production assignment accepted and marked In Progress!',
        );
      }
    } catch (e) {
      if (mounted) {
        showFeedbackSnackBar(
          context: context,
          message: 'Failed to accept assignment: $e',
          isError: true,
        );
      }
    } finally {
      if (mounted) {
        setState(() => _submittingAction = false);
      }
    }
  }

  void _submitRejection(ProductionModel prod, String companyId, String userUid, String userName) async {
    final reason = _rejectionReasonController.text.trim();
    if (reason.isEmpty) {
      showFeedbackSnackBar(
        context: context,
        message: 'Rejection reason is required.',
        isError: true,
      );
      return;
    }

    setState(() => _submittingAction = true);
    try {
      final repo = ref.read(productionRepositoryProvider);
      final newRemarks = prod.remarks.isNotEmpty 
          ? '${prod.remarks}\n\n[Assignment Rejected by Employee: $reason]' 
          : 'Assignment Rejected by Employee: $reason';
      
      final updated = prod.copyWith(
        status: 'Cancelled', // Rejection cancels/rejects the pending state
        remarks: newRemarks,
        updatedAt: DateTime.now(),
      );
      await repo.updateProduction(companyId, updated);

      // Trigger rejection notification to managers
      await ref.read(notificationServiceProvider).notifyProductionRejection(
        companyId: companyId,
        productionId: prod.productionId,
        productName: prod.productName,
        employeeName: userName,
        reason: reason,
        userUid: userUid,
      );

      if (mounted) {
        showFeedbackSnackBar(
          context: context,
          message: 'Production assignment rejected and managers notified.',
        );
        context.pop();
      }
    } catch (e) {
      if (mounted) {
        showFeedbackSnackBar(
          context: context,
          message: 'Failed to submit rejection: $e',
          isError: true,
        );
      }
    } finally {
      if (mounted) {
        setState(() => _submittingAction = false);
      }
    }
  }

  void _showCompletionDialog(ProductionModel prod, String companyId, String userUid, String userName) {
    final goodController = TextEditingController(text: prod.quantity.toString());
    final rejectController = TextEditingController(text: '0');
    final dialogFormKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        return AlertDialog(
          title: const Text('Report Work Completion'),
          content: Form(
            key: dialogFormKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: goodController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Completed Good Quantity *',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.check_circle_rounded, color: Colors.green),
                  ),
                  validator: (val) {
                    if (val == null || val.trim().isEmpty) return 'Required';
                    final parsed = int.tryParse(val);
                    if (parsed == null || parsed < 0) return 'Must be >= 0';
                    return null;
                  },
                ),
                const SizedBox(height: AppSizes.p16),
                TextFormField(
                  controller: rejectController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Rejected Quantity *',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.cancel_rounded, color: Colors.red),
                  ),
                  validator: (val) {
                    if (val == null || val.trim().isEmpty) return 'Required';
                    final parsed = int.tryParse(val);
                    if (parsed == null || parsed < 0) return 'Must be >= 0';
                    return null;
                  },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
              onPressed: () async {
                if (!dialogFormKey.currentState!.validate()) return;
                
                final good = int.parse(goodController.text);
                final rejected = int.parse(rejectController.text);
                
                Navigator.pop(ctx);
                setState(() => _submittingAction = true);
                
                try {
                  final repo = ref.read(productionRepositoryProvider);
                  final updated = prod.copyWith(
                    status: 'Completed',
                    completedQuantity: good,
                    rejectedQuantity: rejected,
                    updatedAt: DateTime.now(),
                  );
                  await repo.updateProduction(companyId, updated);

                  // Trigger completed notification
                  await ref.read(notificationServiceProvider).notifyProductionAddedUpdatedCompleted(
                    companyId: companyId,
                    productionId: prod.productionId,
                    productName: prod.productName,
                    quantity: good.toDouble(),
                    status: 'Completed',
                    userUid: userUid,
                    userName: userName,
                    isEdit: true,
                  );

                  if (mounted) {
                    showFeedbackSnackBar(
                      context: context,
                      message: 'Production completed successfully!',
                    );
                  }
                } catch (e) {
                  if (mounted) {
                    showFeedbackSnackBar(
                      context: context,
                      message: 'Failed to complete production: $e',
                      isError: true,
                    );
                  }
                } finally {
                  if (mounted) {
                    setState(() => _submittingAction = false);
                  }
                }
              },
              child: const Text('Submit Completion', style: TextStyle(color: Colors.white)),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    
    final authState = ref.watch(authProvider);
    final user = authState.user;
    final companyId = user?.companyId;
    final role = authState.selectedRole ?? 'Employee';
    final isOwnerOrSupervisor = role == 'Owner' || role == 'Supervisor';

    final productionAsync = ref.watch(productionDetailsStreamProvider(widget.productionId));
    final employeesAsync = ref.watch(productionEmployeesProvider);

    return ResponsiveScaffold(
      appBar: AppBar(
        title: const Text('Production Details'),
        elevation: 0,
        backgroundColor: theme.colorScheme.surface,
        iconTheme: IconThemeData(color: theme.colorScheme.onSurface),
        actions: [
          if (isOwnerOrSupervisor)
            IconButton(
              icon: const Icon(Icons.edit_rounded),
              tooltip: 'Edit Production',
              onPressed: () => context.push('/production/${widget.productionId}/edit'),
            ),
        ],
      ),
      body: productionAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, stack) => Center(child: Text('Error loading details: $err')),
        data: (prod) {
          if (prod == null) {
            return const Center(child: Text('Production log not found.'));
          }

          return employeesAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (err, stack) => Center(child: Text('Error loading directory: $err')),
            data: (employees) {
              // Lookup supervisor name
              final supervisor = employees.firstWhere(
                (e) => e.employeeId == prod.assignedSupervisor,
                orElse: () => EmployeeModel(
                  employeeId: prod.assignedSupervisor,
                  uid: '',
                  companyId: '',
                  name: prod.assignedSupervisor.isNotEmpty ? prod.assignedSupervisor : 'Unassigned',
                  email: '',
                  phone: '',
                  role: '',
                  department: '',
                  designation: '',
                  status: '',
                  joiningDate: DateTime.now(),
                  createdAt: DateTime.now(),
                  updatedAt: DateTime.now(),
                ),
              );

              // Get names of assigned staff members
              final assignedStaff = employees
                  .where((e) => prod.assignedEmployees.contains(e.employeeId))
                  .map((e) => e.name)
                  .toList();
              final assignedNames = assignedStaff.isNotEmpty ? assignedStaff.join(', ') : 'Unassigned';

              // Security check: is the current user assigned to this job?
              final isAssignedEmployee = user != null && prod.assignedEmployees.contains(user.employeeId);

              // Status Styling
              Color statusColor;
              switch (prod.status) {
                case 'Completed':
                  statusColor = Colors.green;
                  break;
                case 'In Progress':
                  statusColor = Colors.orange;
                  break;
                case 'Cancelled':
                  statusColor = Colors.red;
                  break;
                default:
                  statusColor = Colors.blueGrey;
              }

              return SafeArea(
                child: Center(
                  child: Container(
                    constraints: const BoxConstraints(maxWidth: 800),
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.all(AppSizes.p24),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Header Section
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(
                                child: Text(
                                  prod.productName,
                                  style: theme.textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.bold),
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                decoration: BoxDecoration(
                                  color: statusColor.withAlpha(26),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: statusColor.withAlpha(128)),
                                ),
                                child: Text(
                                  prod.status,
                                  style: TextStyle(
                                    color: statusColor,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 13,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: AppSizes.p24),

                          // Summary Details Grid
                          Card(
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                              side: BorderSide(color: theme.dividerColor.withAlpha(50)),
                            ),
                            child: Padding(
                              padding: const EdgeInsets.all(AppSizes.p20),
                              child: Column(
                                children: [
                                  _buildInfoRow('Production Date', DateFormat('dd MMMM yyyy').format(prod.productionDate), theme),
                                  const Divider(),
                                  _buildInfoRow('Supervisor', supervisor.name, theme),
                                  const Divider(),
                                  _buildInfoRow('Target Quantity', '${prod.quantity} units', theme, isValueBold: true),
                                  const Divider(),
                                  _buildInfoRow('Assigned Staff', assignedNames, theme),
                                  const Divider(),
                                  _buildInfoRow('Completed / Good Qty', '${prod.completedQuantity} units', theme, valueColor: Colors.green),
                                  const Divider(),
                                  _buildInfoRow('Rejected Defective Qty', '${prod.rejectedQuantity} units', theme, valueColor: Colors.red),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: AppSizes.p24),

                          // Tooling Section
                          Text('Required Tooling', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                          const SizedBox(height: AppSizes.p8),
                          if (prod.selectedToolNames == null || prod.selectedToolNames!.isEmpty)
                            const Text('No tooling specified for this production run.', style: TextStyle(color: Colors.grey))
                          else
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: prod.selectedToolNames!.map((tool) {
                                return Chip(
                                  label: Text(tool),
                                  backgroundColor: theme.colorScheme.primaryContainer.withAlpha(100),
                                  side: BorderSide.none,
                                  avatar: const Icon(Icons.handyman_outlined, size: 14),
                                );
                              }).toList(),
                            ),
                          const SizedBox(height: AppSizes.p24),

                          // Drawings Section
                          Text('Blueprints & Technical Documents', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                          const SizedBox(height: AppSizes.p8),
                          if (prod.drawingUrl == null || prod.drawingUrl!.isEmpty)
                            const Text('No technical drawing uploaded.', style: TextStyle(color: Colors.grey))
                          else ...[
                            Card(
                              elevation: 0,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                                side: BorderSide(color: theme.dividerColor.withAlpha(50)),
                              ),
                              child: Padding(
                                padding: const EdgeInsets.all(AppSizes.p16),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        const Icon(Icons.insert_drive_file_rounded, color: Colors.blue, size: 28),
                                        const SizedBox(width: AppSizes.p12),
                                        Expanded(
                                          child: Text(
                                            prod.drawingFileName ?? 'Drawing Blueprint',
                                            style: const TextStyle(fontWeight: FontWeight.bold),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                        ElevatedButton.icon(
                                          onPressed: () => _openFileUrl(prod.drawingUrl!),
                                          icon: const Icon(Icons.open_in_new_rounded, size: 16, color: Colors.white),
                                          label: const Text('Open Document', style: TextStyle(color: Colors.white)),
                                          style: ElevatedButton.styleFrom(backgroundColor: theme.colorScheme.primary),
                                        ),
                                      ],
                                    ),
                                    // Inline Image Preview if file is likely an image
                                    if (prod.drawingFileName != null &&
                                        !prod.drawingFileName!.toLowerCase().endsWith('.pdf')) ...[
                                      const SizedBox(height: AppSizes.p16),
                                      ClipRRect(
                                        borderRadius: BorderRadius.circular(8),
                                        child: Image.network(
                                          prod.drawingUrl!,
                                          height: 300,
                                          width: double.infinity,
                                          fit: BoxFit.contain,
                                          errorBuilder: (context, error, stack) => const Text('Failed to load drawing preview.'),
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                            ),
                          ],
                          const SizedBox(height: AppSizes.p24),

                          // Instructions / Remarks Section
                          Text('Instructions / Remarks', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                          const SizedBox(height: AppSizes.p8),
                          Card(
                            elevation: 0,
                            color: isDark ? Colors.grey[900] : Colors.grey[100],
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                              side: BorderSide(color: theme.dividerColor.withAlpha(20)),
                            ),
                            child: Padding(
                              padding: const EdgeInsets.all(AppSizes.p16),
                              child: SizedBox(
                                width: double.infinity,
                                child: Text(
                                  prod.remarks.isNotEmpty ? prod.remarks : 'No special guidelines provided.',
                                  style: const TextStyle(height: 1.4),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: AppSizes.p32),

                          // Employee Interactive Workflow Panel
                          // Only visible if current user is an assigned employee and NOT an Owner/Supervisor
                          if (isAssignedEmployee && !isOwnerOrSupervisor) ...[
                            const Divider(height: 32),
                            if (_submittingAction)
                              const Center(child: CircularProgressIndicator())
                            else if (prod.status == 'Pending') ...[
                              if (!_showRejectionInput) ...[
                                const Text(
                                  'Production Assignment Actions',
                                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                                ),
                                const SizedBox(height: AppSizes.p12),
                                Row(
                                  children: [
                                    Expanded(
                                      child: OutlinedButton.icon(
                                        onPressed: () => setState(() => _showRejectionInput = true),
                                        style: OutlinedButton.styleFrom(
                                          side: const BorderSide(color: Colors.red),
                                          padding: const EdgeInsets.symmetric(vertical: AppSizes.p16),
                                        ),
                                        icon: const Icon(Icons.cancel_rounded, color: Colors.red),
                                        label: const Text('REJECT', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
                                      ),
                                    ),
                                    const SizedBox(width: AppSizes.p16),
                                    Expanded(
                                      child: ElevatedButton.icon(
                                        onPressed: () => _acceptAssignment(
                                          prod,
                                          companyId ?? '',
                                          user?.uid ?? '',
                                          user?.name ?? 'Employee',
                                        ),
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: theme.colorScheme.primary,
                                          padding: const EdgeInsets.symmetric(vertical: AppSizes.p16),
                                        ),
                                        icon: const Icon(Icons.check_circle_rounded, color: Colors.white),
                                        label: const Text('ACCEPT & START', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                                      ),
                                    ),
                                  ],
                                ),
                              ] else ...[
                                const Text(
                                  'Explain Rejection Reason',
                                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Colors.red),
                                ),
                                const SizedBox(height: AppSizes.p8),
                                TextFormField(
                                  controller: _rejectionReasonController,
                                  maxLines: 3,
                                  decoration: const InputDecoration(
                                    labelText: 'Rejection Reason *',
                                    hintText: 'Describe why this production assignment cannot be accepted...',
                                    border: OutlineInputBorder(),
                                    focusedBorder: OutlineInputBorder(borderSide: BorderSide(color: Colors.red)),
                                  ),
                                ),
                                const SizedBox(height: AppSizes.p12),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.end,
                                  children: [
                                    TextButton(
                                      onPressed: () => setState(() {
                                        _showRejectionInput = false;
                                        _rejectionReasonController.clear();
                                      }),
                                      child: const Text('Cancel'),
                                    ),
                                    const SizedBox(width: AppSizes.p12),
                                    ElevatedButton(
                                      style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                                      onPressed: () => _submitRejection(
                                        prod,
                                        companyId ?? '',
                                        user?.uid ?? '',
                                        user?.name ?? 'Employee',
                                      ),
                                      child: const Text('Submit Rejection', style: TextStyle(color: Colors.white)),
                                    ),
                                  ],
                                ),
                              ],
                            ] else if (prod.status == 'In Progress') ...[
                              SizedBox(
                                width: double.infinity,
                                height: 52,
                                child: ElevatedButton.icon(
                                  style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
                                  onPressed: () => _showCompletionDialog(
                                    prod,
                                    companyId ?? '',
                                    user?.uid ?? '',
                                    user?.name ?? 'Employee',
                                  ),
                                  icon: const Icon(Icons.done_all_rounded, color: Colors.white),
                                  label: const Text('WORK COMPLETED', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
                                ),
                              ),
                            ] else ...[
                              // Job is completed or cancelled/rejected, workflow ended
                              Center(
                                child: Container(
                                  padding: const EdgeInsets.symmetric(vertical: 12, horizontal: AppSizes.p16),
                                  decoration: BoxDecoration(
                                    color: theme.dividerColor.withAlpha(15),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: const Text(
                                    'This production assignment has concluded.',
                                    style: TextStyle(fontStyle: FontStyle.italic, color: Colors.grey),
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ],
                      ),
                    ),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildInfoRow(String label, String value, ThemeData theme, {bool isValueBold = false, Color? valueColor}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontSize: 13, color: Colors.grey)),
          const SizedBox(width: AppSizes.p16),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.end,
              style: TextStyle(
                fontSize: 13,
                fontWeight: isValueBold ? FontWeight.bold : FontWeight.w500,
                color: valueColor ?? theme.colorScheme.onSurface,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
