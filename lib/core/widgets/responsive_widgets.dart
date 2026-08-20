import 'package:flutter/material.dart';
import '../constants/app_colors.dart';
import '../constants/app_sizes.dart';
import 'responsive_layout.dart';

/// Centralized responsive padding widget
class ResponsivePadding extends StatelessWidget {
  final Widget child;

  const ResponsivePadding({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    final double padding = ResponsiveLayout.isMobile(context)
        ? AppSizes.p16
        : ResponsiveLayout.isTablet(context)
            ? AppSizes.p24
            : AppSizes.p32;

    return Padding(
      padding: EdgeInsets.all(padding),
      child: child,
    );
  }
}

/// Centralized responsive margin widget
class ResponsiveMargin extends StatelessWidget {
  final Widget child;

  const ResponsiveMargin({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    final double margin = ResponsiveLayout.isMobile(context)
        ? AppSizes.p12
        : ResponsiveLayout.isTablet(context)
            ? AppSizes.p20
            : AppSizes.p28;

    return Padding(
      padding: EdgeInsets.all(margin),
      child: child,
    );
  }
}

/// Centralized responsive card widget
class ResponsiveCard extends StatelessWidget {
  final Widget child;
  final Color? color;
  final double? elevation;
  final EdgeInsetsGeometry? padding;
  final ShapeBorder? shape;

  const ResponsiveCard({
    super.key,
    required this.child,
    this.color,
    this.elevation,
    this.padding,
    this.shape,
  });

  @override
  Widget build(BuildContext context) {
    final isMobile = ResponsiveLayout.isMobile(context);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final defaultPadding = isMobile
        ? const EdgeInsets.all(AppSizes.p12)
        : const EdgeInsets.all(AppSizes.p20);

    return Card(
      color: color ?? (isDark ? theme.colorScheme.surface : Colors.white),
      elevation: elevation ?? 0,
      margin: EdgeInsets.zero,
      shape: shape ??
          RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppSizes.cardRadius),
            side: BorderSide(
              color: isDark ? AppColors.borderDark : AppColors.borderLight,
              width: 1,
            ),
          ),
      child: Padding(
        padding: padding ?? defaultPadding,
        child: child,
      ),
    );
  }
}

/// Centralized responsive grid widget
class ResponsiveGrid extends StatelessWidget {
  final List<Widget> children;
  final int mobileCrossAxisCount;
  final int tabletCrossAxisCount;
  final int desktopCrossAxisCount;
  final double spacing;
  final double? mainAxisExtent;
  final double childAspectRatio;

  const ResponsiveGrid({
    super.key,
    required this.children,
    this.mobileCrossAxisCount = 2,
    this.tabletCrossAxisCount = 3,
    this.desktopCrossAxisCount = 4,
    this.spacing = AppSizes.p16,
    this.mainAxisExtent,
    this.childAspectRatio = 1.0,
  });

  @override
  Widget build(BuildContext context) {
    final columns = ResponsiveLayout.isMobile(context)
        ? mobileCrossAxisCount
        : ResponsiveLayout.isTablet(context)
            ? tabletCrossAxisCount
            : desktopCrossAxisCount;

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: columns,
        crossAxisSpacing: spacing,
        mainAxisSpacing: spacing,
        mainAxisExtent: mainAxisExtent,
        childAspectRatio: childAspectRatio,
      ),
      itemCount: children.length,
      itemBuilder: (context, index) => children[index],
    );
  }
}

/// Centralized responsive button widget
class ResponsiveButton extends StatelessWidget {
  final String text;
  final VoidCallback? onPressed;
  final IconData? icon;
  final Color? color;
  final bool isSecondary;

  const ResponsiveButton({
    super.key,
    required this.text,
    this.onPressed,
    this.icon,
    this.color,
    this.isSecondary = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isMobile = ResponsiveLayout.isMobile(context);

    final padding = isMobile
        ? const EdgeInsets.symmetric(horizontal: AppSizes.p16, vertical: AppSizes.p12)
        : const EdgeInsets.symmetric(horizontal: AppSizes.p24, vertical: AppSizes.p16);

    final textStyle = theme.textTheme.labelLarge?.copyWith(
      fontWeight: FontWeight.bold,
      fontSize: isMobile ? 14 : 16,
    );

    final buttonStyle = ElevatedButton.styleFrom(
      backgroundColor: isSecondary
          ? Colors.transparent
          : (color ?? theme.colorScheme.primary),
      foregroundColor: isSecondary
          ? (color ?? theme.colorScheme.primary)
          : Colors.white,
      padding: padding,
      elevation: isSecondary ? 0 : 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppSizes.buttonRadius),
        side: isSecondary
            ? BorderSide(color: color ?? theme.colorScheme.primary)
            : BorderSide.none,
      ),
    );

