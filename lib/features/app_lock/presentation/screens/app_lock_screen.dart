import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_strings.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../providers/app_lock_provider.dart';
import '../../domain/models/app_lock_state.dart';

class AppLockScreen extends ConsumerStatefulWidget {
  const AppLockScreen({super.key});

  @override
  ConsumerState<AppLockScreen> createState() => _AppLockScreenState();
}

class _AppLockScreenState extends ConsumerState<AppLockScreen>
    with SingleTickerProviderStateMixin {
  String _enteredPin = '';
  late AnimationController _shakeController;
  late Animation<double> _shakeAnimation;
  bool _isVerifying = false;

  @override
  void initState() {
    super.initState();
    _shakeController = AnimationController(
      duration: const Duration(milliseconds: 400),
      vsync: this,
    );

    _shakeAnimation = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 0.0, end: -12.0), weight: 1),
      TweenSequenceItem(tween: Tween(begin: -12.0, end: 12.0), weight: 2),
      TweenSequenceItem(tween: Tween(begin: 12.0, end: -8.0), weight: 2),
      TweenSequenceItem(tween: Tween(begin: -8.0, end: 8.0), weight: 2),
      TweenSequenceItem(tween: Tween(begin: 8.0, end: 0.0), weight: 1),
    ]).animate(CurvedAnimation(
      parent: _shakeController,
      curve: Curves.easeInOut,
    ));
  }

  @override
  void dispose() {
    _shakeController.dispose();
    super.dispose();
  }

  void _onDigitPressed(String digit) {
    final lockState = ref.read(appLockProvider);
    if (lockState.isLockoutActive || _isVerifying) return;

    if (_enteredPin.length < lockState.pinLength) {
      HapticFeedback.lightImpact();
      setState(() {
        _enteredPin += digit;
      });

      if (_enteredPin.length == lockState.pinLength) {
        _verifyCurrentPin();
      }
    }
  }

  void _onBackspacePressed() {
    if (_enteredPin.isNotEmpty && !_isVerifying) {
      HapticFeedback.selectionClick();
      setState(() {
        _enteredPin = _enteredPin.substring(0, _enteredPin.length - 1);
      });
    }
  }

  void _onClearAll() {
    if (_enteredPin.isNotEmpty && !_isVerifying) {
      HapticFeedback.mediumImpact();
      setState(() {
        _enteredPin = '';
      });
    }
  }

  Future<void> _verifyCurrentPin() async {
    setState(() => _isVerifying = true);
    final pin = _enteredPin;

    final success = await ref.read(appLockProvider.notifier).verifyPin(pin);

    if (mounted) {
      setState(() {
        _isVerifying = false;
        if (!success) {
          _enteredPin = '';
          _shakeController.forward(from: 0.0);
          HapticFeedback.heavyImpact();
        }
      });
    }
  }

  void _handleBiometricAuth() {
    HapticFeedback.selectionClick();
    ref.read(appLockProvider.notifier).authenticateWithBiometrics(isUserInitiated: true);
  }

  String _sanitizeError(String? raw) {
    if (raw == null) return '';
    final lower = raw.toLowerCase();
    if (lower.contains('localauthexception') ||
        lower.contains('platformexception') ||
        lower.contains('exception') ||
        lower.contains('failed:')) {
      return 'Biometric unavailable. Enter PIN.';
    }
    return raw;
  }

  void _handleForgotPin() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Forgot App PIN?'),
        content: const Text(
          'To regain access, you can sign out of your account and sign back in using your company email and password.\n\nYour App PIN will be reset upon signing out.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
              foregroundColor: Colors.white,
            ),
            onPressed: () async {
              Navigator.pop(ctx);
              await ref.read(appLockProvider.notifier).disableAndRemovePin();
              await ref.read(authProvider.notifier).logout();
            },
            child: const Text('Sign Out & Reset'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final lockState = ref.watch(appLockProvider);
    final authState = ref.watch(authProvider);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final primaryColor = theme.colorScheme.primary;
    final companyName = authState.companyName ?? authState.selectedCompany ?? AppStrings.appName;
    final userName = authState.userName ?? 'User';

    return PopScope(
      canPop: false, // Prevent physical back button from bypassing lock
      child: Scaffold(
        backgroundColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
        body: SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) {
              return Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 420),
                  child: SingleChildScrollView(
                    physics: const ClampingScrollPhysics(),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 28.0, vertical: 12.0),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const SizedBox(height: 8),
                          // ── App & Company Branding Header ─────────────────
                          Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                width: 64,
                                height: 64,
                                decoration: BoxDecoration(
                                  color: primaryColor.withValues(alpha: 0.12),
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: primaryColor.withValues(alpha: 0.25),
                                    width: 2,
                                  ),
                                ),
                                child: Center(
                                  child: ClipOval(
                                    child: Image.asset(
                                      'assets/logo.png',
                                      width: 40,
                                      height: 40,
                                      fit: BoxFit.contain,
                                      errorBuilder: (_, __, ___) => Icon(
                                        Icons.lock_outline_rounded,
                                        size: 32,
                                        color: primaryColor,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 12),
                              Text(
                                companyName,
                                style: theme.textTheme.titleLarge?.copyWith(
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: -0.3,
                                ),
                                textAlign: TextAlign.center,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Welcome back, $userName',
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  color: isDark ? Colors.white60 : Colors.black54,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ],
                          ),
                          const SizedBox(height: 18),

                          // ── PIN Title & Dots Indicator ────────────────────
                          Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                'Enter App PIN',
                                style: theme.textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.w600,
                                  color: isDark ? Colors.white : Colors.black87,
                                ),
                              ),
                              const SizedBox(height: 14),
                              AnimatedBuilder(
                                animation: _shakeAnimation,
                                builder: (context, child) {
                                  return Transform.translate(
                                    offset: Offset(_shakeAnimation.value, 0),
                                    child: child,
                                  );
                                },
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: List.generate(
                                    lockState.pinLength,
                                    (index) => _buildPinDot(
                                      isFilled: index < _enteredPin.length,
                                      isError: lockState.errorMessage != null && _enteredPin.isEmpty,
                                      primaryColor: primaryColor,
                                      isDark: isDark,
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 10),

                              // Error or Lockout Message
                              SizedBox(
                                height: 26,
                                child: Center(
                                  child: lockState.errorMessage != null
                                      ? Row(
                                          mainAxisAlignment: MainAxisAlignment.center,
                                          children: [
                                            const Icon(
                                              Icons.error_outline_rounded,
                                              size: 15,
                                              color: AppColors.error,
                                            ),
                                            const SizedBox(width: 6),
                                            Flexible(
                                              child: Text(
                                                _sanitizeError(lockState.errorMessage),
                                                style: const TextStyle(
                                                  color: AppColors.error,
                                                  fontSize: 13,
                                                  fontWeight: FontWeight.w500,
                                                ),
                                                textAlign: TextAlign.center,
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ),
                                          ],
                                        )
                                      : (lockState.isLockoutActive
                                          ? Text(
                                              'Try again in ${lockState.remainingLockoutSeconds}s',
                                              style: const TextStyle(
                                                color: AppColors.error,
                                                fontWeight: FontWeight.bold,
                                                fontSize: 13,
                                              ),
                                            )
                                          : null),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 14),

                          // ── Numeric Keypad ────────────────────────────────
                          _buildKeypad(lockState, isDark, primaryColor),
                          const SizedBox(height: 12),

                          // ── Bottom Footer / Reset Option ──────────────────
                          TextButton(
                            onPressed: _handleForgotPin,
                            style: TextButton.styleFrom(
                              foregroundColor: isDark ? Colors.white54 : Colors.black45,
                            ),
                            child: const Text(
                              'Forgot PIN? Sign Out',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildPinDot({
    required bool isFilled,
    required bool isError,
    required Color primaryColor,
    required bool isDark,
  }) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      margin: const EdgeInsets.symmetric(horizontal: 10),
      width: 16,
      height: 16,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: isFilled
            ? (isError ? AppColors.error : primaryColor)
            : Colors.transparent,
        border: Border.all(
          color: isError
              ? AppColors.error
              : (isFilled
                  ? primaryColor
                  : (isDark ? Colors.white30 : Colors.black26)),
          width: 2,
        ),
        boxShadow: isFilled && !isError
            ? [
                BoxShadow(
                  color: primaryColor.withValues(alpha: 0.35),
                  blurRadius: 8,
                  spreadRadius: 1,
                ),
              ]
            : null,
      ),
    );
  }

  Widget _buildKeypad(AppLockState state, bool isDark, Color primaryColor) {
    final showBiometric = state.biometricsEnabled &&
        state.canCheckBiometrics &&
        state.biometricCapability != BiometricCapability.none;

    final isFace = state.biometricCapability == BiometricCapability.face;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _buildKeyRow(['1', '2', '3'], isDark),
        const SizedBox(height: 14),
        _buildKeyRow(['4', '5', '6'], isDark),
        const SizedBox(height: 14),
        _buildKeyRow(['7', '8', '9'], isDark),
        const SizedBox(height: 14),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            // Bottom-Left: Biometric trigger
            SizedBox(
              width: 72,
              height: 72,
              child: showBiometric
                  ? Material(
                      color: Colors.transparent,
                      shape: const CircleBorder(),
                      clipBehavior: Clip.antiAlias,
                      child: InkWell(
                        onTap: state.isLockoutActive ? null : _handleBiometricAuth,
                        child: Center(
                          child: Icon(
                            isFace ? Icons.face_rounded : Icons.fingerprint_rounded,
                            size: 34,
                            color: primaryColor,
                          ),
                        ),
                      ),
                    )
                  : const SizedBox.shrink(),
            ),
            // Bottom-Center: Digit 0
            _buildKeypadButton('0', isDark),
            // Bottom-Right: Backspace
            SizedBox(
              width: 72,
              height: 72,
              child: Material(
                color: Colors.transparent,
                shape: const CircleBorder(),
                clipBehavior: Clip.antiAlias,
                child: InkWell(
                  onTap: _onBackspacePressed,
                  onLongPress: _onClearAll,
                  child: Center(
                    child: Icon(
                      Icons.backspace_outlined,
                      size: 26,
                      color: isDark ? Colors.white70 : Colors.black87,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildKeyRow(List<String> digits, bool isDark) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: digits.map((d) => _buildKeypadButton(d, isDark)).toList(),
    );
  }

  Widget _buildKeypadButton(String digit, bool isDark) {
    final bgColor = isDark
        ? const Color(0xFF1E293B)
        : const Color(0xFFEDF2F7);

    return SizedBox(
      width: 72,
      height: 72,
      child: Material(
        color: bgColor,
        shape: const CircleBorder(),
        elevation: 0,
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () => _onDigitPressed(digit),
          child: Center(
            child: Text(
              digit,
              style: TextStyle(
                fontSize: 26,
                fontWeight: FontWeight.w600,
                color: isDark ? Colors.white : const Color(0xFF1E293B),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
