import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme/app_theme.dart';

class CalculatorNumpad extends StatelessWidget {
  final ValueChanged<String> onKeyPress;
  final VoidCallback onDelete;
  final VoidCallback onConfirm;

  const CalculatorNumpad({
    super.key,
    required this.onKeyPress,
    required this.onDelete,
    required this.onConfirm,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final btnBg = isDark ? const Color(0xFF191919) : Colors.white;
    final btnBorder = isDark
        ? Colors.white.withValues(alpha: 0.08)
        : Colors.black.withValues(alpha: 0.06);
    final btnTextColor = isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary;

    return Container(
      padding: const EdgeInsets.fromLTRB(14, 8, 14, 10),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : const Color(0xFFF3F4F6),
        border: Border(
          top: BorderSide(
            color: isDark ? AppColors.darkCardBorder : AppColors.lightCardBorder,
            width: 1,
          ),
        ),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Row 1: 1, 2, 3
            Row(
              children: [
                _buildBtn('1', btnBg, btnBorder, btnTextColor),
                _buildBtn('2', btnBg, btnBorder, btnTextColor),
                _buildBtn('3', btnBg, btnBorder, btnTextColor),
              ],
            ),
            const SizedBox(height: 6),

            // Row 2: 4, 5, 6
            Row(
              children: [
                _buildBtn('4', btnBg, btnBorder, btnTextColor),
                _buildBtn('5', btnBg, btnBorder, btnTextColor),
                _buildBtn('6', btnBg, btnBorder, btnTextColor),
              ],
            ),
            const SizedBox(height: 6),

            // Row 3: 7, 8, 9
            Row(
              children: [
                _buildBtn('7', btnBg, btnBorder, btnTextColor),
                _buildBtn('8', btnBg, btnBorder, btnTextColor),
                _buildBtn('9', btnBg, btnBorder, btnTextColor),
              ],
            ),
            const SizedBox(height: 6),

            // Row 4: ., 0, Backspace (⌫)
            Row(
              children: [
                _buildBtn('.', btnBg, btnBorder, btnTextColor),
                _buildBtn('0', btnBg, btnBorder, btnTextColor),
                _buildActionBtn(
                  icon: Icons.backspace_outlined,
                  bg: isDark ? const Color(0xFF241616) : const Color(0xFFFFEBEE),
                  border: isDark
                      ? AppColors.expenseRed.withValues(alpha: 0.25)
                      : AppColors.expenseRed.withValues(alpha: 0.2),
                  iconColor: AppColors.expenseRed,
                  onTap: onDelete,
                ),
              ],
            ),
            const SizedBox(height: 8),

            // Row 5: Sleek Full-Width Neon Save Transaction Button
            _buildFullWidthConfirmBtn(),
          ],
        ),
      ),
    );
  }

  Widget _buildBtn(String label, Color bg, Color border, Color textColor) {
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 3.5),
        child: AspectRatio(
          aspectRatio: 2.1,
          child: Material(
            color: bg,
            borderRadius: BorderRadius.circular(16),
            child: InkWell(
              borderRadius: BorderRadius.circular(16),
              onTap: () {
                HapticFeedback.lightImpact();
                onKeyPress(label);
              },
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: border, width: 1),
                ),
                alignment: Alignment.center,
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: 21,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.3,
                    color: textColor,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildActionBtn({
    required IconData icon,
    required Color bg,
    required Color border,
    required Color iconColor,
    required VoidCallback onTap,
  }) {
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 3.5),
        child: AspectRatio(
          aspectRatio: 2.1,
          child: Material(
            color: bg,
            borderRadius: BorderRadius.circular(16),
            child: InkWell(
              borderRadius: BorderRadius.circular(16),
              onTap: () {
                HapticFeedback.lightImpact();
                onTap();
              },
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: border, width: 1),
                ),
                alignment: Alignment.center,
                child: Icon(icon, color: iconColor, size: 21),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFullWidthConfirmBtn() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 3.5),
      child: SizedBox(
        width: double.infinity,
        height: 48,
        child: Material(
          color: AppColors.primaryGreenLight,
          borderRadius: BorderRadius.circular(16),
          elevation: 3,
          shadowColor: AppColors.primaryGreenLight.withValues(alpha: 0.45),
          child: InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: () {
              HapticFeedback.mediumImpact();
              onConfirm();
            },
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.35),
                  width: 1,
                ),
              ),
              alignment: Alignment.center,
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.check_circle_rounded,
                    color: Colors.black,
                    size: 20,
                  ),
                  SizedBox(width: 8),
                  Text(
                    'Save Transaction',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      color: Colors.black,
                      letterSpacing: 0.2,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
