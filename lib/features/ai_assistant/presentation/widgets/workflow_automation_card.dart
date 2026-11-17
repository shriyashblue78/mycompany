import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/constants/app_colors.dart';
import '../../domain/models/chat_message.dart';

class WorkflowAutomationCard extends StatefulWidget {
  final WorkflowActionData workflow;
  final bool isDark;
  final ValueChanged<String>? onNavigate;
  final void Function(String route, Map<String, dynamic>? extra)? onNavigateWithExtra;

  const WorkflowAutomationCard({
    super.key,
    required this.workflow,
    required this.isDark,
    this.onNavigate,
    this.onNavigateWithExtra,
  });

  @override
  State<WorkflowAutomationCard> createState() => _WorkflowAutomationCardState();
}

class _WorkflowAutomationCardState extends State<WorkflowAutomationCard> {
  final Set<int> _completedStepIndices = {};

  void _executeStep(BuildContext context, WorkflowStepData step, int index) {
    if (_completedStepIndices.contains(index)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('This step has already been reviewed or executed.')),
      );
      return;
    }

    if (step.actionType == 'prefill_form') {
      final route = step.route;
      final payload = step.payload;
      final fields = payload['fields'] as Map<String, dynamic>? ?? {};

      setState(() {
        _completedStepIndices.add(index);
      });

      if (route != null && route.startsWith('/')) {
        if (widget.onNavigateWithExtra != null) {
          widget.onNavigateWithExtra!(route, fields);
        } else if (widget.onNavigate != null) {
          widget.onNavigate!(route);
        } else {
          context.push(route, extra: fields);
        }
      }
    } else if (step.actionType == 'navigate') {
      final route = step.route;
      setState(() {
        _completedStepIndices.add(index);
      });
      if (route != null && route.startsWith('/')) {
        if (widget.onNavigate != null) {
          widget.onNavigate!(route);
        } else {
          context.push(route);
        }
      }
    } else {
      setState(() {
        _completedStepIndices.add(index);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = widget.isDark;
    final workflow = widget.workflow;

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: isDark
                      ? AppColors.primaryDark.withOpacity(0.2)
                      : AppColors.primaryLight.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  Icons.auto_mode_rounded,
                  size: 18,
                  color: isDark ? AppColors.primaryDark : AppColors.primaryLight,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      workflow.title,
                      style: TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.bold,
                        color: isDark ? Colors.white : const Color(0xFF0F172A),
                      ),
                    ),
                    if (workflow.summary.isNotEmpty)
                      Text(
                        workflow.summary,
                        style: TextStyle(
                          fontSize: 11,
                          color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          const Divider(height: 1, thickness: 1),
          const SizedBox(height: 10),

          // Steps List
          ...workflow.steps.asMap().entries.map((entry) {
            final idx = entry.key;
            final step = entry.value;
            final isDone = _completedStepIndices.contains(idx) || step.status == 'completed';
            final isFormAction = step.actionType == 'prefill_form';

            return Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF0F172A) : Colors.white,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: isDone
                      ? Colors.green.withOpacity(0.4)
                      : (isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
                ),
              ),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 12,
                    backgroundColor: isDone
                        ? Colors.green.withOpacity(0.2)
                        : (isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
                    child: Icon(
                      isDone ? Icons.check_rounded : Icons.pending_actions_rounded,
                      size: 14,
                      color: isDone
                          ? Colors.green
                          : (isDark ? Colors.white70 : const Color(0xFF475569)),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Step ${step.stepNumber}: ${step.title}',
                          style: TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w600,
                            color: isDark ? Colors.white : const Color(0xFF1E293B),
                          ),
                        ),
                        if (step.description.isNotEmpty)
                          Text(
                            step.description,
                            style: TextStyle(
                              fontSize: 11,
                              color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                            ),
                          ),
                      ],
                    ),
                  ),
                  if (isFormAction)
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: isDone ? Colors.grey : AppColors.primaryLight,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                      ),
                      onPressed: isDone ? null : () => _executeStep(context, step, idx),
                      child: Text(
                        isDone ? 'Reviewed' : 'Review & Confirm',
                        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                      ),
                    )
                  else if (step.actionType == 'navigate')
                    TextButton(
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      onPressed: () => _executeStep(context, step, idx),
                      child: const Text('Open Screen', style: TextStyle(fontSize: 11)),
                    ),
                ],
              ),
            );
          }),

          // Security & Approval Notice
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF0F172A).withOpacity(0.5) : const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Row(
              children: [
                Icon(Icons.shield_outlined, size: 13, color: isDark ? Colors.white60 : Colors.black54),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    'Explicit approval required: Primot AI will never write or change records directly.',
                    style: TextStyle(
                      fontSize: 10.5,
                      color: isDark ? Colors.white60 : Colors.black54,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

