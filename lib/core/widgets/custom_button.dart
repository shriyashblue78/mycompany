import 'package:flutter/material.dart';
import '../constants/app_colors.dart';
import '../constants/app_sizes.dart';

class CustomButton extends StatelessWidget {
  final String text;
  final VoidCallback? onPressed;
  final bool isLoading;
  final bool isFullWidth;
  final IconData? icon;
  final bool isOutlined;

  const CustomButton({
    super.key,
    required this.text,
    this.onPressed,
    this.isLoading = false,
    this.isFullWidth = true,
    this.icon,
    this.isOutlined = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final isDisabled = onPressed == null || isLoading;

    final primaryColor = isDark ? AppColors.primaryDark : AppColors.primaryLight;

    Color getTextColor() {
      if (isDisabled) {
        return isDark ? Colors.grey.shade600 : Colors.grey.shade400;
      }
      return isOutlined ? primaryColor : (isDark ? Colors.black : Colors.white);
    }

    Widget buttonChild = Row(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (isLoading) ...[
          SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              valueColor: AlwaysStoppedAnimation<Color>(getTextColor()),
            ),
          ),
          const SizedBox(width: AppSizes.p12),
        ] else if (icon != null) ...[
          Icon(icon, size: 18, color: getTextColor()),
          const SizedBox(width: AppSizes.p8),
        ],
        Text(
          text,
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.bold,
            letterSpacing: 0.2,
            color: getTextColor(),
          ),
        ),
      ],
    );

    return Container(
      width: isFullWidth ? double.infinity : null,
      height: 48,
      decoration: BoxDecoration(
        color: isOutlined
            ? Colors.transparent
            : (isDisabled
                ? (isDark ? Colors.grey.shade800 : Colors.grey.shade200)
                : primaryColor),
        borderRadius: BorderRadius.circular(AppSizes.buttonRadius),
        border: isOutlined
            ? Border.all(
                color: isDisabled
                    ? (isDark ? Colors.grey.shade800 : Colors.grey.shade300)
                    : primaryColor,
                width: 1.5,
              )
            : null,
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: isDisabled ? null : onPressed,
          borderRadius: BorderRadius.circular(AppSizes.buttonRadius),
          child: Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSizes.p24),
              child: buttonChild,
            ),
          ),
        ),
      ),
    );
  }
}
