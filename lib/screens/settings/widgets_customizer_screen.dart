import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/wallet_model.dart';
import '../../providers/app_providers.dart';
import '../../services/system_widget_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/top_capsule_toast.dart';

class WidgetsCustomizerScreen extends ConsumerStatefulWidget {
  const WidgetsCustomizerScreen({super.key});

  @override
  ConsumerState<WidgetsCustomizerScreen> createState() => _WidgetsCustomizerScreenState();
}

class _WidgetsCustomizerScreenState extends ConsumerState<WidgetsCustomizerScreen> {
  int _selectedPreviewTab = 0; // 0: Card (4x2), 1: Safe-to-Spend (2x2), 2: Quick Bar (4x1)

  Future<void> _pinWidget(String widgetType, String widgetName) async {
    final success = await SystemWidgetService.requestPinWidget(widgetType);
    if (!mounted) return;
    if (success) {
      TopCapsuleToast.show(
        context,
        message: 'Prompted system to pin $widgetName to Home Screen',
        icon: const Icon(Icons.check_circle_rounded, color: Colors.black, size: 20),
        accentColor: AppColors.primaryGreenLight,
      );
    } else {
      TopCapsuleToast.show(
        context,
        message: 'Long-press your phone home screen > Widgets > Pocket to add',
        icon: const Icon(Icons.info_outline_rounded, color: Colors.white, size: 20),
        accentColor: AppColors.infoBlue,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(settingsProvider);
    final totalBalance = ref.watch(totalBalanceProvider);
    final wallets = ref.watch(walletsWithBalancesProvider);
    final monthlyStats = ref.watch(monthlyStatsProvider);
    final budgetRemaining = ref.watch(totalBudgetRemainingProvider);
    final forecast = ref.watch(monthSpendForecastProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // Resolve primary wallet name & balance for preview
    double activeCardBalance = totalBalance;
    String activeCardWalletName = 'All Accounts';
    if (settings.widgetSelectedWalletId != null && wallets.isNotEmpty) {
      final match = wallets.where((w) => w.id == settings.widgetSelectedWalletId);
      if (match.isNotEmpty) {
        activeCardBalance = match.first.currentBalance;
        activeCardWalletName = match.first.name;
      }
    }

    final displayBalanceStr = settings.widgetPrivacyMode
        ? '••••••'
        : settings.formatCurrency(activeCardBalance);
    final displayTotalStr = settings.widgetPrivacyMode
        ? '••••••'
        : settings.formatCurrency(totalBalance);

    // Calculate safe daily spend
    final daysRemaining = forecast.daysRemainingInMonth > 0 ? forecast.daysRemainingInMonth : 1;
    final safeDailySpend = (budgetRemaining > 0 ? budgetRemaining : 0.0) / daysRemaining;
    final displaySafeDailyStr = settings.widgetPrivacyMode
        ? '••••••'
        : settings.formatCurrency(safeDailySpend);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Home Screen Widgets'),
        centerTitle: false,
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        children: [
          // Header Description
          Text(
            'GLANCEABLE DESKTOP SUITE',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.2,
              color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Keep your finances at your fingertips with real-time Android home screen widgets.',
            style: TextStyle(
              fontSize: 13,
              color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
            ),
          ),
          const SizedBox(height: 16),

          // Widget Type Selector Tabs
          Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1A1A1E) : const Color(0xFFEFEFEF),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Row(
              children: [
                _buildTabButton(0, 'Card (4x2)', Icons.credit_card_rounded, isDark),
                _buildTabButton(1, 'Runway (2x2)', Icons.speed_rounded, isDark),
                _buildTabButton(2, 'Bar (4x1)', Icons.view_headline_rounded, isDark),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Live Interactive Preview Box
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF101012) : const Color(0xFFF2F4F7),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: isDark ? Colors.white10 : Colors.black12,
              ),
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: const BoxDecoration(
                        color: AppColors.primaryGreenLight,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'LIVE PHONE DESKTOP PREVIEW',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1.0,
                        color: isDark ? Colors.white60 : Colors.black54,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),

                // Render Active Preview
                if (_selectedPreviewTab == 0)
                  _buildCardWidgetPreview(
                    isDark: isDark,
                    walletName: activeCardWalletName,
                    balanceStr: displayBalanceStr,
                    todaySpentStr: settings.formatCurrency(monthlyStats.todayExpense),
                    secondaryAction: settings.widgetSecondaryAction,
                    isOverBudget: budgetRemaining <= 0,
                  )
                else if (_selectedPreviewTab == 1)
                  _buildRunwayWidgetPreview(
                    isDark: isDark,
                    safeDailyStr: displaySafeDailyStr,
                    daysLeft: daysRemaining,
                    budgetRemainingStr: settings.formatCurrency(budgetRemaining),
                    isOverBudget: budgetRemaining <= 0,
                  )
                else
                  _buildBarWidgetPreview(
                    isDark: isDark,
                    totalBalanceStr: displayTotalStr,
                  ),

                const SizedBox(height: 16),

                // One-Tap Add to Home Screen Button
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton.icon(
                    onPressed: () {
                      final type = _selectedPreviewTab == 0
                          ? 'card'
                          : (_selectedPreviewTab == 1 ? 'runway' : 'bar');
                      final name = _selectedPreviewTab == 0
                          ? 'Pocket Card (4x2)'
                          : (_selectedPreviewTab == 1
                              ? 'Safe-to-Spend (2x2)'
                              : 'Pocket Quick Bar (4x1)');
                      _pinWidget(type, name);
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primaryGreenLight,
                      foregroundColor: Colors.black,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    icon: const Icon(Icons.add_to_home_screen_rounded, size: 20),
                    label: Text(
                      _selectedPreviewTab == 0
                          ? 'Add Card (4x2) to Home Screen'
                          : (_selectedPreviewTab == 1
                              ? 'Add Runway (2x2) to Home Screen'
                              : 'Add Quick Bar (4x1) to Home Screen'),
                      style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Customization Controls
          Text(
            'WIDGET PREFERENCES',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.2,
              color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
            ),
          ),
          const SizedBox(height: 10),

          // Privacy Mode Switch
          Container(
            decoration: BoxDecoration(
              color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isDark ? AppColors.darkCardBorder : AppColors.lightCardBorder,
              ),
            ),
            child: Column(
              children: [
                SwitchListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  secondary: Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: settings.widgetPrivacyMode
                          ? AppColors.primaryGreenLight.withValues(alpha: 0.15)
                          : (isDark ? Colors.white10 : Colors.black12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      settings.widgetPrivacyMode ? Icons.visibility_off_rounded : Icons.visibility_rounded,
                      color: settings.widgetPrivacyMode ? AppColors.primaryGreenLight : (isDark ? Colors.white70 : Colors.black54),
                      size: 20,
                    ),
                  ),
                  title: const Text(
                    'Privacy Mode on Desktop',
                    style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                  ),
                  subtitle: const Text(
                    'Mask sensitive balance amounts (••••••) on your phone home screen',
                    style: TextStyle(fontSize: 12),
                  ),
                  value: settings.widgetPrivacyMode,
                  activeThumbColor: AppColors.primaryGreenLight,
                  onChanged: (val) {
                    ref.read(settingsProvider.notifier).setWidgetPrivacyMode(val);
                  },
                ),
                Divider(height: 1, color: isDark ? AppColors.darkCardBorder : AppColors.lightCardBorder),

                // Card Account Selector
                ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  leading: Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: isDark ? Colors.white10 : Colors.black12,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.account_balance_wallet_rounded, size: 20),
                  ),
                  title: const Text(
                    'Card Widget Featured Account',
                    style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                  ),
                  subtitle: Text(
                    activeCardWalletName,
                    style: const TextStyle(fontSize: 12),
                  ),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: () => _showWalletPicker(context, ref, wallets, settings.widgetSelectedWalletId),
                ),
                Divider(height: 1, color: isDark ? AppColors.darkCardBorder : AppColors.lightCardBorder),

                // Secondary Action Preference
                ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  leading: Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: isDark ? Colors.white10 : Colors.black12,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      settings.widgetSecondaryAction == 'voice'
                          ? Icons.mic_rounded
                          : Icons.camera_alt_rounded,
                      size: 20,
                    ),
                  ),
                  title: const Text(
                    'Secondary Action Button',
                    style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                  ),
                  subtitle: Text(
                    settings.widgetSecondaryAction == 'voice'
                        ? '🎙️ Voice / NLP Assistant'
                        : '📸 Receipt Camera Scanner',
                    style: const TextStyle(fontSize: 12),
                  ),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: () => _showSecondaryActionPicker(context, ref, settings.widgetSecondaryAction),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Android Widget Instructions Card
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF141418) : const Color(0xFFF7F8FA),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isDark ? Colors.white.withValues(alpha: 0.08) : Colors.black.withValues(alpha: 0.06),
              ),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.lightbulb_outline_rounded, color: AppColors.accentOrange, size: 22),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Manual Android Setup Tip',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: isDark ? Colors.white : Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'You can also touch and hold any empty area on your phone desktop, tap Widgets, scroll to Pocket, and drag your favorite widget directly onto your screen.',
                        style: TextStyle(
                          fontSize: 11.5,
                          height: 1.4,
                          color: isDark ? Colors.white60 : Colors.black54,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _buildTabButton(int index, String label, IconData icon, bool isDark) {
    final isSelected = _selectedPreviewTab == index;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _selectedPreviewTab = index),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: isSelected
                ? (isDark ? const Color(0xFF2C2C32) : Colors.white)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.1),
                      blurRadius: 4,
                      offset: const Offset(0, 1),
                    )
                  ]
                : null,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 15,
                color: isSelected
                    ? AppColors.primaryGreenLight
                    : (isDark ? Colors.white54 : Colors.black45),
              ),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  fontSize: 11.5,
                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                  color: isSelected
                      ? (isDark ? Colors.white : Colors.black87)
                      : (isDark ? Colors.white54 : Colors.black45),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // 1. Preview for Card Widget (4x2)
  Widget _buildCardWidgetPreview({
    required bool isDark,
    required String walletName,
    required String balanceStr,
    required String todaySpentStr,
    required String secondaryAction,
    required bool isOverBudget,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF141417),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0xFF2A2A30), width: 1.2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text(
                'POCKET',
                style: TextStyle(
                  color: Color(0xFF00C853),
                  fontSize: 12,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(width: 8),
              Container(
                width: 18,
                height: 13,
                decoration: BoxDecoration(
                  color: const Color(0xFF2C2616),
                  borderRadius: BorderRadius.circular(3),
                  border: Border.all(color: const Color(0xFFC5A059), width: 1),
                ),
              ),
              const SizedBox(width: 4),
              const Text(
                ')))',
                style: TextStyle(
                  color: Color(0xFF7A7A85),
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const Spacer(),
              Text(
                walletName,
                style: const TextStyle(
                  color: Color(0xFF9E9EA8),
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 2),
          const Text(
            '•••• 2026',
            style: TextStyle(
              color: Color(0xFF5A5A66),
              fontSize: 10,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: 8),

          // Inset Box
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: const Color(0xFF1A1A1E),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFF262626)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'AVAILABLE BALANCE',
                  style: TextStyle(
                    color: Color(0xFF8A8A96),
                    fontSize: 8.5,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 1),
                Text(
                  balanceStr,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Text(
                      '$todaySpentStr Today',
                      style: const TextStyle(
                        color: Color(0xFFEF5350),
                        fontSize: 10.5,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(width: 6),
                    const Text('•', style: TextStyle(color: Color(0xFF44444E), fontSize: 10)),
                    const SizedBox(width: 6),
                    Text(
                      isOverBudget ? '⚠️ Over Budget' : '✓ On Budget',
                      style: TextStyle(
                        color: isOverBudget ? const Color(0xFFFFA000) : const Color(0xFF00C853),
                        fontSize: 10.5,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),

          // Action Buttons Row
          Row(
            children: [
              Expanded(
                flex: 6,
                child: Container(
                  height: 32,
                  decoration: BoxDecoration(
                    color: const Color(0xFF00C853),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  alignment: Alignment.center,
                  child: const Text(
                    '⚡ Quick Add',
                    style: TextStyle(
                      color: Colors.black,
                      fontWeight: FontWeight.w800,
                      fontSize: 11.5,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                flex: 4,
                child: Container(
                  height: 32,
                  decoration: BoxDecoration(
                    color: const Color(0xFF202024),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFF32323A)),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    secondaryAction == 'voice' ? '🎙️ Voice' : '📸 Scan',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                      fontSize: 11.5,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // 2. Preview for Safe-to-Spend Runway Widget (2x2)
  Widget _buildRunwayWidgetPreview({
    required bool isDark,
    required String safeDailyStr,
    required int daysLeft,
    required String budgetRemainingStr,
    required bool isOverBudget,
  }) {
    return Container(
      width: 220,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF131316),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0xFF28282E), width: 1.2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text(
                'SAFE TO SPEND',
                style: TextStyle(
                  color: Color(0xFF00C853),
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const Spacer(),
              Text(
                '${daysLeft}d left',
                style: const TextStyle(
                  color: Color(0xFF8E8E98),
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                safeDailyStr,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(width: 4),
              const Text(
                '/ day',
                style: TextStyle(
                  color: Color(0xFF7A7A88),
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),

          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: const Color(0xFF1A1A1E),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: const Color(0xFF142618),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: const Color(0xFF00C853)),
                  ),
                  child: Text(
                    isOverBudget ? '⚠️ OVER BUDGET' : '✓ ON TRACK',
                    style: const TextStyle(
                      color: Color(0xFF00C853),
                      fontSize: 8.5,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '$budgetRemainingStr remaining',
                  style: const TextStyle(color: Color(0xFFA0A0AA), fontSize: 9.5),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),

          Container(
            height: 32,
            width: double.infinity,
            decoration: BoxDecoration(
              color: const Color(0xFF00C853),
              borderRadius: BorderRadius.circular(10),
            ),
            alignment: Alignment.center,
            child: const Text(
              '➕ Log Spend',
              style: TextStyle(
                color: Colors.black,
                fontWeight: FontWeight.w800,
                fontSize: 11.5,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // 3. Preview for Quick Action Bar (4x1)
  Widget _buildBarWidgetPreview({
    required bool isDark,
    required String totalBalanceStr,
  }) {
    return Container(
      width: double.infinity,
      height: 52,
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: BoxDecoration(
        color: const Color(0xFF161619),
        borderRadius: BorderRadius.circular(26),
        border: Border.all(color: const Color(0xFF2A2A32), width: 1.2),
      ),
      child: Row(
        children: [
          Container(
            width: 24,
            height: 24,
            decoration: const BoxDecoration(
              color: Color(0xFF142618),
              shape: BoxShape.circle,
            ),
            alignment: Alignment.center,
            child: const Text(
              'P',
              style: TextStyle(
                color: Color(0xFF00C853),
                fontWeight: FontWeight.w900,
                fontSize: 12,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                totalBalanceStr,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                ),
              ),
              const Text(
                'Pocket Balance',
                style: TextStyle(
                  color: Color(0xFF7A7A85),
                  fontSize: 8.5,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const Spacer(),

          // 3 Action Circles
          _buildCircleBtn('➕', const Color(0xFF00C853)),
          const SizedBox(width: 8),
          _buildCircleBtn('📸', Colors.white),
          const SizedBox(width: 8),
          _buildCircleBtn('🎙️', Colors.white),
        ],
      ),
    );
  }

  Widget _buildCircleBtn(String label, Color color) {
    return Container(
      width: 36,
      height: 36,
      decoration: BoxDecoration(
        color: const Color(0xFF222228),
        shape: BoxShape.circle,
        border: Border.all(color: const Color(0xFF363640)),
      ),
      alignment: Alignment.center,
      child: Text(
        label,
        style: TextStyle(fontSize: 13, color: color),
      ),
    );
  }

  void _showWalletPicker(
    BuildContext context,
    WidgetRef ref,
    List<WalletModel> wallets,
    String? currentWalletId,
  ) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 12),
              Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.withValues(alpha: 0.4),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const Padding(
                padding: EdgeInsets.all(16),
                child: Text(
                  'Select Account for Card Widget',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ),
              ListTile(
                leading: const Icon(Icons.account_balance_wallet_rounded, color: AppColors.primaryGreenLight),
                title: const Text('All Accounts (Net Balance)', style: TextStyle(fontWeight: FontWeight.w600)),
                trailing: currentWalletId == null ? const Icon(Icons.check, color: AppColors.primaryGreenLight) : null,
                onTap: () {
                  ref.read(settingsProvider.notifier).setWidgetSelectedWalletId(null);
                  Navigator.pop(ctx);
                },
              ),
              const Divider(height: 1),
              ...wallets.map((wallet) {
                final isSelected = currentWalletId == wallet.id;
                return ListTile(
                  leading: Text(wallet.icon, style: const TextStyle(fontSize: 22)),
                  title: Text(wallet.name, style: const TextStyle(fontWeight: FontWeight.w600)),
                  subtitle: Text(wallet.walletType.name.toUpperCase()),
                  trailing: isSelected ? const Icon(Icons.check, color: AppColors.primaryGreenLight) : null,
                  onTap: () {
                    ref.read(settingsProvider.notifier).setWidgetSelectedWalletId(wallet.id);
                    Navigator.pop(ctx);
                  },
                );
              }),
              const SizedBox(height: 16),
            ],
          ),
        );
      },
    );
  }

  void _showSecondaryActionPicker(
    BuildContext context,
    WidgetRef ref,
    String currentAction,
  ) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 12),
              Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.withValues(alpha: 0.4),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const Padding(
                padding: EdgeInsets.all(16),
                child: Text(
                  'Secondary Widget Button Action',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ),
              ListTile(
                leading: const Icon(Icons.camera_alt_rounded, color: AppColors.primaryGreenLight),
                title: const Text('📸 Receipt Camera Scanner', style: TextStyle(fontWeight: FontWeight.w600)),
                subtitle: const Text('1-tap camera capture with automatic parsing'),
                trailing: currentAction == 'scan' ? const Icon(Icons.check, color: AppColors.primaryGreenLight) : null,
                onTap: () {
                  ref.read(settingsProvider.notifier).setWidgetSecondaryAction('scan');
                  Navigator.pop(ctx);
                },
              ),
              ListTile(
                leading: const Icon(Icons.mic_rounded, color: AppColors.infoBlue),
                title: const Text('🎙️ Voice / NLP Assistant', style: TextStyle(fontWeight: FontWeight.w600)),
                subtitle: const Text('Speak or type natural language transactions'),
                trailing: currentAction == 'voice' ? const Icon(Icons.check, color: AppColors.primaryGreenLight) : null,
                onTap: () {
                  ref.read(settingsProvider.notifier).setWidgetSecondaryAction('voice');
                  Navigator.pop(ctx);
                },
              ),
              const SizedBox(height: 16),
            ],
          ),
        );
      },
    );
  }
}
