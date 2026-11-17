import 'package:flutter/material.dart';
import '../../../../core/constants/app_colors.dart';

class AiFormPrefillBanner extends StatelessWidget {
  final Map<String, dynamic> prefilledFields;
  final List<String> missingFields;
  final bool isEdit;

  const AiFormPrefillBanner({
    super.key,
    required this.prefilledFields,
    this.missingFields = const [],
    this.isEdit = false,
  });

  @override
  Widget build(BuildContext context) {
    if (prefilledFields.isEmpty) return const SizedBox.shrink();

    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E283D) : const Color(0xFFEFF6FF),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark ? AppColors.primaryDark.withOpacity(0.5) : AppColors.primaryLight.withOpacity(0.4),
          width: 1.2,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.auto_awesome_rounded,
                size: 18,
                color: isDark ? AppColors.primaryDark : AppColors.primaryLight,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  isEdit ? 'AI-Assisted Update: Review Changes' : 'AI-Assisted Draft: Review Before Saving',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : const Color(0xFF1E3A8A),
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: isDark ? AppColors.primaryDark.withOpacity(0.25) : AppColors.primaryLight.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  'Review Only',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: isDark ? AppColors.primaryDark : AppColors.primaryLight,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Primot AI populated the fields below. Review, make any adjustments, and click Save to confirm.',
            style: TextStyle(
              fontSize: 12.5,
              height: 1.4,
              color: isDark ? Colors.white70 : const Color(0xFF3B82F6),
            ),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              ...prefilledFields.entries.map((e) {
                return Chip(
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  visualDensity: VisualDensity.compact,
                  backgroundColor: isDark ? const Color(0xFF2B3A5A) : Colors.white,
                  side: BorderSide(
                    color: isDark ? AppColors.primaryDark.withOpacity(0.3) : const Color(0xFFBFDBFE),
                  ),
                  label: Text(
                    '${e.key}: ${e.value}',
                    style: TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w500,
                      color: isDark ? Colors.white : const Color(0xFF1E40AF),
                    ),
                  ),
                );
              }),
              if (missingFields.isNotEmpty)
                ...missingFields.map((m) {
                  return Chip(
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    visualDensity: VisualDensity.compact,
                    backgroundColor: isDark ? const Color(0xFF451A1A) : const Color(0xFFFEF2F2),
                    side: BorderSide(
                      color: isDark ? AppColors.error.withOpacity(0.4) : const Color(0xFFFECACA),
                    ),
                    avatar: const Icon(Icons.info_outline_rounded, size: 14, color: AppColors.error),
                    label: Text(
                      'Missing: $m',
                      style: const TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.bold,
                        color: AppColors.error,
                      ),
                    ),
                  );
                }),
            ],
          ),
        ],
      ),
    );
  }
}

