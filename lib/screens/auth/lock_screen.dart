import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/app_providers.dart';
import '../../theme/app_theme.dart';

class LockScreen extends ConsumerStatefulWidget {
  final VoidCallback onAuthenticated;

  const LockScreen({super.key, required this.onAuthenticated});

  @override
  ConsumerState<LockScreen> createState() => _LockScreenState();
}

class _LockScreenState extends ConsumerState<LockScreen> {
  String _enteredPin = '';
  bool _hasError = false;

  void _onKeyPress(String digit) {
    if (_enteredPin.length < 4) {
      setState(() {
        _hasError = false;
        _enteredPin += digit;
      });

      if (_enteredPin.length == 4) {
        _verifyPin();
      }
    }
  }

  void _onDelete() {
    if (_enteredPin.isNotEmpty) {
      setState(() {
        _hasError = false;
        _enteredPin = _enteredPin.substring(0, _enteredPin.length - 1);
      });
    }
  }

  void _verifyPin() {
    final settings = ref.read(settingsProvider);
    final targetPin = settings.pinCode ?? '1234';

    if (_enteredPin == targetPin) {
      HapticFeedback.mediumImpact();
      widget.onAuthenticated();
    } else {
      HapticFeedback.heavyImpact();
      setState(() {
        _hasError = true;
        _enteredPin = '';
      });
    }
  }

  void _triggerBiometrics() {
    HapticFeedback.lightImpact();
    // In mobile simulator / web, simulate successful biometric auth
    widget.onAuthenticated();
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(settingsProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            const Spacer(flex: 2),

            // App Icon
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [AppColors.primaryGreen, AppColors.primaryGreenLight],
                ),
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: AppColors.primaryGreenLight.withValues(alpha: 0.35),
                    blurRadius: 20,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              alignment: Alignment.center,
              child: const Text('🔒', style: TextStyle(fontSize: 32)),
            ),
            const SizedBox(height: 20),

            Text(
              'Pocket Security',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w800,
                color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              _hasError ? 'Incorrect PIN, please try again' : 'Enter your 4-digit PIN to unlock',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: _hasError
                    ? AppColors.expenseRed
                    : (isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary),
              ),
            ),
            const SizedBox(height: 32),

            // PIN Dots
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(4, (index) {
                final isFilled = index < _enteredPin.length;
                return AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  margin: const EdgeInsets.symmetric(horizontal: 10),
                  width: 16,
                  height: 16,
                  decoration: BoxDecoration(
                    color: _hasError
                        ? AppColors.expenseRed
                        : (isFilled
                            ? AppColors.primaryGreenLight
                            : Colors.transparent),
                    border: Border.all(
                      color: _hasError
                          ? AppColors.expenseRed
                          : (isFilled
                              ? AppColors.primaryGreenLight
                              : (isDark ? const Color(0xFF444444) : const Color(0xFFCCCCCC))),
                      width: 2,
                    ),
                    shape: BoxShape.circle,
                  ),
                );
              }),
            ),

            const Spacer(flex: 3),

            // PIN Numpad Grid
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 40),
              child: Column(
                children: [
                  _buildNumpadRow(['1', '2', '3'], isDark),
                  const SizedBox(height: 16),
                  _buildNumpadRow(['4', '5', '6'], isDark),
                  const SizedBox(height: 16),
                  _buildNumpadRow(['7', '8', '9'], isDark),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      // Biometric button (if enabled)
                      if (settings.biometricEnabled)
                        _buildActionButton(
                          Icons.fingerprint_rounded,
                          AppColors.primaryGreenLight,
                          _triggerBiometrics,
                          isDark,
                        )
                      else
                        const SizedBox(width: 68, height: 68),

                      _buildNumpadButton('0', isDark),

                      _buildActionButton(
                        Icons.backspace_outlined,
                        AppColors.expenseRed,
                        _onDelete,
                        isDark,
                      ),
                    ],
                  ),
                ],
              ),
            ),

            const Spacer(flex: 2),
          ],
        ),
      ),
    );
  }

  Widget _buildNumpadRow(List<String> digits, bool isDark) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: digits.map((d) => _buildNumpadButton(d, isDark)).toList(),
    );
  }

  Widget _buildNumpadButton(String digit, bool isDark) {
    return Material(
      color: isDark ? AppColors.darkSurfaceVariant : Colors.white,
      shape: const CircleBorder(),
      elevation: 0,
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: () {
          HapticFeedback.lightImpact();
          _onKeyPress(digit);
        },
        child: Container(
          width: 68,
          height: 68,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(
              color: isDark ? AppColors.darkCardBorder : AppColors.lightCardBorder,
            ),
          ),
          child: Text(
            digit,
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w700,
              color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildActionButton(IconData icon, Color color, VoidCallback onTap, bool isDark) {
    return Material(
      color: isDark ? AppColors.darkSurfaceVariant : Colors.white,
      shape: const CircleBorder(),
      elevation: 0,
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: () {
          HapticFeedback.lightImpact();
          onTap();
        },
        child: Container(
          width: 68,
          height: 68,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(
              color: isDark ? AppColors.darkCardBorder : AppColors.lightCardBorder,
            ),
          ),
          child: Icon(icon, color: color, size: 26),
        ),
      ),
    );
  }
}
