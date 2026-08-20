import 'package:flutter/material.dart';

class AppColors {
  // Light Theme Colors
  static const Color primaryLight = Color(0xFF0F5E36); // Deep Manufacturing Green
  static const Color primaryContainerLight = Color(0xFFE8F5E9); // Soft light green container
  static const Color secondaryLight = Color(0xFF16A34A); // Fresh Green
  static const Color accentLight = Color(0xFF22C55E); // Fresh Green Accent
  static const Color backgroundLight = Color(0xFFF7F8FA); // Very Light Grey background
  static const Color surfaceLight = Color(0xFFFFFFFF); // Pure white cards
  static const Color borderLight = Color(0xFFE5E7EB); // Very Light Grey border
  
  // Dark Theme Colors
  static const Color primaryDark = Color(0xFF22C55E); // Green primary
  static const Color primaryContainerDark = Color(0xFF064E3B); // Dark green container
  static const Color secondaryDark = Color(0xFF4ADE80); // Lighter fresh green
  static const Color accentDark = Color(0xFF22C55E); // Fresh green
  static const Color backgroundDark = Color(0xFF0B0F19); // Deep dark blue-grey background
  static const Color surfaceDark = Color(0xFF111827); // Dark card background
  static const Color borderDark = Color(0xFF1F2937); // Dark border

  // General Status Colors
  static const Color success = Color(0xFF10B981); // Emerald Green
  static const Color warning = Color(0xFFF59E0B); // Orange/Amber
  static const Color error = Color(0xFFEF4444); // Red/Danger
  static const Color info = Color(0xFF3B82F6); // Blue Info

  // Gradients for Premium Look (very subtle)
  static const LinearGradient primaryGradient = LinearGradient(
    colors: [Color(0xFF0F5E36), Color(0xFF117543)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient accentGradient = LinearGradient(
    colors: [Color(0xFF16A34A), Color(0xFF22C55E)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient darkCardGradient = LinearGradient(
    colors: [Color(0xFF1F2937), Color(0xFF111827)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient glassGradient = LinearGradient(
    colors: [
      Color(0x1AFFFFFF),
      Color(0x05FFFFFF),
    ],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
}
