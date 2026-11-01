import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../providers/app_lock_provider.dart';
import '../screens/app_lock_screen.dart';
import '../screens/app_lock_setup_sheet.dart';

class AppLockWrapper extends ConsumerStatefulWidget {
  final Widget? child;

  const AppLockWrapper({super.key, this.child});

  @override
  ConsumerState<AppLockWrapper> createState() => _AppLockWrapperState();
}

class _AppLockWrapperState extends ConsumerState<AppLockWrapper>
    with WidgetsBindingObserver {
  bool _promptedFirstActivation = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkFirstActivationPrompt();
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    final authState = ref.read(authProvider);

    if (state == AppLifecycleState.paused) {
      ref.read(appLockProvider.notifier).onAppPaused();
    } else if (state == AppLifecycleState.resumed) {
      ref.read(appLockProvider.notifier).onAppResumed(
        isUserLoggedIn: authState.isLoggedIn,
      );
    }
  }

  void _checkFirstActivationPrompt() {
    if (_promptedFirstActivation) return;
    final authState = ref.read(authProvider);
    final lockState = ref.read(appLockProvider);
    final bool isMobile = !kIsWeb &&
        (defaultTargetPlatform == TargetPlatform.android ||
            defaultTargetPlatform == TargetPlatform.iOS);

    if (isMobile && authState.isLoggedIn && lockState.isInitialized && !lockState.hasPin) {
      _promptedFirstActivation = true;
      Future.delayed(const Duration(milliseconds: 600), () {
        if (!mounted) return;
        _showFirstActivationBottomSheet();
      });
    }
  }

  void _showFirstActivationBottomSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        final theme = Theme.of(ctx);
        final isDark = theme.brightness == Brightness.dark;
        return Container(
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF0F172A) : Colors.white,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          ),
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 44,
                height: 4,
                margin: const EdgeInsets.only(bottom: 20),
                decoration: BoxDecoration(
                  color: isDark ? Colors.white24 : Colors.black12,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  color: theme.colorScheme.primary.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.shield_outlined,
                  size: 36,
                  color: theme.colorScheme.primary,
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Protect MyCompany ERP',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text(
                'Set up an App PIN and Biometrics (Fingerprint/Face) to secure your enterprise data.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 13,
                  color: isDark ? Colors.white60 : Colors.black54,
                ),
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(ctx),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text('Maybe Later'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.pop(ctx);
                        AppLockSetupSheet.show(context, mode: AppLockSetupMode.create);
                      },
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text('Set Up PIN'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<AuthState>(authProvider, (previous, next) {
      if (next.isLoggedIn && (previous == null || !previous.isLoggedIn)) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _checkFirstActivationPrompt();
        });
      }
    });

    final lockState = ref.watch(appLockProvider);
    final authState = ref.watch(authProvider);

    final bool isMobile = !kIsWeb &&
        (defaultTargetPlatform == TargetPlatform.android ||
            defaultTargetPlatform == TargetPlatform.iOS);

    final bool shouldShowLockScreen = isMobile &&
        authState.isLoggedIn &&
        lockState.isEnabled &&
        lockState.hasPin &&
        lockState.isLocked;

    return Stack(
      children: [
        if (widget.child != null) widget.child!,
        if (shouldShowLockScreen)
          const Positioned.fill(
            child: AppLockScreen(),
          ),
      ],
    );
  }
}
