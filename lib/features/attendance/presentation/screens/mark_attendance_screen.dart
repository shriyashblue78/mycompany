import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_sizes.dart';
import '../../../../core/widgets/custom_text_field.dart';
import '../../../../core/widgets/custom_button.dart';
import '../../../../core/widgets/responsive_widgets.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../domain/models/attendance_model.dart';
import '../providers/attendance_provider.dart';

class MarkAttendanceScreen extends ConsumerStatefulWidget {
  const MarkAttendanceScreen({super.key});

  @override
  ConsumerState<MarkAttendanceScreen> createState() => _MarkAttendanceScreenState();
}

class _MarkAttendanceScreenState extends ConsumerState<MarkAttendanceScreen> {
  final TextEditingController _remarksController = TextEditingController();
  late Timer _clockTimer;
  DateTime _currentTime = DateTime.now();
  bool _isActionLoading = false;

  @override
  void initState() {
    super.initState();
    _clockTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) {
        setState(() {
          _currentTime = DateTime.now();
        });
      }
    });
  }

  @override
  void dispose() {
    _clockTimer.cancel();
    _remarksController.dispose();
    super.dispose();
  }

  Future<void> _handlePunch(bool isCheckedIn, String? checkInTimeStr) async {
    setState(() {
      _isActionLoading = true;
    });

    try {
      final authState = ref.read(authProvider);
      final companyId = authState.user?.companyId;
      final employeeId = authState.user?.employeeId;
      final uid = authState.user?.uid;

      if (companyId == null || employeeId == null || uid == null) {
        throw Exception('User authentication data missing.');
      }

      final todayStr = ref.read(todayDateStringProvider);

      if (!isCheckedIn) {
        // --- CHECK IN ---
        final checkInLimit = DateTime(_currentTime.year, _currentTime.month, _currentTime.day, 9, 15);
        final status = _currentTime.isAfter(checkInLimit) ? 'Late' : 'Present';

        final existing = ref.read(todayAttendanceStreamProvider).value;
        if (existing != null) {
          throw Exception('Already checked in for today.');
        }

        final recordToSave = AttendanceModel(
          attendanceId: '${employeeId}_$todayStr',
          companyId: companyId,
          employeeId: employeeId,
          uid: uid,
          date: DateTime(_currentTime.year, _currentTime.month, _currentTime.day),
          checkInTime: _currentTime,
          workingHours: 0.0,
          status: status,
          remarks: _remarksController.text.trim().isNotEmpty ? _remarksController.text.trim() : null,
          createdAt: _currentTime,
          updatedAt: _currentTime,
        );

        await ref.read(attendanceRepositoryProvider).checkIn(companyId, recordToSave);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Successfully Checked In!'), backgroundColor: AppColors.success),
          );
        }
      } else {
        // --- CHECK OUT ---
        final todayRecord = ref.read(todayAttendanceStreamProvider).value;
        if (todayRecord == null) {
          throw Exception('No Check-In record found. Please check in first.');
        }

        final checkInTime = todayRecord.checkInTime;
        if (checkInTime == null) {
          throw Exception('No Check-In time recorded.');
        }

        if (_currentTime.isBefore(checkInTime)) {
          throw Exception('Check-Out time cannot be before Check-In time.');
        }

        final diff = _currentTime.difference(checkInTime);
        final workingHours = diff.inSeconds / 3600.0;

        String finalStatus = todayRecord.status;
        if (workingHours < 4.0) {
          finalStatus = 'Half Day';
        }

        await ref.read(attendanceRepositoryProvider).checkOut(
          companyId: companyId,
          attendanceId: todayRecord.attendanceId,
          checkOutTime: _currentTime,
          workingHours: workingHours,
          status: finalStatus,
          remarks: _remarksController.text.trim().isNotEmpty ? _remarksController.text.trim() : todayRecord.remarks,
        );

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Successfully Checked Out!'), backgroundColor: AppColors.success),
          );
        }
      }

      if (mounted) {
        _remarksController.clear();
        context.pop(); // Return to dashboard
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Operation Failed: $e'), backgroundColor: AppColors.error),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isActionLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final todayAttendanceAsync = ref.watch(todayAttendanceStreamProvider);

    return ResponsiveScaffold(
      appBar: AppBar(
        title: const Text('Mark Attendance'),
        elevation: 0,
      ),
      body: todayAttendanceAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) => Center(child: Text('Error: $err', style: const TextStyle(color: AppColors.error))),
        data: (attendance) {
          final bool isCheckedIn = attendance != null;
          final bool isCheckedOut = attendance?.checkOutTime != null;
          
          final checkIn = attendance?.checkInTime;
          final checkOut = attendance?.checkOutTime;
          final workingHours = attendance?.workingHours ?? 0.0;
          final status = attendance?.status ?? '';

          final String? checkInTimeStr = checkIn != null 
              ? DateFormat('hh:mm a').format(checkIn) 
              : null;

          return SingleChildScrollView(
            padding: const EdgeInsets.all(AppSizes.p24),
            child: Center(
              child: Container(
                constraints: const BoxConstraints(maxWidth: 500),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    // Date header card
                    Text(
                      DateFormat('EEEE, d MMMM yyyy').format(_currentTime),
                      style: theme.textTheme.titleMedium?.copyWith(
                        color: Colors.grey.shade600,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: AppSizes.p8),

                    // Running Clock display
                    Text(
                      DateFormat('hh:mm:ss a').format(_currentTime),
                      style: theme.textTheme.headlineLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                        fontSize: 48,
                        color: theme.colorScheme.primary,
                      ),
                    ),
                    const SizedBox(height: AppSizes.p32),

                    // Status Information Box
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(AppSizes.p20),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.primary.withAlpha(20),
                        borderRadius: BorderRadius.circular(AppSizes.cardRadius),
                        border: Border.all(color: theme.colorScheme.primary.withAlpha(51)),
                      ),
                      child: Column(
                        children: [
                          Icon(
                            isCheckedOut 
                                ? Icons.offline_pin_rounded 
                                : (isCheckedIn ? Icons.login_rounded : Icons.logout_rounded),
                            size: 48,
                            color: theme.colorScheme.primary,
                          ),
                          const SizedBox(height: AppSizes.p12),
                          Text(
                            isCheckedOut 
                                ? 'Attendance Completed' 
                                : (isCheckedIn ? 'You are currently Checked In' : 'Ready to Punch In'),
                            style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                          ),
                          if (isCheckedIn) ...[
                            const SizedBox(height: 8),
                            Text(
                              'Checked In at: $checkInTimeStr',
                              style: theme.textTheme.bodyMedium?.copyWith(color: Colors.grey.shade700),
                            ),
                          ],
                          if (isCheckedOut) ...[
                            const SizedBox(height: 8),
                            Text(
                              'Checked Out at: ${checkOut != null ? DateFormat('hh:mm a').format(checkOut) : ''}\nWorking Hours: ${workingHours.toStringAsFixed(2)} hrs\nStatus: $status',
                              textAlign: TextAlign.center,
                              style: theme.textTheme.bodyMedium?.copyWith(color: Colors.grey.shade700),
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(height: AppSizes.p32),

                    if (!isCheckedOut) ...[
                      // Remarks Text Field
                      CustomTextField(
                        controller: _remarksController,
                        hintText: 'Enter any remarks (optional)',
                        labelText: 'Remarks / Notes',
                        prefixIcon: Icons.notes_rounded,
                      ),
                      const SizedBox(height: AppSizes.p24),

                      // Punch Button
                      CustomButton(
                        text: isCheckedIn ? 'CHECK OUT' : 'CHECK IN',
                        isLoading: _isActionLoading,
                        onPressed: _isActionLoading 
                            ? null 
                            : () => _handlePunch(isCheckedIn, checkInTimeStr),
                        icon: Icons.fingerprint,
                      ),
                    ] else ...[
                      const Icon(Icons.check_circle_outline_rounded, color: AppColors.success, size: 64),
                      const SizedBox(height: AppSizes.p16),
                      Text(
                        'Your timesheet is locked for today.',
                        style: theme.textTheme.titleMedium?.copyWith(color: Colors.grey.shade600),
                      ),
                      const SizedBox(height: AppSizes.p24),
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          minimumSize: const Size(double.infinity, 48),
                        ),
                        onPressed: () => context.pop(),
                        child: const Text('Back to Dashboard'),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
