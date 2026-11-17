import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/routing/app_router.dart';
import '../../../../core/widgets/responsive_layout.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import 'compact_ai_chat_panel.dart';

/// Wraps the ERP view hierarchy and injects a single floating AI assistant pill
/// on authenticated, tenant-active screens.
class FloatingAiAssistantWrapper extends ConsumerStatefulWidget {
  final Widget child;

  const FloatingAiAssistantWrapper({
    super.key,
    required this.child,
  });

  @override
  ConsumerState<FloatingAiAssistantWrapper> createState() => _FloatingAiAssistantWrapperState();
}

class _FloatingAiAssistantWrapperState extends ConsumerState<FloatingAiAssistantWrapper> {
  bool _isPanelOpen = false;

  bool _isRouteExcluded(String? path) {
    if (path == null) return false;
    // Exclude unauthenticated or blocking screens
    return path.startsWith('/login') ||
        path.startsWith('/splash') ||
        path.startsWith('/download-app') ||
        path.startsWith('/company-blocked') ||
        path.startsWith('/ai-chat'); // Dedicated chat screen does not need the floating button
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // Determine current route path safely
    String? currentPath;
    try {
      final router = ref.watch(routerProvider);
      currentPath = router.routeInformationProvider.value.uri.path;
    } catch (_) {
      try {
        currentPath = GoRouterState.of(context).uri.path;
      } catch (_) {
        currentPath = null;
      }
    }

    final bool isUserAuthenticated = authState.isLoggedIn &&
        authState.user != null &&
        authState.isCompanyActive &&
        !_isRouteExcluded(currentPath);

    return Stack(
      children: [
        widget.child,
        if (isUserAuthenticated) ...[
          // Floating Button (positioned bottom right, unobtrusive)
          Positioned(
            right: 20,
            bottom: 24,
            child: Material(
              color: Colors.transparent,
              elevation: 6,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
              child: InkWell(
                onTap: () {
                  if (ResponsiveLayout.isMobile(context)) {
                    // Mobile devices open full screen chat directly for better UX
                    ref.read(routerProvider).push('/ai-chat');
                  } else {
                    setState(() {
                      _isPanelOpen = !_isPanelOpen;
                    });
                  }
                },
                borderRadius: BorderRadius.circular(28),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: isDark ? AppColors.surfaceDark : Colors.white,
                    borderRadius: BorderRadius.circular(28),
                    border: Border.all(
                      color: isDark
                          ? AppColors.primaryDark.withOpacity(0.4)
                          : AppColors.primaryLight.withOpacity(0.25),
                      width: 1.5,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: (isDark ? AppColors.primaryDark : AppColors.primaryLight).withOpacity(0.18),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(5),
                        decoration: BoxDecoration(
                          color: isDark ? AppColors.primaryContainerDark : AppColors.primaryContainerLight,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.auto_awesome_rounded,
                          size: 16,
                          color: isDark ? AppColors.primaryDark : AppColors.primaryLight,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Primot AI',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: isDark ? Colors.white : const Color(0xFF1F2937),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          // Compact floating desktop/tablet panel
          if (_isPanelOpen && !ResponsiveLayout.isMobile(context))
            Positioned(
              right: 20,
              bottom: 80,
              child: CompactAiChatPanel(
                onClose: () {
                  if (mounted) {
                    setState(() => _isPanelOpen = false);
                  }
                },
                onNavigateWithExtra: (route, extra) {
                  // Navigate directly via GoRouter from Riverpod without context lookup
                  ref.read(routerProvider).push(route, extra: extra);
                  if (mounted) {
                    setState(() => _isPanelOpen = false);
                  }
                },
              ),
            ),
        ],
      ],
    );
  }
}

