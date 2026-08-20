import 'package:flutter/material.dart';
import '../constants/app_sizes.dart';

class ResponsiveLayout extends StatelessWidget {
  final Widget mobile;
  final Widget? tablet;
  final Widget desktop;

  const ResponsiveLayout({
    super.key,
    required this.mobile,
    this.tablet,
    required this.desktop,
  });

  static bool isMobile(BuildContext context) =>
      MediaQuery.of(context).size.width < AppSizes.maxMobileWidth;

  static bool isTablet(BuildContext context) =>
      MediaQuery.of(context).size.width >= AppSizes.maxMobileWidth &&
      MediaQuery.of(context).size.width < AppSizes.maxTabletWidth;

  static bool isDesktop(BuildContext context) =>
      MediaQuery.of(context).size.width >= AppSizes.maxTabletWidth;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth >= AppSizes.maxTabletWidth) {
          return desktop;
        } else if (constraints.maxWidth >= AppSizes.maxMobileWidth) {
          return tablet ?? desktop; // Fallback to desktop if tablet is not specified
        } else {
          return mobile;
        }
      },
    );
  }
}