    if (icon != null) {
      return ElevatedButton.icon(
        onPressed: onPressed,
        style: buttonStyle,
        icon: Icon(icon, size: isMobile ? 18 : 22),
        label: Text(text, style: textStyle),
      );
    }

    return ElevatedButton(
      onPressed: onPressed,
      style: buttonStyle,
      child: Text(text, style: textStyle),
    );
  }
}

/// Centralized responsive dialog size wrapper
class ResponsiveDialog extends StatelessWidget {
  final Widget child;
  final double maxTabletWidth;
  final double maxMobileWidth;

  const ResponsiveDialog({
    super.key,
    required this.child,
    this.maxTabletWidth = 550.0,
    this.maxMobileWidth = 420.0,
  });

  @override
  Widget build(BuildContext context) {
    final double width = ResponsiveLayout.isMobile(context)
        ? maxMobileWidth
        : maxTabletWidth;

    return Center(
      child: Container(
        constraints: BoxConstraints(maxWidth: width),
        child: child,
      ),
    );
  }
}

/// Centralized responsive form row
class ResponsiveFormRow extends StatelessWidget {
  final List<Widget> children;
  final double spacing;

  const ResponsiveFormRow({
    super.key,
    required this.children,
    this.spacing = AppSizes.p16,
  });

  @override
  Widget build(BuildContext context) {
    final isMobile = ResponsiveLayout.isMobile(context);

    if (isMobile) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: children
            .map((child) => Padding(
                  padding: EdgeInsets.only(bottom: spacing),
                  child: child,
                ))
            .toList(),
      );
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: children
          .map((child) => Expanded(child: child))
          .expand((widget) => [widget, SizedBox(width: spacing)])
          .toList()
        ..removeLast(),
    );
  }
}

/// Centralized responsive Scaffold with permanent drawer on Desktop
class ResponsiveScaffold extends StatelessWidget {
  final PreferredSizeWidget? appBar;
  final Widget body;
  final Widget? drawer;
  final Widget? floatingActionButton;
  final FloatingActionButtonLocation? floatingActionButtonLocation;
  final Widget? bottomNavigationBar;

  const ResponsiveScaffold({
    super.key,
    this.appBar,
    required this.body,
    this.drawer,
    this.floatingActionButton,
    this.floatingActionButtonLocation,
    this.bottomNavigationBar,
  });

  @override
  Widget build(BuildContext context) {
    final isDesktop = ResponsiveLayout.isDesktop(context);

    if (isDesktop && drawer != null) {
      return Scaffold(
        body: Row(
          children: [
            SizedBox(
              width: AppSizes.drawerWidth,
              child: drawer,
            ),
            const VerticalDivider(width: 1, thickness: 1),
            Expanded(
              child: Scaffold(
                appBar: appBar != null ? _buildDesktopAppBar(context, appBar!) : null,
                body: body,
                floatingActionButton: floatingActionButton,
                floatingActionButtonLocation: floatingActionButtonLocation,
                bottomNavigationBar: bottomNavigationBar,
              ),
            ),
          ],
        ),
      );
    }

    return Scaffold(
      appBar: appBar,
      body: body,
      drawer: drawer,
      floatingActionButton: floatingActionButton,
      floatingActionButtonLocation: floatingActionButtonLocation,
      bottomNavigationBar: bottomNavigationBar,
    );
  }

  PreferredSizeWidget _buildDesktopAppBar(BuildContext context, PreferredSizeWidget originalAppBar) {
    if (originalAppBar is AppBar) {
      return AppBar(
        title: originalAppBar.title,
        actions: originalAppBar.actions,
        elevation: originalAppBar.elevation,
        backgroundColor: originalAppBar.backgroundColor,
        foregroundColor: originalAppBar.foregroundColor,
        bottom: originalAppBar.bottom,
        automaticallyImplyLeading: false, // Hide drawer icon
      );
    }
    return originalAppBar;
  }
}
