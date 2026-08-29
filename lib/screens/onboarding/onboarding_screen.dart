import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:uuid/uuid.dart';
import '../../models/budget_model.dart';
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
  final TextEditingController _phoneController = TextEditingController();
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
  final Map<String, double> _onboardingBudgets = {};

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
    _phoneController.dispose();
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

    if (_currentPage == 3) {
      // Validate Wallets page
      if (_onboardingWallets.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Please add at least 1 wallet to get started'),
            duration: Duration(seconds: 4),
          ),
        );
        return;
      }
    }

    if (_currentPage < 5) {
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
    final phone = _phoneController.text.trim();
    final currencySymbol = _selectedCurrencySymbol ?? '₹';
    final currencyCode = _selectedCurrencyCode ?? 'INR';

    // 1. Save all settings & preferences
    await ref.read(settingsProvider.notifier).updateSettings(
          ref.read(settingsProvider).copyWith(
                userName: name,
                userPhoneNumber: phone.isNotEmpty ? phone : null,
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

    // 3. Save configured category budgets
    final now = DateTime.now();
    final List<CategoryBudgetModel> budgetsToSave = [];
    _onboardingBudgets.forEach((catId, limit) {
      if (limit > 0) {
        budgetsToSave.add(
          CategoryBudgetModel(
            id: const Uuid().v4(),
            categoryId: catId,
            monthlyLimit: limit,
            createdAt: now,
            updatedAt: now,
          ),
        );
      }
    });
    await storage.saveCategoryBudgets(budgetsToSave);
    ref.invalidate(categoryBudgetsProvider);

    // 4. Request Notification & Alarm Permissions
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
            // Top Page Indicator Bar (6 steps)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              child: Row(
                children: List.generate(6, (index) {
                  final isActive = index == _currentPage;
                  final isDone = index < _currentPage;
                  return Expanded(
                    child: Container(
                      height: 4,
                      margin: const EdgeInsets.symmetric(horizontal: 2.5),
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

            // Page View (6 Slides)
            Expanded(
              child: PageView(
                controller: _pageController,
                physics: const NeverScrollableScrollPhysics(),
                onPageChanged: (page) => setState(() => _currentPage = page),
                children: [
                  _buildSlide1Welcome(isDark),
                  _buildSlide2Profile(isDark),
                  _buildSlide3Theme(isDark),
                  _buildSlide4Wallets(isDark),
                  _buildSlide5CategoryBudgets(isDark),
                  _buildSlide6Preferences(isDark),
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
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          _currentPage == 5 ? 'Get Started' : 'Continue',
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
        borderRadius: BorderRadius.circular(14),
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

  // --- Slide 2: Profile (Name, Phone & Currency) ---
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
            'Enter your identity details and primary currency to personalize your ledger.',
            style: TextStyle(
              fontSize: 13,
              color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
            ),
          ),
          const SizedBox(height: 20),

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
            decoration: InputDecoration(
              prefixIcon: const Icon(Icons.person_outline_rounded),
              hintText: 'Enter your full name',
              filled: true,
              fillColor: isDark ? AppColors.darkSurfaceVariant : Colors.grey.shade100,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
            ),
          ),
          const SizedBox(height: 16),

          // Mobile Number Input (Optional with Country Code)
          Text(
            'MOBILE NUMBER (FOR IDENTITY)',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.1,
              color: isDark ? const Color(0xFFB0B0B0) : const Color(0xFF666666),
            ),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _phoneController,
            keyboardType: TextInputType.phone,
            decoration: InputDecoration(
              prefixIcon: const Icon(Icons.phone_outlined),
              hintText: '+91 98765 43210 (Optional)',
              filled: true,
              fillColor: isDark ? AppColors.darkSurfaceVariant : Colors.grey.shade100,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
            ),
          ),
          const SizedBox(height: 24),

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
                borderRadius: BorderRadius.circular(14),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? AppColors.primaryGreenLight.withValues(alpha: 0.15)
                        : (isDark ? AppColors.darkSurfaceVariant : Colors.white),
                    borderRadius: BorderRadius.circular(14),
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
                                fontSize: 10,
                                color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
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

  // --- Slide 3: Theme ---
  Widget _buildSlide3Theme(bool isDark) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
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
            'Select how Pocket renders across day, night, and OLED displays.',
            style: TextStyle(
              fontSize: 13,
              color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
            ),
          ),
          const SizedBox(height: 24),

          _buildThemeOption(
            title: 'Auto (Time-Based)',
            subtitle: 'Crisp Light Mode during day (6 AM - 6 PM) and Pure AMOLED Black at night',
            icon: Icons.auto_mode_rounded,
            isSelected: _selectedThemeMode == AppThemeMode.autoTime,
            isDark: isDark,
            onTap: () => setState(() => _selectedThemeMode = AppThemeMode.autoTime),
          ),
          const SizedBox(height: 12),
          _buildThemeOption(
            title: 'AMOLED Pure Black (Recommended)',
            subtitle: '#000000 Pitch Black surfaces for infinite contrast & battery saving',
            icon: Icons.dark_mode_rounded,
            isSelected: _selectedThemeMode == AppThemeMode.manual && _selectedThemeStyle == ManualThemeStyle.pureBlack,
            isDark: isDark,
            onTap: () {
              setState(() {
                _selectedThemeMode = AppThemeMode.manual;
                _selectedThemeStyle = ManualThemeStyle.pureBlack;
                _isPureBlack = true;
              });
            },
          ),
          const SizedBox(height: 12),
          _buildThemeOption(
            title: 'Crisp Light Mode',
            subtitle: 'Bright, clean aesthetic with subtle green accents',
            icon: Icons.light_mode_rounded,
            isSelected: _selectedThemeMode == AppThemeMode.manual && _selectedThemeStyle == ManualThemeStyle.light,
            isDark: isDark,
            onTap: () {
              setState(() {
                _selectedThemeMode = AppThemeMode.manual;
                _selectedThemeStyle = ManualThemeStyle.light;
              });
            },
          ),
        ],
      ),
    );
  }

  Widget _buildThemeOption({
    required String title,
    required String subtitle,
    required IconData icon,
    required bool isSelected,
    required bool isDark,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.primaryGreenLight.withValues(alpha: 0.15)
              : (isDark ? AppColors.darkSurfaceVariant : Colors.white),
          borderRadius: BorderRadius.circular(16),
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
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: isSelected ? AppColors.primaryGreenLight : (isDark ? const Color(0xFF262626) : const Color(0xFFE0E0E0)),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: isSelected ? Colors.black : (isDark ? Colors.white : Colors.black), size: 20),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 12,
                      color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
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

  // --- Slide 4: Wallets & Accounts (with Last 4 Digits) ---
  Widget _buildSlide4Wallets(bool isDark) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Create Your Accounts',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w800,
              color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Add your bank accounts, cash wallet, or cards (with last 4 digits for instant bank identification).',
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
                  borderRadius: BorderRadius.circular(16),
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
                          Row(
                            children: [
                              Text(
                                w.name,
                                style: TextStyle(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 14,
                                  color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                                ),
                              ),
                              if (w.maskedAccountNumber.isNotEmpty) ...[
                                const SizedBox(width: 6),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                                  decoration: BoxDecoration(
                                    color: isDark ? const Color(0xFF262626) : const Color(0xFFEFEFEF),
                                    borderRadius: BorderRadius.circular(5),
                                  ),
                                  child: Text(
                                    w.maskedAccountNumber,
                                    style: TextStyle(
                                      fontSize: 9.5,
                                      fontWeight: FontWeight.w600,
                                      color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Starting: ${_selectedCurrencySymbol ?? '₹'}${w.initialBalance.toStringAsFixed(2)} • ${w.walletType.name.toUpperCase()}',
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
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
              icon: const Icon(Icons.add_circle_outline_rounded, color: AppColors.primaryGreenLight),
              label: const Text(
                '+ Add Account / Bank',
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
    WalletType selectedType = WalletType.bank;
    String selectedIcon = '🏦';
    final nameCtrl = TextEditingController();
    final last4Ctrl = TextEditingController();
    final balanceCtrl = TextEditingController();

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
                const Text('Add Account', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 16),

                // Wallet Type ChoiceChips
                const Text('Account Type', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
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
                        });
                      },
                    );
                  }).toList(),
                ),
                const SizedBox(height: 14),

                const Text('Account Name', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                const SizedBox(height: 6),
                TextField(
                  controller: nameCtrl,
                  decoration: const InputDecoration(
                    hintText: 'e.g. ICICI Bank, Cash in Wallet',
                  ),
                ),
                const SizedBox(height: 14),

                // Last 4 Digits of Account Number (Required for Bank & Card)
                if (selectedType == WalletType.bank || selectedType == WalletType.creditCard || selectedType == WalletType.savings) ...[
                  const Text('Last 4 Digits of Account/Card (Required for Bank)', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 6),
                  TextField(
                    controller: last4Ctrl,
                    keyboardType: TextInputType.number,
                    maxLength: 4,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    decoration: InputDecoration(
                      prefixText: '•••• ',
                      counterText: '',
                      hintText: 'e.g. 4821',
                      filled: true,
                      fillColor: isDark ? AppColors.darkSurfaceVariant : Colors.grey.shade100,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
                    ),
                  ),
                  const SizedBox(height: 14),
                ],

                Text('Starting Balance (${_selectedCurrencySymbol ?? '₹'})', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                const SizedBox(height: 6),
                TextField(
                  controller: balanceCtrl,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: InputDecoration(
                    prefixText: '${_selectedCurrencySymbol ?? '₹'} ',
                    hintText: '0.00',
                  ),
                ),
                const SizedBox(height: 20),

                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primaryGreenLight,
                      foregroundColor: Colors.black,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                    onPressed: () {
                      final name = nameCtrl.text.trim();
                      final balance = double.tryParse(balanceCtrl.text.trim()) ?? 0.0;
                      final last4 = last4Ctrl.text.trim();

                      if (name.isEmpty) return;

                      if ((selectedType == WalletType.bank || selectedType == WalletType.creditCard) && last4.isEmpty) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Please enter the last 4 digits to identify this bank account'),
                            duration: Duration(seconds: 4),
                          ),
                        );
                        return;
                      }

                      setState(() {
                        _onboardingWallets.add(
                          WalletModel(
                            id: const Uuid().v4(),
                            name: name,
                            walletType: selectedType,
                            icon: selectedIcon,
                            accountNumber: last4.isNotEmpty ? last4 : null,
                            initialBalance: balance,
                            currentBalance: balance,
                            colorValue: 0xFF2E7D32,
                            isDefault: _onboardingWallets.isEmpty,
                          ),
                        );
                      });
                      Navigator.pop(ctx);
                    },
                    child: const Text('Save Account', style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // --- Slide 5: Categories & Monthly Budgets Setup ---
  Widget _buildSlide5CategoryBudgets(bool isDark) {
    final symbol = _selectedCurrencySymbol ?? '₹';
    final defaultCategories = [
      {'id': 'cat_food', 'name': 'Food & Dining', 'icon': '🍔'},
      {'id': 'cat_groceries', 'name': 'Groceries & Mart', 'icon': '🛒'},
      {'id': 'cat_shopping', 'name': 'Shopping & Retail', 'icon': '🛍️'},
      {'id': 'cat_transport', 'name': 'Transport & Fuel', 'icon': '🚗'},
      {'id': 'cat_bills', 'name': 'Bills & Utilities', 'icon': '⚡'},
      {'id': 'cat_entertainment', 'name': 'Entertainment', 'icon': '🍿'},
      {'id': 'cat_health', 'name': 'Health & Medical', 'icon': '💊'},
    ];

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Configure Monthly Budgets',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w800,
              color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Set monthly spending limits for each category in 1 tap to receive smart budget alerts.',
            style: TextStyle(
              fontSize: 13,
              color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
            ),
          ),
          const SizedBox(height: 16),

          ...defaultCategories.map((cat) {
            final catId = cat['id']!;
            final currentBudget = _onboardingBudgets[catId] ?? 0.0;
            final isEnabled = currentBudget > 0;

            return Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: isDark ? AppColors.darkSurfaceVariant : Colors.white,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(
                  color: isEnabled
                      ? AppColors.primaryGreenLight.withValues(alpha: 0.3)
                      : (isDark ? AppColors.darkCardBorder : AppColors.lightCardBorder),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Text(cat['icon']!, style: const TextStyle(fontSize: 20)),
                          const SizedBox(width: 10),
                          Text(
                            cat['name']!,
                            style: TextStyle(
                              fontSize: 14.5,
                              fontWeight: FontWeight.w700,
                              color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                            ),
                          ),
                        ],
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: isEnabled
                              ? AppColors.primaryGreenLight.withValues(alpha: 0.18)
                              : (isDark ? const Color(0xFF262626) : const Color(0xFFE0E0E0)),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          isEnabled ? '$symbol${currentBudget.toStringAsFixed(0)} / mo' : 'No Limit',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                            color: isEnabled ? AppColors.primaryGreenLight : Colors.grey,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  // Preset Budget Chips
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        _buildPresetBudgetChip(catId, 0, 'Off', currentBudget == 0, isDark),
                        const SizedBox(width: 6),
                        _buildPresetBudgetChip(catId, 2000, '${symbol}2k', currentBudget == 2000, isDark),
                        const SizedBox(width: 6),
                        _buildPresetBudgetChip(catId, 4000, '${symbol}4k', currentBudget == 4000, isDark),
                        const SizedBox(width: 6),
                        _buildPresetBudgetChip(catId, 6000, '${symbol}6k', currentBudget == 6000, isDark),
                        const SizedBox(width: 6),
                        _buildPresetBudgetChip(catId, 10000, '${symbol}10k', currentBudget == 10000, isDark),
                      ],
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildPresetBudgetChip(String catId, double amount, String label, bool isSelected, bool isDark) {
    return InkWell(
      onTap: () {
        setState(() {
          _onboardingBudgets[catId] = amount;
        });
      },
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.primaryGreenLight
              : (isDark ? const Color(0xFF262626) : const Color(0xFFEFEFEF)),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11.5,
            fontWeight: FontWeight.w700,
            color: isSelected ? Colors.black : (isDark ? Colors.white70 : Colors.black87),
          ),
        ),
      ),
    );
  }

  // --- Slide 6: Smart Preferences & Notification Alerts ---
  Widget _buildSlide6Preferences(bool isDark) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Smart Alerts & Automation',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w800,
              color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Configure daily reminders and proactive budget warning notifications.',
            style: TextStyle(
              fontSize: 13,
              color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
            ),
          ),
          const SizedBox(height: 20),

          // Daily Reminder Card
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: isDark ? AppColors.darkSurfaceVariant : Colors.white,
              borderRadius: BorderRadius.circular(18),
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
                      child: const Icon(Icons.notifications_active_rounded, color: AppColors.primaryGreenLight, size: 18),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Daily Logging Reminder',
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 14,
                              color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Daily prompt to review spend',
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
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: isDark ? AppColors.darkCardBorder : AppColors.lightCardBorder,
              ),
            ),
            child: Column(
              children: [
                _buildPreferenceSwitchRow(
                  icon: Icons.warning_amber_rounded,
                  iconColor: AppColors.accentOrange,
                  title: 'Budget 80% Warning',
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
                  subtitle: 'Notify immediately when limit is reached',
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
}
