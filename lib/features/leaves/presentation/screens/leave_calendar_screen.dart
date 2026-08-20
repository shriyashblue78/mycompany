import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_sizes.dart';
import '../../../../core/widgets/responsive_layout.dart';
import '../../../../core/widgets/erp_drawer.dart';
import '../../../../core/widgets/responsive_widgets.dart';
import '../../domain/models/leave_model.dart';
import '../providers/leaves_provider.dart';

class LeaveCalendarScreen extends ConsumerStatefulWidget {
  const LeaveCalendarScreen({super.key});

  @override
  ConsumerState<LeaveCalendarScreen> createState() => _LeaveCalendarScreenState();
}

class _LeaveCalendarScreenState extends ConsumerState<LeaveCalendarScreen> {
  DateTime _focusedMonth = DateTime.now();
  DateTime _selectedDay = DateTime.now();

  static const List<String> _weekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
  static const List<String> _months = [
    'January', 'February', 'March', 'April', 'May', 'June',
    'July', 'August', 'September', 'October', 'November', 'December'
  ];

  int _getDaysInMonth(int year, int month) {
    return DateTime(year, month + 1, 0).day;
  }

  int _getFirstWeekdayOfMonth(int year, int month) {
    return DateTime(year, month, 1).weekday;
  }

  bool _isDayOnLeave(DateTime day, List<LeaveModel> leaves) {
    final target = DateTime(day.year, day.month, day.day);
    return leaves.any((leave) {
      if (leave.status != 'Approved') return false;
      final start = DateTime(leave.startDate.year, leave.startDate.month, leave.startDate.day);
      final end = DateTime(leave.endDate.year, leave.endDate.month, leave.endDate.day);
      return !target.isBefore(start) && !target.isAfter(end);
    });
  }

