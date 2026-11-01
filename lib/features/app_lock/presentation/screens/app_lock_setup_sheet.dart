import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_sizes.dart';
import '../providers/app_lock_provider.dart';
import '../../domain/models/app_lock_state.dart';

enum AppLockSetupMode {
  create,
  change,
}

class AppLockSetupSheet extends ConsumerStatefulWidget {
  final AppLockSetupMode mode;

  const AppLockSetupSheet({
    super.key,
    this.mode = AppLockSetupMode.create,
  });

  static Future<bool?> show(BuildContext context, {AppLockSetupMode mode = AppLockSetupMode.create}) {
    return showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => AppLockSetupSheet(mode: mode),
    );
  }

  @override
  ConsumerState<AppLockSetupSheet> createState() => _AppLockSetupSheetState();
}

class _AppLockSetupSheetState extends ConsumerState<AppLockSetupSheet> {
  int _pinLength = 4;
  int _step = 0; // 0: enter/current, 1: enter new, 2: confirm new, 3: biometrics opt-in

  String _currentPin = '';
  String _newPin = '';
  String _confirmPin = '';
  String _activeInput = '';

  String? _errorMessage;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    final lockState = ref.read(appLockProvider);
    _pinLength = lockState.pinLength;
  }

  String get _title {
    if (widget.mode == AppLockSetupMode.change) {
      if (_step == 0) return 'Enter Current PIN';
      if (_step == 1) return 'Enter New App PIN';
      return 'Confirm New App PIN';
    } else {
      if (_step == 0) return 'Create App PIN';
      if (_step == 1) return 'Confirm App PIN';
      return 'Biometric Unlock';
    }
  }

  String get _subtitle {
    if (widget.mode == AppLockSetupMode.change) {
      if (_step == 0) return 'Verify your existing $_pinLength-digit PIN';
      if (_step == 1) return 'Choose a new $_pinLength-digit security PIN';
      return 'Re-enter your new PIN to confirm';
    } else {
      if (_step == 0) return 'Set a $_pinLength-digit PIN to secure your app';
      if (_step == 1) return 'Re-enter the PIN to confirm';
      return 'Unlock faster using your fingerprint or face';
    }
  }

  void _onDigit(String digit) {
    if (_isLoading) return;
    if (_activeInput.length < _pinLength) {
      HapticFeedback.lightImpact();
      setState(() {
        _activeInput += digit;
        _errorMessage = null;
      });

      if (_activeInput.length == _pinLength) {
        _handlePinSubmitted(_activeInput);
      }
    }
  }

  void _onBackspace() {
    if (_activeInput.isNotEmpty && !_isLoading) {
      HapticFeedback.selectionClick();
      setState(() {
        _activeInput = _activeInput.substring(0, _activeInput.length - 1);
        _errorMessage = null;
      });
    }
  }

  void _onClear() {
    if (_activeInput.isNotEmpty && !_isLoading) {
      HapticFeedback.mediumImpact();
      setState(() {
        _activeInput = '';
        _errorMessage = null;
      });
    }
  }

  Future<void> _handlePinSubmitted(String pin) async {
    final lockNotifier = ref.read(appLockProvider.notifier);
    final lockState = ref.read(appLockProvider);

    if (widget.mode == AppLockSetupMode.change) {
      if (_step == 0) {
        // Verify current PIN
        setState(() => _isLoading = true);
        final isValid = await ref.read(appLockStorageServiceProvider).verifyPin(pin);
        setState(() => _isLoading = false);

        if (!isValid) {
          HapticFeedback.heavyImpact();
          setState(() {
            _activeInput = '';
            _errorMessage = 'Incorrect current PIN. Please try again.';
          });
          return;
        }

        setState(() {
          _currentPin = pin;
          _activeInput = '';
          _step = 1;
        });
      } else if (_step == 1) {
        setState(() {
          _newPin = pin;
          _activeInput = '';
          _step = 2;
        });
      } else if (_step == 2) {
        _confirmPin = pin;
        if (_confirmPin != _newPin) {
          HapticFeedback.heavyImpact();
          setState(() {
            _activeInput = '';
            _errorMessage = 'PINs do not match. Try entering new PIN again.';
            _step = 1;
          });
          return;
        }

        setState(() => _isLoading = true);
        final success = await lockNotifier.changePin(oldPin: _currentPin, newPin: _newPin);
        setState(() => _isLoading = false);

        if (success && mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('App PIN changed successfully.')),
          );
          Navigator.pop(context, true);
        } else if (mounted) {
          setState(() {
            _activeInput = '';
            _errorMessage = 'Failed to update PIN. Try again.';
          });
        }
      }
    } else {
      // Create mode
      if (_step == 0) {
        setState(() {
          _newPin = pin;
          _activeInput = '';
          _step = 1;
        });
      } else if (_step == 1) {
        _confirmPin = pin;
        if (_confirmPin != _newPin) {
          HapticFeedback.heavyImpact();
          setState(() {
            _activeInput = '';
            _errorMessage = 'PINs do not match. Please re-enter.';
          });
          return;
        }

        // If biometrics supported, offer opt-in step
        if (lockState.canCheckBiometrics && lockState.isDeviceSupported) {
          setState(() {
            _step = 2;
          });
        } else {
          _completeSetup(enableBiometrics: false);
        }
      }
    }
  }

  Future<void> _completeSetup({required bool enableBiometrics}) async {
    setState(() => _isLoading = true);
    try {
      await ref.read(appLockProvider.notifier).setupPin(
            _newPin,
            enableBiometrics: enableBiometrics,
          );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('App Lock enabled successfully.')),
        );
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'Failed to enable App Lock: $e';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final primaryColor = theme.colorScheme.primary;
    final lockState = ref.watch(appLockProvider);

    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0F172A) : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      ),
      padding: const EdgeInsets.only(top: 12, bottom: 24),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Drag handle
            Container(
              width: 44,
              height: 4,
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                color: isDark ? Colors.white24 : Colors.black12,
                borderRadius: BorderRadius.circular(2),
              ),
            ),

            // Header Row
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Row(
                children: [
                  if (_step > 0 && _step < 2)
                    IconButton(
                      icon: const Icon(Icons.arrow_back_rounded),
                      onPressed: () {
                        setState(() {
                          _step--;
                          _activeInput = '';
                          _errorMessage = null;
                        });
                      },
                    ),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Text(
                          _title,
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                            fontSize: 18,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _subtitle,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: isDark ? Colors.white60 : Colors.black54,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded),
                    onPressed: () => Navigator.pop(context, false),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),

            // PIN Length Selector (Only on step 0 of create mode)
            if (widget.mode == AppLockSetupMode.create && _step == 0)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: SegmentedButton<int>(
                  segments: const [
                    ButtonSegment(value: 4, label: Text('4-Digit PIN')),
                    ButtonSegment(value: 6, label: Text('6-Digit PIN')),
                  ],
                  selected: {_pinLength},
                  onSelectionChanged: (vals) {
                    setState(() {
                      _pinLength = vals.first;
                      _activeInput = '';
                      _errorMessage = null;
                    });
                  },
                ),
              ),

            // Biometric Opt-in Screen (Step 2 of create mode)
            if (_step == 2 && widget.mode == AppLockSetupMode.create) ...[
              const SizedBox(height: 24),
              Container(
                width: 76,
                height: 76,
                decoration: BoxDecoration(
                  color: primaryColor.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  lockState.biometricCapability == BiometricCapability.face
                      ? Icons.face_rounded
                      : Icons.fingerprint_rounded,
                  size: 44,
                  color: primaryColor,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Enable ${lockState.biometricName} Unlock?',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 17),
              ),
              const SizedBox(height: 8),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 40),
                child: Text(
                  'Use ${lockState.biometricName} for instant, secure access to your ERP. You can always use your PIN as a backup.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 13,
                    color: isDark ? Colors.white60 : Colors.black54,
                  ),
                ),
              ),
              const SizedBox(height: 32),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: _isLoading ? null : () => _completeSetup(enableBiometrics: false),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        child: const Text('Not Now'),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: _isLoading ? null : () => _completeSetup(enableBiometrics: true),
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        child: _isLoading
                            ? const SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : Text('Enable ${lockState.biometricName}'),
                      ),
                    ),
                  ],
                ),
              ),
            ] else ...[
              // PIN Dots
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(
                  _pinLength,
                  (index) => Container(
                    margin: const EdgeInsets.symmetric(horizontal: 8),
                    width: 14,
                    height: 14,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: index < _activeInput.length ? primaryColor : Colors.transparent,
                      border: Border.all(
                        color: index < _activeInput.length
                            ? primaryColor
                            : (isDark ? Colors.white30 : Colors.black26),
                        width: 2,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),

              // Error text
              SizedBox(
                height: 24,
                child: _errorMessage != null
                    ? Text(
                        _errorMessage!,
                        style: const TextStyle(
                          color: AppColors.error,
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                        ),
                      )
                    : null,
              ),

              // Keypad
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 32),
                child: Column(
                  children: [
                    _buildRow(['1', '2', '3'], isDark),
                    const SizedBox(height: 10),
                    _buildRow(['4', '5', '6'], isDark),
                    const SizedBox(height: 10),
                    _buildRow(['7', '8', '9'], isDark),
                    const SizedBox(height: 10),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        const SizedBox(width: 64, height: 64),
                        _buildButton('0', isDark),
                        SizedBox(
                          width: 64,
                          height: 64,
                          child: IconButton(
                            icon: const Icon(Icons.backspace_outlined),
                            onPressed: _onBackspace,
                            onLongPress: _onClear,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildRow(List<String> digits, bool isDark) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: digits.map((d) => _buildButton(d, isDark)).toList(),
    );
  }

  Widget _buildButton(String digit, bool isDark) {
    return SizedBox(
      width: 64,
      height: 64,
      child: Material(
        color: isDark ? const Color(0xFF1E293B) : const Color(0xFFEDF2F7),
        shape: const CircleBorder(),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: () => _onDigit(digit),
          child: Center(
            child: Text(
              digit,
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w600,
                color: isDark ? Colors.white : Colors.black87,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
