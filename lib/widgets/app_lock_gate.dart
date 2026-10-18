import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/settings_provider.dart';
import '../services/security_service.dart';
import '../theme/app_theme.dart';

class AppLockGate extends ConsumerStatefulWidget {
  final Widget child;

  const AppLockGate({super.key, required this.child});

  @override
  ConsumerState<AppLockGate> createState() => _AppLockGateState();
}

class _AppLockGateState extends ConsumerState<AppLockGate> with WidgetsBindingObserver {
  bool _isUnlocked = false;
  bool _isAuthenticating = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    final settings = ref.read(settingsProvider);
    if (settings.biometricLockEnabled) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _requestUnlock();
      });
    } else {
      _isUnlocked = true;
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final settings = ref.read(settingsProvider);
    if (!settings.biometricLockEnabled) {
      if (!_isUnlocked) {
        setState(() => _isUnlocked = true);
      }
      return;
    }

    if (state == AppLifecycleState.paused) {
      setState(() {
        _isUnlocked = false;
      });
    } else if (state == AppLifecycleState.resumed && !_isUnlocked && !_isAuthenticating) {
      _requestUnlock();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  Future<void> _requestUnlock() async {
    if (_isAuthenticating || !mounted) return;
    _isAuthenticating = true;

    try {
      final success = await SecurityService.authenticate();
      if (mounted) {
        setState(() {
          _isUnlocked = success;
          _isAuthenticating = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _isAuthenticating = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(settingsProvider);

    if (!settings.biometricLockEnabled || _isUnlocked) {
      return widget.child;
    }

    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? AppColors.darkBackground : AppColors.lightBackground,
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 96,
                  height: 96,
                  decoration: BoxDecoration(
                    color: AppColors.primaryGreenLight.withValues(alpha: isDark ? 0.12 : 0.08),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: AppColors.primaryGreenLight.withValues(alpha: 0.25),
                      width: 1.5,
                    ),
                  ),
                  child: const Icon(
                    Icons.fingerprint_rounded,
                    size: 52,
                    color: AppColors.primaryGreenLight,
                  ),
                ),
                const SizedBox(height: 28),
                Text(
                  'Pocket is Locked',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.5,
                    color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Confirm your fingerprint, face, or device PIN to continue.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 14,
                    height: 1.4,
                    color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                  ),
                ),
                const SizedBox(height: 36),
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton.icon(
                    onPressed: _isAuthenticating ? null : _requestUnlock,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primaryGreenLight,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    icon: _isAuthenticating
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                          )
                        : const Icon(Icons.lock_open_rounded, size: 20),
                    label: Text(
                      _isAuthenticating ? 'Authenticating...' : 'Unlock Pocket',
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