  List<LeaveModel> _getLeavesForDay(DateTime day, List<LeaveModel> leaves) {
    final target = DateTime(day.year, day.month, day.day);
    return leaves.where((leave) {
      if (leave.status != 'Approved') return false;
      final start = DateTime(leave.startDate.year, leave.startDate.month, leave.startDate.day);
      final end = DateTime(leave.endDate.year, leave.endDate.month, leave.endDate.day);
      return !target.isBefore(start) && !target.isAfter(end);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final leavesAsync = ref.watch(companyLeavesStreamProvider);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return ResponsiveScaffold(
      appBar: AppBar(
        title: const Text('Leave Calendar'),
        elevation: 0,
        backgroundColor: theme.colorScheme.surface,
        iconTheme: IconThemeData(color: theme.colorScheme.onSurface),
      ),
      drawer: const ERPDrawer(),
      body: leavesAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, stack) => Center(child: Text('Error loading calendar: $err')),
        data: (leaves) {
          final year = _focusedMonth.year;
          final month = _focusedMonth.month;
          final totalDays = _getDaysInMonth(year, month);
          final firstWeekday = _getFirstWeekdayOfMonth(year, month);
          final padCount = firstWeekday - 1;

          // Build grid cells
          final cellsCount = totalDays + padCount;

          final isDesktop = ResponsiveLayout.isDesktop(context);

          if (isDesktop) {
            return SafeArea(
              child: Center(
                child: Container(
                  constraints: const BoxConstraints(maxWidth: AppSizes.maxContentWidth),
                  padding: const EdgeInsets.all(AppSizes.p24),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        flex: 5,
                        child: Card(
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(AppSizes.cardRadius),
                            side: BorderSide(color: isDark ? Colors.white.withAlpha(15) : Colors.grey.shade200),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(AppSizes.p24),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                _buildCalendarHeader(theme),
                                const SizedBox(height: AppSizes.p16),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                                  children: _weekdays.map((w) {
                                    return Expanded(
                                      child: Center(
                                        child: Text(
                                          w,
                                          style: theme.textTheme.labelMedium?.copyWith(
                                            fontWeight: FontWeight.bold,
                                            color: Colors.grey.shade600,
                                          ),
                                        ),
                                      ),
                                    );
                                  }).toList(),
                                ),
                                const SizedBox(height: 8),
                                GridView.builder(
                                  shrinkWrap: true,
                                  physics: const NeverScrollableScrollPhysics(),
                                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                                    crossAxisCount: 7,
                                    mainAxisSpacing: 8,
                                    crossAxisSpacing: 8,
                                    childAspectRatio: 1.3,
                                  ),
                                  itemCount: cellsCount,
                                  itemBuilder: (context, index) {
                                    if (index < padCount) {
                                      return const SizedBox.shrink();
                                    }

                                    final dayNum = index - padCount + 1;
                                    final currentDay = DateTime(year, month, dayNum);
                                    final isSelected = _selectedDay.year == currentDay.year &&
                                        _selectedDay.month == currentDay.month &&
                                        _selectedDay.day == currentDay.day;

                                    final isToday = DateTime.now().year == currentDay.year &&
                                        DateTime.now().month == currentDay.month &&
                                        DateTime.now().day == currentDay.day;

                                    final onLeave = _isDayOnLeave(currentDay, leaves);

                                    return _buildDayCell(theme, dayNum, isSelected, isToday, onLeave, currentDay, isDark);
                                  },
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: AppSizes.p24),
                      Expanded(
                        flex: 4,
                        child: Container(
                          height: 480,
                          child: _buildDayDetailsSection(theme, leaves, isDark),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          }

          return SafeArea(
            child: Center(
              child: Container(
                constraints: const BoxConstraints(maxWidth: 800),
                padding: const EdgeInsets.all(AppSizes.p24),
                child: Column(
                  children: [
                    // Month Switcher Header
                    _buildCalendarHeader(theme),
                    const SizedBox(height: AppSizes.p16),

                    // Weekdays Row
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: _weekdays.map((w) {
                        return Expanded(
                          child: Center(
                            child: Text(
                              w,
                              style: theme.textTheme.labelMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: Colors.grey.shade600,
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 8),

                    // Days Grid
                    GridView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 7,
                        mainAxisSpacing: 8,
                        crossAxisSpacing: 8,
                        childAspectRatio: 1.1,
                      ),
                      itemCount: cellsCount,
                      itemBuilder: (context, index) {
                        if (index < padCount) {
                          return const SizedBox.shrink();
                        }

                        final dayNum = index - padCount + 1;
                        final currentDay = DateTime(year, month, dayNum);
                        final isSelected = _selectedDay.year == currentDay.year &&
                            _selectedDay.month == currentDay.month &&
                            _selectedDay.day == currentDay.day;

                        final isToday = DateTime.now().year == currentDay.year &&
                            DateTime.now().month == currentDay.month &&
                            DateTime.now().day == currentDay.day;

                        final onLeave = _isDayOnLeave(currentDay, leaves);

                        return _buildDayCell(theme, dayNum, isSelected, isToday, onLeave, currentDay, isDark);
                      },
                    ),
                    const SizedBox(height: AppSizes.p24),

                    // Selected Day Leaves details
                    Expanded(
                      child: _buildDayDetailsSection(theme, leaves, isDark),
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

  Widget _buildCalendarHeader(ThemeData theme) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        IconButton(
          icon: const Icon(Icons.chevron_left_rounded),
          onPressed: () {
            setState(() {
              _focusedMonth = DateTime(_focusedMonth.year, _focusedMonth.month - 1);
            });
          },
        ),
        Text(
          '${_months[_focusedMonth.month - 1]} ${_focusedMonth.year}',
          style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
        ),
        IconButton(
          icon: const Icon(Icons.chevron_right_rounded),
          onPressed: () {
            setState(() {
              _focusedMonth = DateTime(_focusedMonth.year, _focusedMonth.month + 1);
            });
          },
        ),
      ],
    );
  }

  Widget _buildDayCell(
    ThemeData theme,
    int dayNum,
    bool isSelected,
    bool isToday,
    bool onLeave,
    DateTime currentDay,
    bool isDark,
  ) {
    return InkWell(
      onTap: () {
        setState(() {
          _selectedDay = currentDay;
        });
      },
      borderRadius: BorderRadius.circular(8),
      child: Container(
        decoration: BoxDecoration(
          color: isSelected
              ? theme.colorScheme.primary
              : (isToday ? theme.colorScheme.primary.withAlpha(25) : Colors.transparent),
          border: Border.all(
            color: isSelected
                ? theme.colorScheme.primary
                : (isToday ? theme.colorScheme.primary.withAlpha(100) : Colors.grey.shade300),
          ),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Stack(
          alignment: Alignment.center,
          children: [
            Text(
              dayNum.toString(),
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 14,
                color: isSelected
                    ? Colors.white
                    : (isToday ? theme.colorScheme.primary : theme.colorScheme.onSurface),
              ),
            ),
            // Purple dot indicator if someone is on leave
            if (onLeave)
              Positioned(
                bottom: 4,
                child: Container(
                  width: 6,
                  height: 6,
                  decoration: BoxDecoration(
                    color: isSelected ? Colors.purpleAccent : Colors.purple,
                    shape: BoxShape.circle,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildDayDetailsSection(ThemeData theme, List<LeaveModel> leaves, bool isDark) {
    final selectedDayLeaves = _getLeavesForDay(_selectedDay, leaves);
    final dateStr = '${_selectedDay.year}-${_selectedDay.month.toString().padLeft(2, '0')}-${_selectedDay.day.toString().padLeft(2, '0')}';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? theme.colorScheme.surface : Colors.grey.shade50,
        borderRadius: BorderRadius.circular(AppSizes.cardRadius),
        border: Border.all(color: isDark ? Colors.white.withAlpha(15) : Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Leaves on: $dateStr',
                style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.purple.withAlpha(30),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  '${selectedDayLeaves.length} On Leave',
                  style: const TextStyle(color: Colors.purple, fontSize: 11, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Expanded(
            child: selectedDayLeaves.isEmpty
                ? const Center(
                    child: Text(
                      'No employees on leave on this date.',
                      style: TextStyle(color: Colors.grey, fontStyle: FontStyle.italic),
                    ),
                  )
                : ListView.builder(
                    itemCount: selectedDayLeaves.length,
                    itemBuilder: (context, index) {
                      final leave = selectedDayLeaves[index];
                      return Container(
                        margin: const EdgeInsets.symmetric(vertical: 4),
                        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                        decoration: BoxDecoration(
                          color: isDark ? theme.colorScheme.surface : Colors.white,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: isDark ? Colors.white.withAlpha(10) : Colors.grey.shade200),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  leave.employeeName,
                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  '${leave.department} • ${leave.leaveType}',
                                  style: TextStyle(color: Colors.grey.shade600, fontSize: 11),
                                ),
                              ],
                            ),
                            IconButton(
                              icon: const Icon(Icons.info_outline_rounded, size: 20),
                              onPressed: () => context.push('/leaves/${leave.leaveId}'),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
