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

    final btnBg = isDark ? AppColors.darkSurfaceVariant : Colors.white;
    final btnTextColor = isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary;
    final opTextColor = isDark ? AppColors.accentOrangeLight : AppColors.accentOrange;

    return Container(
      padding: const EdgeInsets.fromLTRB(12, 6, 12, 8),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : const Color(0xFFF2F4F5),
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
            // Row 1
            Row(
              children: [
                _buildBtn('7', btnBg, btnTextColor),
                _buildBtn('8', btnBg, btnTextColor),
                _buildBtn('9', btnBg, btnTextColor),
                _buildActionBtn(
                  Icons.backspace_outlined,
                  btnBg,
                  AppColors.expenseRed,
                  onDelete,
                ),
              ],
            ),
            const SizedBox(height: 6),

            // Row 2
            Row(
              children: [
                _buildBtn('4', btnBg, btnTextColor),
                _buildBtn('5', btnBg, btnTextColor),
                _buildBtn('6', btnBg, btnTextColor),
                _buildBtn('+', btnBg, opTextColor),
              ],
            ),
            const SizedBox(height: 6),

            // Row 3
            Row(
              children: [
                _buildBtn('1', btnBg, btnTextColor),
                _buildBtn('2', btnBg, btnTextColor),
                _buildBtn('3', btnBg, btnTextColor),
                _buildBtn('-', btnBg, opTextColor),
              ],
            ),
            const SizedBox(height: 6),

            // Row 4
            Row(
              children: [
                _buildBtn('.', btnBg, btnTextColor),
                _buildBtn('0', btnBg, btnTextColor),
                _buildBtn('00', btnBg, btnTextColor),
                _buildConfirmBtn(),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBtn(String label, Color bg, Color textColor) {
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4),
        child: AspectRatio(
          aspectRatio: 1.6,
          child: Material(
            color: bg,
            borderRadius: BorderRadius.circular(14),
            elevation: 0,
            child: InkWell(
              borderRadius: BorderRadius.circular(14),
              onTap: () {
                HapticFeedback.lightImpact();
                onKeyPress(label);
              },
              child: Center(
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
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

  Widget _buildActionBtn(
    IconData icon,
    Color bg,
    Color iconColor,
    VoidCallback onTap,
  ) {
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4),
        child: AspectRatio(
          aspectRatio: 1.6,
          child: Material(
            color: bg,
            borderRadius: BorderRadius.circular(14),
            elevation: 0,
            child: InkWell(
              borderRadius: BorderRadius.circular(14),
              onTap: () {
                HapticFeedback.lightImpact();
                onTap();
              },
              child: Center(
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
        padding: const EdgeInsets.symmetric(horizontal: 4),
        child: AspectRatio(
          aspectRatio: 1.6,
          child: Material(
            color: AppColors.primaryGreenLight,
            borderRadius: BorderRadius.circular(14),
            elevation: 2,
            shadowColor: AppColors.primaryGreenLight.withValues(alpha: 0.4),
            child: InkWell(
              borderRadius: BorderRadius.circular(14),
              onTap: () {
                HapticFeedback.mediumImpact();
                onConfirm();
              },
              child: const Center(
                child: Icon(
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
