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

    final btnBg = isDark ? const Color(0xFF1B1B1B) : Colors.white;
    final btnBorder = isDark
        ? Colors.white.withValues(alpha: 0.08)
        : Colors.black.withValues(alpha: 0.06);
    final btnTextColor = isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary;
    final opTextColor = isDark ? AppColors.accentOrangeLight : AppColors.accentOrange;

    return Container(
      padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
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
            // Row 1: 1, 2, 3, Backspace
            Row(
              children: [
                _buildBtn('1', btnBg, btnBorder, btnTextColor),
                _buildBtn('2', btnBg, btnBorder, btnTextColor),
                _buildBtn('3', btnBg, btnBorder, btnTextColor),
                _buildActionBtn(
                  icon: Icons.backspace_outlined,
                  bg: isDark ? const Color(0xFF221717) : const Color(0xFFFFEBEE),
                  border: isDark ? AppColors.expenseRed.withValues(alpha: 0.25) : AppColors.expenseRed.withValues(alpha: 0.2),
                  iconColor: AppColors.expenseRed,
                  onTap: onDelete,
                ),
              ],
            ),
            const SizedBox(height: 6),

            // Row 2: 4, 5, 6, Plus (+)
            Row(
              children: [
                _buildBtn('4', btnBg, btnBorder, btnTextColor),
                _buildBtn('5', btnBg, btnBorder, btnTextColor),
                _buildBtn('6', btnBg, btnBorder, btnTextColor),
                _buildBtn('+', btnBg, btnBorder, opTextColor, isOperator: true),
              ],
            ),
            const SizedBox(height: 6),

            // Row 3: 7, 8, 9, Minus (-)
            Row(
              children: [
                _buildBtn('7', btnBg, btnBorder, btnTextColor),
                _buildBtn('8', btnBg, btnBorder, btnTextColor),
                _buildBtn('9', btnBg, btnBorder, btnTextColor),
                _buildBtn('-', btnBg, btnBorder, opTextColor, isOperator: true),
              ],
            ),
            const SizedBox(height: 6),

            // Row 4: ., 0, 00, Confirm (✓)
            Row(
              children: [
                _buildBtn('.', btnBg, btnBorder, btnTextColor),
                _buildBtn('0', btnBg, btnBorder, btnTextColor),
                _buildBtn('00', btnBg, btnBorder, btnTextColor),
                _buildConfirmBtn(),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBtn(String label, Color bg, Color border, Color textColor, {bool isOperator = false}) {
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 3.5),
        child: AspectRatio(
          aspectRatio: 1.65,
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
                    fontSize: isOperator ? 22 : 20.5,
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
          aspectRatio: 1.65,
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
                child: Icon(icon, color: iconColor, size: 20),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildConfirmBtn() {
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 3.5),
        child: AspectRatio(
          aspectRatio: 1.65,
          child: Material(
            color: AppColors.primaryGreenLight,
            borderRadius: BorderRadius.circular(16),
            elevation: 3,
            shadowColor: AppColors.primaryGreenLight.withValues(alpha: 0.5),
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
                    color: Colors.white.withValues(alpha: 0.3),
                    width: 1,
                  ),
                ),
                alignment: Alignment.center,
                child: const Icon(
                  Icons.check_rounded,
                  color: Colors.black,
                  size: 26,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
