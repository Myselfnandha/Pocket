import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/core_providers.dart';
import '../providers/settings_provider.dart';

void showAutoImportGuideModal(BuildContext context) {
  showDialog(
    context: context,
    builder: (ctx) => const AutoImportGuideModal(),
  );
}

class AutoImportGuideModal extends ConsumerStatefulWidget {
  const AutoImportGuideModal({super.key});

  @override
  ConsumerState<AutoImportGuideModal> createState() => _AutoImportGuideModalState();
}

class _AutoImportGuideModalState extends ConsumerState<AutoImportGuideModal> {
  int _currentStep = 0;

  @override
  Widget build(BuildContext context) {
    final palette = ref.watch(activePaletteProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Center(
      child: Material(
        color: Colors.transparent,
        child: Container(
          width: 440,
          margin: const EdgeInsets.symmetric(horizontal: 20),
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E1E26) : Colors.white,
            borderRadius: BorderRadius.circular(28),
            border: Border.all(
              color: palette.primary.withValues(alpha: 0.4),
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: isDark ? 0.6 : 0.2),
                blurRadius: 30,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header with Step Indicator
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: palette.primary.withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      _getStepIcon(_currentStep),
                      color: palette.primary,
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Step ${_currentStep + 1} of 3',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 1.0,
                            color: palette.primary,
                          ),
                        ),
                        Text(
                          _getStepTitle(_currentStep),
                          style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded, size: 20),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const SizedBox(height: 18),

              // Content Body
              Text(
                _getStepDescription(_currentStep),
                style: TextStyle(
                  fontSize: 13.5,
                  height: 1.45,
                  color: isDark ? Colors.grey.shade300 : Colors.grey.shade700,
                ),
              ),
              const SizedBox(height: 14),

              // Highlights Box
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: isDark ? Colors.black26 : Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: isDark ? Colors.white10 : Colors.black.withValues(alpha: 0.05),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(Icons.shield_outlined, color: palette.primary, size: 20),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        _getStepSecurityNote(_currentStep),
                        style: TextStyle(fontSize: 11.5, color: isDark ? Colors.grey.shade400 : Colors.grey.shade600),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 22),

              // Actions
              Row(
                children: [
                  if (_currentStep > 0) ...[
                    OutlinedButton(
                      onPressed: () => setState(() => _currentStep--),
                      style: OutlinedButton.styleFrom(
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      ),
                      child: const Text('Back'),
                    ),
                    const SizedBox(width: 10),
                  ],
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: () async {
                        if (_currentStep == 0) {
                          setState(() => _currentStep = 1);
                        } else if (_currentStep == 1) {
                          await ref.read(autoImportServiceProvider).openNotificationSettings();
                          setState(() => _currentStep = 2);
                        } else {
                          await ref.read(autoImportServiceProvider).openAccessibilitySettings();
                          if (context.mounted) Navigator.pop(context);
                        }
                      },
                      icon: Icon(_currentStep == 0 ? Icons.arrow_forward_rounded : Icons.open_in_new_rounded, size: 18),
                      label: Text(
                        _currentStep == 0
                            ? 'Continue'
                            : (_currentStep == 1 ? 'Open Notification Settings' : 'Open Accessibility Settings'),
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                      style: FilledButton.styleFrom(
                        backgroundColor: palette.primary,
                        foregroundColor: Colors.black,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  IconData _getStepIcon(int step) {
    switch (step) {
      case 0:
        return Icons.lock_outline_rounded;
      case 1:
        return Icons.notifications_active_outlined;
      case 2:
      default:
        return Icons.visibility_outlined;
    }
  }

  String _getStepTitle(int step) {
    switch (step) {
      case 0:
        return '100% On-Device Privacy';
      case 1:
        return 'Enable Notification Listener';
      case 2:
      default:
        return 'Enable Screen Reader';
    }
  }

  String _getStepDescription(int step) {
    switch (step) {
      case 0:
        return 'Pocket captures transactions entirely on your device. No financial numbers, OTPs, or notifications are ever sent to the cloud. All deductions are verified in your review inbox.';
      case 1:
        return 'Allows Pocket to detect payment alerts from Google Pay, PhonePe, Paytm, and your banking apps as soon as a payment is made.';
      case 2:
      default:
        return 'Enables instant zero-click capture of the green confirmation screen directly inside UPI apps, extracting merchant names and amounts with pixel-perfect accuracy.';
    }
  }

  String _getStepSecurityNote(int step) {
    switch (step) {
      case 0:
        return 'Your financial data is stored locally in encrypted SQLite storage.';
      case 1:
        return 'Find "Pocket" in the list and toggle the switch to Allow.';
      case 2:
      default:
        return 'Look for "Pocket Payment Screen Reader" under Installed Services.';
    }
  }
}
