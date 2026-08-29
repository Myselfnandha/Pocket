import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:uuid/uuid.dart';
import '../../models/wallet_model.dart';
import '../../models/settings_model.dart';
import '../../providers/app_providers.dart';
import '../../services/notification_service.dart';
import '../../theme/app_theme.dart';

class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  final TextEditingController _nameController = TextEditingController();
  String? _selectedCurrencySymbol;
  String? _selectedCurrencyCode;

  // Theme preferences
  AppThemeMode _selectedThemeMode = AppThemeMode.autoTime;
  ManualThemeStyle _selectedThemeStyle = ManualThemeStyle.pureBlack;
  bool _isPureBlack = true;

  // Notification Preferences
  bool _dailyReminderEnabled = true;
  TimeOfDay _dailyReminderTime = const TimeOfDay(hour: 20, minute: 0);
  bool _budgetNearLimitEnabled = true;
  bool _budgetExceededEnabled = true;
  bool _recurringDueEnabled = true;
  bool _monthlySummaryEnabled = true;

  final List<WalletModel> _onboardingWallets = [];

  final List<Map<String, String>> _currencies = [
    {'symbol': '₹', 'code': 'INR', 'name': 'Indian Rupee'},
    {'symbol': '\$', 'code': 'USD', 'name': 'US Dollar'},
    {'symbol': '€', 'code': 'EUR', 'name': 'Euro'},
    {'symbol': '£', 'code': 'GBP', 'name': 'British Pound'},
    {'symbol': '¥', 'code': 'JPY', 'name': 'Japanese Yen'},
    {'symbol': 'AED', 'code': 'AED', 'name': 'UAE Dirham'},
    {'symbol': 'C\$', 'code': 'CAD', 'name': 'Canadian Dollar'},
    {'symbol': 'A\$', 'code': 'AUD', 'name': 'Australian Dollar'},
  ];

  @override
  void dispose() {
    _pageController.dispose();
    _nameController.dispose();
    super.dispose();
  }

  void _nextPage() {
    FocusScope.of(context).unfocus();

    if (_currentPage == 1) {
      // Validate Profile page
      final name = _nameController.text.trim();
      if (name.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Please enter your name'),
            duration: Duration(seconds: 4),
          ),
        );
        return;
      }
      if (_selectedCurrencySymbol == null || _selectedCurrencyCode == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Please select your preferred currency'),
            duration: Duration(seconds: 4),
          ),
        );
        return;
      }
    }

    if (_currentPage < 4) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    } else {
      _finishOnboarding();
    }
  }

  Future<void> _finishOnboarding() async {
    if (_onboardingWallets.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please create at least 1 wallet to get started'),
          duration: Duration(seconds: 4),
        ),
      );
      return;
    }

    final name = _nameController.text.trim();
    final currencySymbol = _selectedCurrencySymbol ?? '₹';
    final currencyCode = _selectedCurrencyCode ?? 'INR';

    // 1. Save all settings & preferences
    await ref.read(settingsProvider.notifier).updateSettings(
          ref.read(settingsProvider).copyWith(
                userName: name,
                currencySymbol: currencySymbol,
                currencyCode: currencyCode,
                themeMode: _selectedThemeMode,
                manualThemeStyle: _selectedThemeStyle,
                isPureBlackEnabled: _isPureBlack,
                dailyReminderEnabled: _dailyReminderEnabled,
                dailyReminderHour: _dailyReminderTime.hour,
                dailyReminderMinute: _dailyReminderTime.minute,
                notifyBudgetNearLimit: _budgetNearLimitEnabled,
                notifyBudgetExceeded: _budgetExceededEnabled,
                notifyRecurringDue: _recurringDueEnabled,
                monthlySummaryEnabled: _monthlySummaryEnabled,
                isOnboarded: true,
              ),
        );

    // 2. Save created onboarding wallets
    final storage = ref.read(storageServiceProvider);
    await storage.saveWallets(_onboardingWallets);
    ref.invalidate(walletsProvider);

    // 3. Request Notification & Alarm Permissions
    try {
      await NotificationService().requestPermissions();
    } catch (_) {}

    if (!mounted) return;
    context.go('/home');
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            // Top Page Indicator Bar (5 steps)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              child: Row(
                children: List.generate(5, (index) {
                  final isActive = index == _currentPage;
                  final isDone = index < _currentPage;
                  return Expanded(
                    child: Container(
                      height: 4,
                      margin: const EdgeInsets.symmetric(horizontal: 3),
                      decoration: BoxDecoration(
                        color: isDone || isActive
                            ? AppColors.primaryGreenLight
                            : (isDark ? const Color(0xFF262626) : const Color(0xFFE0E0E0)),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  );
                }),
              ),
            ),

            // Page View
            Expanded(
              child: PageView(
                controller: _pageController,
                physics: const NeverScrollableScrollPhysics(),
                onPageChanged: (page) => setState(() => _currentPage = page),
                children: [
                  _buildSlide1Welcome(isDark),
                  _buildSlide2Profile(isDark),
                  _buildSlide3Theme(isDark),
                  _buildSlide4Preferences(isDark),
                  _buildSlide5Wallets(isDark),
                ],
              ),
            ),

            // Bottom Navigation Actions
            Padding(
              padding: const EdgeInsets.all(24),
              child: Row(
                children: [
                  if (_currentPage > 0)
                    TextButton(
                      onPressed: () {
                        FocusScope.of(context).unfocus();
                        _pageController.previousPage(
                          duration: const Duration(milliseconds: 300),
                          curve: Curves.easeInOut,
                        );
                      },
                      style: TextButton.styleFrom(
                        foregroundColor: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                      ),
                      child: const Text('Back', style: TextStyle(fontWeight: FontWeight.w600)),
                    ),
                  const Spacer(),
                  ElevatedButton(
                    onPressed: _nextPage,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primaryGreenLight,
                      foregroundColor: Colors.black,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          _currentPage == 4 ? 'Get Started' : 'Continue',
                          style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
                        ),
                        const SizedBox(width: 6),
                        const Icon(Icons.arrow_forward_rounded, size: 18, color: Colors.black),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // --- Slide 1: Welcome ---
  Widget _buildSlide1Welcome(bool isDark) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 28),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 96,
            height: 96,
            decoration: BoxDecoration(
              color: AppColors.primaryGreenLight.withValues(alpha: 0.15),
              shape: BoxShape.circle,
              border: Border.all(color: AppColors.primaryGreenLight.withValues(alpha: 0.3), width: 2),
            ),
            child: const Center(
              child: Text('💳', style: TextStyle(fontSize: 48)),
            ),
          ),
          const SizedBox(height: 32),
          Text(
            'Welcome to Pocket',
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.5,
              color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Next-generation offline personal financial management suite with AMOLED Pure Black aesthetics.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14,
              height: 1.5,
              color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
            ),
          ),
          const SizedBox(height: 28),
          _buildFeaturePill(Icons.bolt_rounded, '⚡ Instant UPI Share-to-Log • Share payment screenshots to auto-parse & log', isDark),
          const SizedBox(height: 10),
          _buildFeaturePill(Icons.lock_outline_rounded, 'Zero cloud storage • 100% offline & private', isDark),
          const SizedBox(height: 10),
          _buildFeaturePill(Icons.autorenew_rounded, 'Automated recurring expenses & smart ledger', isDark),
          const SizedBox(height: 10),
          _buildFeaturePill(Icons.receipt_long_rounded, 'Private receipt capture & contact debt tracking', isDark),
        ],
      ),
    );
  }

  Widget _buildFeaturePill(IconData icon, String label, bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurfaceVariant : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark ? AppColors.darkCardBorder : AppColors.lightCardBorder,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: AppColors.primaryGreenLight),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // --- Slide 2: Profile (Name & Currency) ---
  Widget _buildSlide2Profile(bool isDark) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Set Up Your Profile',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w800,
              color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Enter your name and primary currency to personalize your dashboard.',
            style: TextStyle(
              fontSize: 13,
              color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
            ),
          ),
          const SizedBox(height: 24),

          // Name Input
          Text(
            'YOUR NAME',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.1,
              color: isDark ? const Color(0xFFB0B0B0) : const Color(0xFF666666),
            ),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _nameController,
            textCapitalization: TextCapitalization.words,
            decoration: const InputDecoration(
              prefixIcon: Icon(Icons.person_outline_rounded),
            ),
          ),
          const SizedBox(height: 28),

          // Currency Selection
          Text(
            'PRIMARY CURRENCY',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.1,
              color: isDark ? const Color(0xFFB0B0B0) : const Color(0xFF666666),
            ),
          ),
          const SizedBox(height: 12),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              mainAxisExtent: 64,
              crossAxisSpacing: 10,
              mainAxisSpacing: 10,
            ),
            itemCount: _currencies.length,
            itemBuilder: (context, index) {
              final c = _currencies[index];
              final isSelected = _selectedCurrencyCode == c['code'];

              return InkWell(
                onTap: () {
                  FocusScope.of(context).unfocus();
                  setState(() {
                    _selectedCurrencySymbol = c['symbol'];
                    _selectedCurrencyCode = c['code'];
                  });
                },
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? AppColors.primaryGreenLight.withValues(alpha: 0.15)
                        : (isDark ? AppColors.darkSurfaceVariant : Colors.white),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isSelected
                          ? AppColors.primaryGreenLight
                          : (isDark ? AppColors.darkCardBorder : AppColors.lightCardBorder),
                      width: isSelected ? 1.5 : 1.0,
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          color: isSelected
                              ? AppColors.primaryGreenLight
                              : (isDark ? const Color(0xFF262626) : const Color(0xFFE0E0E0)),
                          shape: BoxShape.circle,
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          c['symbol']!,
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                            color: isSelected ? Colors.black : (isDark ? Colors.white : Colors.black),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              c['code']!,
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                              ),
                            ),
                            Text(
                              c['name']!,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w500,
                                color: isDark ? const Color(0xFFB0B0B0) : const Color(0xFF666666),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  // --- Slide 3: Theme Preference ---
  Widget _buildSlide3Theme(bool isDark) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Choose Visual Theme',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w800,
              color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Select your preferred appearance mode. You can customize this later in Settings.',
            style: TextStyle(
              fontSize: 13,
              color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
            ),
          ),
          const SizedBox(height: 24),

          _buildThemeCard(
            title: 'Auto Adaptive (Day / Night)',
            subtitle: 'Switches automatically: Light by day (6 AM – 6 PM) and Dark by night',
            icon: Icons.schedule_rounded,
            iconColor: AppColors.infoBlue,
            isSelected: _selectedThemeMode == AppThemeMode.autoTime,
            onTap: () => _onThemeSelected(AppThemeMode.autoTime, ManualThemeStyle.pureBlack, true),
            isDark: isDark,
          ),
          const SizedBox(height: 12),

          _buildThemeCard(
            title: 'Pure Black AMOLED',
            subtitle: 'True deep black (#000000) optimized for OLED displays and battery saving',
            icon: Icons.brightness_2_rounded,
            iconColor: AppColors.primaryGreenLight,
            isSelected: _selectedThemeMode == AppThemeMode.manual && _isPureBlack,
            onTap: () => _onThemeSelected(AppThemeMode.manual, ManualThemeStyle.pureBlack, true),
            isDark: isDark,
          ),
          const SizedBox(height: 12),

          _buildThemeCard(
            title: 'Dark Charcoal',
            subtitle: 'Sophisticated matte dark gray interface (#131313)',
            icon: Icons.dark_mode_rounded,
            iconColor: AppColors.accentOrange,
            isSelected: _selectedThemeMode == AppThemeMode.manual && !_isPureBlack && _selectedThemeStyle == ManualThemeStyle.dark,
            onTap: () => _onThemeSelected(AppThemeMode.manual, ManualThemeStyle.dark, false),
            isDark: isDark,
          ),
          const SizedBox(height: 12),

          _buildThemeCard(
            title: 'Light Mode',
            subtitle: 'Clean, high-contrast daylight aesthetic',
            icon: Icons.light_mode_rounded,
            iconColor: AppColors.accentOrange,
            isSelected: _selectedThemeMode == AppThemeMode.manual && _selectedThemeStyle == ManualThemeStyle.light,
            onTap: () => _onThemeSelected(AppThemeMode.manual, ManualThemeStyle.light, false),
            isDark: isDark,
          ),
        ],
      ),
    );
  }

  void _onThemeSelected(AppThemeMode mode, ManualThemeStyle style, bool isPureBlack) {
    setState(() {
      _selectedThemeMode = mode;
      _selectedThemeStyle = style;
      _isPureBlack = isPureBlack;
    });
    ref.read(settingsProvider.notifier).updateSettings(
          ref.read(settingsProvider).copyWith(
                themeMode: mode,
                manualThemeStyle: style,
                isPureBlackEnabled: isPureBlack,
              ),
        );
  }

  Widget _buildThemeCard({
    required String title,
    required String subtitle,
    required IconData icon,
    required Color iconColor,
    required bool isSelected,
    required VoidCallback onTap,
    required bool isDark,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.primaryGreenLight.withValues(alpha: 0.12)
              : (isDark ? AppColors.darkSurfaceVariant : Colors.white),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected
                ? AppColors.primaryGreenLight
                : (isDark ? AppColors.darkCardBorder : AppColors.lightCardBorder),
            width: isSelected ? 1.8 : 1.0,
          ),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: iconColor.withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: iconColor, size: 22),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: isDark ? const Color(0xFFB0B0B0) : const Color(0xFF555555),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            if (isSelected)
              const Icon(Icons.check_circle_rounded, color: AppColors.primaryGreenLight, size: 22)
            else
              Icon(Icons.radio_button_unchecked_rounded, color: isDark ? AppColors.darkCardBorder : AppColors.lightCardBorder, size: 22),
          ],
        ),
      ),
    );
  }

  // --- Slide 4: Notifications & Reminders Preference ---
  Widget _buildSlide4Preferences(bool isDark) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Smart Reminders & Alerts',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w800,
              color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Keep your budget on track with automatic reminders and threshold warnings.',
            style: TextStyle(
              fontSize: 13.5,
              fontWeight: FontWeight.w500,
              color: isDark ? const Color(0xFFCCCCCC) : const Color(0xFF4A4A4A),
            ),
          ),
          const SizedBox(height: 24),

          // Daily Spending Reminder with Time Picker
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: isDark ? AppColors.darkSurfaceVariant : Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isDark ? AppColors.darkCardBorder : AppColors.lightCardBorder,
              ),
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppColors.primaryGreenLight.withValues(alpha: 0.15),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.alarm_rounded, color: AppColors.primaryGreenLight, size: 20),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Daily Spending Check-in',
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 14,
                              color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Reminder to log today\'s expenses',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                              color: isDark ? const Color(0xFFB0B0B0) : const Color(0xFF555555),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Switch(
                      value: _dailyReminderEnabled,
                      activeThumbColor: AppColors.primaryGreenLight,
                      onChanged: (val) => setState(() => _dailyReminderEnabled = val),
                    ),
                  ],
                ),
                if (_dailyReminderEnabled) ...[
                  const SizedBox(height: 10),
                  Divider(height: 1, color: isDark ? AppColors.darkCardBorder : AppColors.lightCardBorder),
                  const SizedBox(height: 10),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Reminder Time',
                        style: TextStyle(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w700,
                          color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                        ),
                      ),
                      TextButton.icon(
                        style: TextButton.styleFrom(
                          visualDensity: VisualDensity.compact,
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        ),
                        icon: const Icon(Icons.access_time_rounded, size: 16, color: AppColors.primaryGreenLight),
                        label: Text(
                          _dailyReminderTime.format(context),
                          style: const TextStyle(fontWeight: FontWeight.w800, color: AppColors.primaryGreenLight),
                        ),
                        onPressed: () async {
                          final picked = await showTimePicker(
                            context: context,
                            initialTime: _dailyReminderTime,
                          );
                          if (picked != null) {
                            setState(() => _dailyReminderTime = picked);
                          }
                        },
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 14),

          // Budget Alerts Card
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: isDark ? AppColors.darkSurfaceVariant : Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isDark ? AppColors.darkCardBorder : AppColors.lightCardBorder,
              ),
            ),
            child: Column(
              children: [
                _buildPreferenceSwitchRow(
                  icon: Icons.warning_amber_rounded,
                  iconColor: AppColors.accentOrange,
                  title: 'Budget 80% Threshold Warning',
                  subtitle: 'Notify when monthly spending hits 80%',
                  value: _budgetNearLimitEnabled,
                  onChanged: (v) => setState(() => _budgetNearLimitEnabled = v),
                  isDark: isDark,
                ),
                const SizedBox(height: 8),
                Divider(height: 1, color: isDark ? AppColors.darkCardBorder : AppColors.lightCardBorder),
                const SizedBox(height: 8),
                _buildPreferenceSwitchRow(
                  icon: Icons.error_outline_rounded,
                  iconColor: AppColors.expenseRed,
                  title: 'Budget 100% Exceeded Alert',
                  subtitle: 'Notify immediately when budget is exceeded',
                  value: _budgetExceededEnabled,
                  onChanged: (v) => setState(() => _budgetExceededEnabled = v),
                  isDark: isDark,
                ),
                const SizedBox(height: 8),
                Divider(height: 1, color: isDark ? AppColors.darkCardBorder : AppColors.lightCardBorder),
                const SizedBox(height: 8),
                _buildPreferenceSwitchRow(
                  icon: Icons.autorenew_rounded,
                  iconColor: AppColors.primaryGreenLight,
                  title: 'Recurring Bill Due Alerts',
                  subtitle: 'Remind before recurring subscriptions & bills',
                  value: _recurringDueEnabled,
                  onChanged: (v) => setState(() => _recurringDueEnabled = v),
                  isDark: isDark,
                ),
                const SizedBox(height: 8),
                Divider(height: 1, color: isDark ? AppColors.darkCardBorder : AppColors.lightCardBorder),
                const SizedBox(height: 8),
                _buildPreferenceSwitchRow(
                  icon: Icons.insights_rounded,
                  iconColor: AppColors.infoBlue,
                  title: 'Monthly Financial Summary',
                  subtitle: 'Automated breakdown report at month end',
                  value: _monthlySummaryEnabled,
                  onChanged: (v) => setState(() => _monthlySummaryEnabled = v),
                  isDark: isDark,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPreferenceSwitchRow({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
    required bool isDark,
  }) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: iconColor.withValues(alpha: 0.15),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: iconColor, size: 18),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 13.5,
                  color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: isDark ? const Color(0xFFB0B0B0) : const Color(0xFF555555),
                ),
              ),
            ],
          ),
        ),
        Switch(
          value: value,
          activeThumbColor: AppColors.primaryGreenLight,
          onChanged: onChanged,
        ),
      ],
    );
  }

  // --- Slide 5: Add First Wallet ---
  Widget _buildSlide5Wallets(bool isDark) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Create Your First Wallet',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w800,
              color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'You need at least 1 wallet (Cash, Bank, or UPI) to record transactions.',
            style: TextStyle(
              fontSize: 13,
              color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
            ),
          ),
          const SizedBox(height: 20),

          // Created Wallets List
          if (_onboardingWallets.isNotEmpty) ...[
            ...List.generate(_onboardingWallets.length, (index) {
              final w = _onboardingWallets[index];
              return Container(
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: isDark ? AppColors.darkSurfaceVariant : Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: isDark ? AppColors.darkCardBorder : AppColors.lightCardBorder,
                  ),
                ),
                child: Row(
                  children: [
                    Text(w.icon, style: const TextStyle(fontSize: 24)),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            w.name,
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 14,
                              color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Starting: ${_selectedCurrencySymbol ?? '₹'}${w.initialBalance.toStringAsFixed(2)}',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                              color: isDark ? const Color(0xFFB0B0B0) : const Color(0xFF555555),
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close_rounded, size: 18, color: AppColors.expenseRed),
                      onPressed: () => setState(() => _onboardingWallets.removeAt(index)),
                    ),
                  ],
                ),
              );
            }),
            const SizedBox(height: 12),
          ],

          // Add Wallet Button
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 14),
                side: const BorderSide(color: AppColors.primaryGreenLight, width: 1.5),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
              icon: const Icon(Icons.add_circle_outline_rounded, color: AppColors.primaryGreenLight),
              label: const Text(
                '+ Add Wallet',
                style: TextStyle(
                  color: AppColors.primaryGreenLight,
                  fontWeight: FontWeight.w700,
                  fontSize: 14,
                ),
              ),
              onPressed: () => _showAddWalletModal(context, isDark),
            ),
          ),
        ],
      ),
    );
  }

  void _showAddWalletModal(BuildContext context, bool isDark) {
    WalletType? selectedType;
    String selectedIcon = '🏦';
    final nameCtrl = TextEditingController();
    final balanceCtrl = TextEditingController();
    final limitCtrl = TextEditingController();
    bool enableLimit = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: isDark ? AppColors.darkSurfaceVariant : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) => Padding(
          padding: EdgeInsets.only(
            left: 24,
            right: 24,
            top: 24,
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Set Up New Wallet', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 16),

                // Wallet Type ChoiceChips (Unselected by default)
                const Text('Wallet Type', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: WalletType.values.map((type) {
                    final isSel = selectedType == type;
                    return ChoiceChip(
                      label: Text(type.name.toUpperCase()),
                      selected: isSel,
                      selectedColor: AppColors.primaryGreenLight.withValues(alpha: 0.25),
                      onSelected: (_) {
                        setModalState(() {
                          selectedType = type;
                          if (type == WalletType.cash) {
                            selectedIcon = '💵';
                            nameCtrl.text = 'Cash';
                          } else if (type == WalletType.bank) {
                            selectedIcon = '🏦';
                            nameCtrl.text = 'Bank Account';
                          } else if (type == WalletType.upi) {
                            selectedIcon = '📱';
                            nameCtrl.text = 'UPI';
                          } else if (type == WalletType.creditCard) {
                            selectedIcon = '💳';
                            nameCtrl.text = 'Credit Card';
                          } else if (type == WalletType.savings) {
                            selectedIcon = '💰';
                            nameCtrl.text = 'Savings';
                          }
                          nameCtrl.selection = TextSelection(baseOffset: 0, extentOffset: nameCtrl.text.length);
                        });
                      },
                    );
                  }).toList(),
                ),
                const SizedBox(height: 14),

                const Text('Wallet Name', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                const SizedBox(height: 6),
                TextField(
                  controller: nameCtrl,
                  onTap: () {
                    if (nameCtrl.text.isNotEmpty) {
                      nameCtrl.selection = TextSelection(baseOffset: 0, extentOffset: nameCtrl.text.length);
                    }
                  },
                  decoration: const InputDecoration(
                    hintText: 'Enter wallet name',
                  ),
                ),
                const SizedBox(height: 14),

                Text('Starting Balance (${_selectedCurrencySymbol ?? '₹'})', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                const SizedBox(height: 6),
                TextField(
                  controller: balanceCtrl,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: InputDecoration(
                    prefixText: '${_selectedCurrencySymbol ?? '₹'} ',
                    prefixStyle: TextStyle(color: isDark ? AppColors.darkTextTertiary : AppColors.lightTextTertiary),
                    hintText: '0.00',
                    hintStyle: TextStyle(color: isDark ? AppColors.darkTextTertiary.withValues(alpha: 0.4) : AppColors.lightTextTertiary.withValues(alpha: 0.4)),
                  ),
                ),
                const SizedBox(height: 14),

                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Set Spending Limit', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                    Switch(
                      value: enableLimit,
                      activeThumbColor: AppColors.primaryGreenLight,
                      onChanged: (val) => setModalState(() => enableLimit = val),
                    ),
                  ],
                ),
                if (enableLimit) ...[
                  const SizedBox(height: 6),
                  TextField(
                    controller: limitCtrl,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: InputDecoration(
                      prefixText: '${_selectedCurrencySymbol ?? '₹'} ',
                      prefixStyle: TextStyle(color: isDark ? AppColors.darkTextTertiary : AppColors.lightTextTertiary),
                      hintText: 'Monthly spending cap',
                      hintStyle: TextStyle(color: isDark ? AppColors.darkTextTertiary.withValues(alpha: 0.4) : AppColors.lightTextTertiary.withValues(alpha: 0.4)),
                    ),
                  ),
                ],
                const SizedBox(height: 20),

                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primaryGreenLight,
                      foregroundColor: Colors.black,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    onPressed: () {
                      final name = nameCtrl.text.trim();
                      final balance = double.tryParse(balanceCtrl.text.trim()) ?? 0.0;
                      final limit = enableLimit ? double.tryParse(limitCtrl.text.trim()) : null;

                      if (name.isEmpty) return;

                      setState(() {
                        _onboardingWallets.add(
                          WalletModel(
                            id: const Uuid().v4(),
                            name: name,
                            walletType: selectedType ?? WalletType.bank,
                            icon: selectedIcon,
                            initialBalance: balance,
                            currentBalance: balance,
                            colorValue: 0xFF2E7D32,
                            spendingLimit: limit,
                          ),
                        );
                      });
                      Navigator.pop(ctx);
                    },
                    child: const Text('Save Wallet', style: TextStyle(fontWeight: FontWeight.bold)),
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
