import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:uuid/uuid.dart';
import '../../models/budget_model.dart';
import '../../models/category_model.dart';
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
  late List<CategoryModel> _onboardingCategories;
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
  void initState() {
    super.initState();
    _onboardingCategories = List.from(defaultCategories);
  }

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

    if (_currentPage < 6) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 350),
        curve: Curves.fastOutSlowIn,
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

    // 3. Save categories (with any added/edited categories)
    await storage.saveCategories(_onboardingCategories);
    ref.invalidate(categoriesProvider);

    // 4. Save configured category budgets
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

    // 5. Request Notification & Alarm Permissions
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
            // Top Futuristic Animated Page Indicator Bar (7 steps)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(7, (index) {
                  final isActive = index == _currentPage;
                  final isDone = index < _currentPage;
                  return AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    curve: Curves.fastOutSlowIn,
                    height: 5,
                    width: isActive ? 28 : (isDone ? 10 : 6),
                    margin: const EdgeInsets.symmetric(horizontal: 3),
                    decoration: BoxDecoration(
                      color: isActive
                          ? AppColors.primaryGreenLight
                          : (isDone
                              ? AppColors.primaryGreen.withValues(alpha: 0.6)
                              : (isDark ? const Color(0xFF2E2E2E) : const Color(0xFFE0E0E0))),
                      borderRadius: BorderRadius.circular(3),
                      boxShadow: isActive
                          ? [
                              BoxShadow(
                                color: AppColors.primaryGreenLight.withValues(alpha: 0.5),
                                blurRadius: 8,
                                spreadRadius: 1,
                              )
                            ]
                          : null,
                    ),
                  );
                }),
              ),
            ),

            // Page View (7 Slides)
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
                  _buildSlide5Categories(isDark),
                  _buildSlide6CategoryBudgets(isDark),
                  _buildSlide7Preferences(isDark),
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
                          duration: const Duration(milliseconds: 350),
                          curve: Curves.fastOutSlowIn,
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
                          _currentPage == 6 ? 'Get Started' : 'Continue',
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
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
                color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // --- Slide 2: User Profile & Currency ---
  Widget _buildSlide2Profile(bool isDark) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Your Profile',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w800,
              color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'What should we call you, and which currency do you transact in?',
            style: TextStyle(
              fontSize: 13,
              color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
            ),
          ),
          const SizedBox(height: 24),
          const Text('Your Name', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          TextField(
            controller: _nameController,
            textCapitalization: TextCapitalization.words,
            decoration: InputDecoration(
              hintText: 'Enter your name',
              prefixIcon: const Icon(Icons.person_outline_rounded, color: AppColors.primaryGreenLight),
              filled: true,
              fillColor: isDark ? AppColors.darkSurfaceVariant : Colors.white,
            ),
          ),
          const SizedBox(height: 20),

          // User Mobile Number Input
          const Text('Mobile Number (Optional)', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          TextField(
            controller: _phoneController,
            keyboardType: TextInputType.phone,
            decoration: InputDecoration(
              hintText: 'e.g. 9876543210',
              prefixText: '+91 ',
              prefixIcon: const Icon(Icons.phone_iphone_rounded, color: AppColors.primaryGreenLight),
              filled: true,
              fillColor: isDark ? AppColors.darkSurfaceVariant : Colors.white,
            ),
          ),
          const SizedBox(height: 20),

          const Text('Select Currency', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
          const SizedBox(height: 12),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              mainAxisSpacing: 10,
              crossAxisSpacing: 10,
              childAspectRatio: 2.2,
            ),
            itemCount: _currencies.length,
            itemBuilder: (context, index) {
              final c = _currencies[index];
              final isSelected = _selectedCurrencyCode == c['code'];
              return InkWell(
                onTap: () {
                  setState(() {
                    _selectedCurrencySymbol = c['symbol'];
                    _selectedCurrencyCode = c['code'];
                  });
                },
                borderRadius: BorderRadius.circular(14),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? AppColors.primaryGreenLight.withValues(alpha: 0.15)
                        : (isDark ? AppColors.darkSurfaceVariant : Colors.white),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: isSelected
                          ? AppColors.primaryGreenLight
                          : (isDark ? AppColors.darkCardBorder : AppColors.lightCardBorder),
                      width: isSelected ? 1.5 : 1,
                    ),
                  ),
                  child: Row(
                    children: [
                      Text(
                        c['symbol']!,
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                          color: isSelected ? AppColors.primaryGreenLight : (isDark ? Colors.white : Colors.black),
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
                                fontWeight: FontWeight.bold,
                                color: isSelected ? AppColors.primaryGreenLight : (isDark ? Colors.white : Colors.black),
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

  // --- Slide 3: Theme Preferences ---
  Widget _buildSlide3Theme(bool isDark) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Theme & Display',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w800,
              color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Choose your visual appearance and AMOLED display optimization.',
            style: TextStyle(
              fontSize: 13,
              color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
            ),
          ),
          const SizedBox(height: 24),

          _buildThemeModeCard(
            title: 'Auto Mode (Time-Based)',
            subtitle: 'Automatically switches to Light (6AM-6PM) & Dark (6PM-6AM)',
            icon: Icons.auto_mode_rounded,
            isSelected: _selectedThemeMode == AppThemeMode.autoTime,
            onTap: () => setState(() => _selectedThemeMode = AppThemeMode.autoTime),
            isDark: isDark,
          ),
          const SizedBox(height: 12),

          _buildThemeModeCard(
            title: 'Dark Theme',
            subtitle: 'Always dark background with soft mint green accents',
            icon: Icons.dark_mode_rounded,
            isSelected: _selectedThemeMode == AppThemeMode.manual && _selectedThemeStyle == ManualThemeStyle.dark,
            onTap: () => setState(() {
              _selectedThemeMode = AppThemeMode.manual;
              _selectedThemeStyle = ManualThemeStyle.dark;
            }),
            isDark: isDark,
          ),
          const SizedBox(height: 12),

          _buildThemeModeCard(
            title: 'Light Theme',
            subtitle: 'Crisp, clean bright appearance with high contrast',
            icon: Icons.light_mode_rounded,
            isSelected: _selectedThemeMode == AppThemeMode.manual && _selectedThemeStyle == ManualThemeStyle.light,
            onTap: () => setState(() {
              _selectedThemeMode = AppThemeMode.manual;
              _selectedThemeStyle = ManualThemeStyle.light;
            }),
            isDark: isDark,
          ),
          const SizedBox(height: 24),

          // AMOLED Pure Black Toggle
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: isDark ? AppColors.darkSurfaceVariant : Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isDark ? AppColors.darkCardBorder : AppColors.lightCardBorder,
              ),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: const BoxDecoration(
                    color: Colors.black,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.brightness_2_rounded, color: AppColors.primaryGreenLight, size: 18),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Midnight Pure Black (#000000)',
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 13.5,
                          color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'True #000000 pixels for maximum battery savings',
                        style: TextStyle(
                          fontSize: 11.5,
                          color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                Switch(
                  value: _isPureBlack,
                  activeThumbColor: AppColors.primaryGreenLight,
                  onChanged: (val) => setState(() => _isPureBlack = val),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildThemeModeCard({
    required String title,
    required String subtitle,
    required IconData icon,
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
            width: isSelected ? 1.5 : 1,
          ),
        ),
        child: Row(
          children: [
            Icon(icon, color: isSelected ? AppColors.primaryGreenLight : (isDark ? Colors.white70 : Colors.black87)),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
                      color: isSelected ? AppColors.primaryGreenLight : (isDark ? Colors.white : Colors.black),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 11.5,
                      color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                    ),
                  ),
                ],
              ),
            ),
            if (isSelected)
              const Icon(Icons.check_circle_rounded, color: AppColors.primaryGreenLight, size: 20),
          ],
        ),
      ),
    );
  }

  // --- Slide 4: Wallets / Accounts Setup ---
  Widget _buildSlide4Wallets(bool isDark) {
    final symbol = _selectedCurrencySymbol ?? '₹';

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Add Your Accounts',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w800,
              color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Create your bank accounts or cash in hand to track transactions.',
            style: TextStyle(
              fontSize: 13,
              color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
            ),
          ),
          const SizedBox(height: 20),

          // Created Wallets List
          if (_onboardingWallets.isNotEmpty) ...[
            ..._onboardingWallets.map((w) {
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
                              Text(w.name, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
                              if (w.maskedAccountNumber.isNotEmpty) ...[
                                const SizedBox(width: 6),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                                  decoration: BoxDecoration(
                                    color: isDark ? Colors.white10 : Colors.black.withValues(alpha: 0.05),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    w.maskedAccountNumber,
                                    style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700),
                                  ),
                                ),
                              ],
                            ],
                          ),
                          Text(
                            '$symbol${w.currentBalance.toStringAsFixed(2)}',
                            style: const TextStyle(color: AppColors.primaryGreenLight, fontWeight: FontWeight.w600, fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close_rounded, size: 18, color: Colors.grey),
                      onPressed: () {
                        setState(() {
                          _onboardingWallets.removeWhere((item) => item.id == w.id);
                        });
                      },
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
                foregroundColor: AppColors.primaryGreenLight,
                side: const BorderSide(color: AppColors.primaryGreenLight, width: 1.5),
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
              icon: const Icon(Icons.add_rounded),
              label: const Text('Add Account / Wallet', style: TextStyle(fontWeight: FontWeight.w700)),
              onPressed: () => _showAddWalletDialog(isDark),
            ),
          ),
        ],
      ),
    );
  }

  void _showAddWalletDialog(bool isDark) {
    final nameCtrl = TextEditingController(text: 'Bank Account');
    final balanceCtrl = TextEditingController();
    final last4Ctrl = TextEditingController();
    WalletType selectedType = WalletType.bank;
    String selectedIcon = '🏦';

    showModalBottomSheet(
      context: context,
      useRootNavigator: true,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => Container(
          padding: EdgeInsets.only(
            left: 20,
            right: 20,
            top: 20,
            bottom: MediaQuery.of(context).viewInsets.bottom + 24,
          ),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('Add Account', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 16),

                // Account Type Chips
                Wrap(
                  spacing: 8,
                  children: WalletType.values.map((type) {
                    final isSel = selectedType == type;
                    return ChoiceChip(
                      label: Text(type.name.toUpperCase()),
                      selected: isSel,
                      selectedColor: AppColors.primaryGreenLight,
                      labelStyle: TextStyle(
                        color: isSel ? Colors.black : (isDark ? Colors.white : Colors.black87),
                        fontWeight: FontWeight.w600,
                        fontSize: 11,
                      ),
                      onSelected: (val) {
                        setDialogState(() {
                          selectedType = type;
                          if (type == WalletType.cash) {
                            selectedIcon = '💵';
                            nameCtrl.text = 'Cash in Hand';
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

  // --- Slide 5: Step 5a - Personalize Categories (Add, Edit, Remove) ---
  Widget _buildSlide5Categories(bool isDark) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Personalize Categories',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Step 1 of 2: Customize spending tags',
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                      color: AppColors.primaryGreenLight,
                    ),
                  ),
                ],
              ),
              ElevatedButton.icon(
                onPressed: () => _showAddOrEditCategoryModal(isDark),
                icon: const Icon(Icons.add_rounded, size: 16, color: Colors.black),
                label: const Text('Add', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 12, color: Colors.black)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primaryGreenLight,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  visualDensity: VisualDensity.compact,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            'Keep tags you need, remove ones you don\'t, or add custom tags.',
            style: TextStyle(
              fontSize: 12.5,
              color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
            ),
          ),
          const SizedBox(height: 16),

          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _onboardingCategories.length,
            separatorBuilder: (context, i) => const SizedBox(height: 8),
            itemBuilder: (context, index) {
              final cat = _onboardingCategories[index];
              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: isDark ? AppColors.darkSurfaceVariant : Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: isDark ? AppColors.darkCardBorder : AppColors.lightCardBorder,
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: Color(cat.colorValue).withValues(alpha: 0.18),
                        shape: BoxShape.circle,
                      ),
                      alignment: Alignment.center,
                      child: Text(cat.icon, style: const TextStyle(fontSize: 18)),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            cat.name,
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                            ),
                          ),
                          Text(
                            cat.type == TransactionType.expense ? 'Expense' : 'Income',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: cat.type == TransactionType.expense ? AppColors.expenseRed : AppColors.incomeGreen,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.edit_outlined, size: 18, color: Colors.grey),
                      tooltip: 'Edit category',
                      onPressed: () => _showAddOrEditCategoryModal(isDark, existing: cat),
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete_outline_rounded, size: 18, color: Colors.grey),
                      tooltip: 'Delete category',
                      onPressed: () {
                        setState(() {
                          _onboardingCategories.removeWhere((c) => c.id == cat.id);
                          _onboardingBudgets.remove(cat.id);
                        });
                      },
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  void _showAddOrEditCategoryModal(bool isDark, {CategoryModel? existing}) {
    final nameCtrl = TextEditingController(text: existing?.name ?? '');
    String selectedIcon = existing?.icon ?? '🏷️';
    int selectedColor = existing?.colorValue ?? 0xFF4CAF50;
    TransactionType selectedType = existing?.type ?? TransactionType.expense;

    final icons = ['🍔', '🛒', '🛍️', '🚗', '⚡', '🍿', '💊', '🎓', '✈️', '💰', '💼', '💻', '🎮', '🏋️', '☕', '🎁', '📝'];
    final colors = [
      0xFF4CAF50, // Green
      0xFFE57373, // Red
      0xFFFFB74D, // Orange
      0xFF64B5F6, // Blue
      0xFFBA68C8, // Purple
      0xFF4DD0E1, // Cyan
      0xFF81C784, // Mint
      0xFFAED581, // Lime
      0xFF90A4AE, // Grey
    ];

    showModalBottomSheet(
      context: context,
      useRootNavigator: true,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) => Container(
          padding: EdgeInsets.only(
            left: 20,
            right: 20,
            top: 20,
            bottom: MediaQuery.of(context).viewInsets.bottom + 24,
          ),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  existing == null ? 'Add New Category' : 'Edit Category',
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 14),

                // Type Chips (Expense vs Income)
                Row(
                  children: [
                    ChoiceChip(
                      label: const Text('Expense'),
                      selected: selectedType == TransactionType.expense,
                      selectedColor: AppColors.expenseRed.withValues(alpha: 0.25),
                      labelStyle: TextStyle(
                        fontWeight: FontWeight.w700,
                        color: selectedType == TransactionType.expense ? AppColors.expenseRed : (isDark ? Colors.white70 : Colors.black87),
                      ),
                      onSelected: (val) => setModalState(() => selectedType = TransactionType.expense),
                    ),
                    const SizedBox(width: 8),
                    ChoiceChip(
                      label: const Text('Income'),
                      selected: selectedType == TransactionType.income,
                      selectedColor: AppColors.incomeGreen.withValues(alpha: 0.25),
                      labelStyle: TextStyle(
                        fontWeight: FontWeight.w700,
                        color: selectedType == TransactionType.income ? AppColors.incomeGreen : (isDark ? Colors.white70 : Colors.black87),
                      ),
                      onSelected: (val) => setModalState(() => selectedType = TransactionType.income),
                    ),
                  ],
                ),
                const SizedBox(height: 14),

                const Text('Category Name', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                const SizedBox(height: 6),
                TextField(
                  controller: nameCtrl,
                  decoration: const InputDecoration(
                    hintText: 'e.g. Coffee, Subscriptions',
                  ),
                ),
                const SizedBox(height: 14),

                // Icon Picker
                const Text('Select Icon', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                const SizedBox(height: 6),
                SizedBox(
                  height: 44,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: icons.length,
                    separatorBuilder: (context, i) => const SizedBox(width: 6),
                    itemBuilder: (context, i) {
                      final ic = icons[i];
                      final isSelected = selectedIcon == ic;
                      return InkWell(
                        onTap: () => setModalState(() => selectedIcon = ic),
                        borderRadius: BorderRadius.circular(10),
                        child: Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            color: isSelected ? AppColors.primaryGreenLight.withValues(alpha: 0.2) : (isDark ? AppColors.darkSurfaceVariant : Colors.grey.shade100),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: isSelected ? AppColors.primaryGreenLight : Colors.transparent,
                              width: 2,
                            ),
                          ),
                          alignment: Alignment.center,
                          child: Text(ic, style: const TextStyle(fontSize: 20)),
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 14),

                // Color Picker
                const Text('Select Color', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                const SizedBox(height: 6),
                SizedBox(
                  height: 36,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: colors.length,
                    separatorBuilder: (context, i) => const SizedBox(width: 8),
                    itemBuilder: (context, i) {
                      final col = colors[i];
                      final isSelected = selectedColor == col;
                      return InkWell(
                        onTap: () => setModalState(() => selectedColor = col),
                        borderRadius: BorderRadius.circular(18),
                        child: Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            color: Color(col),
                            shape: BoxShape.circle,
                            border: isSelected ? Border.all(color: Colors.white, width: 2.5) : null,
                          ),
                          child: isSelected ? const Icon(Icons.check, size: 18, color: Colors.white) : null,
                        ),
                      );
                    },
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
                      if (name.isEmpty) return;

                      setState(() {
                        if (existing == null) {
                          _onboardingCategories.add(
                            CategoryModel(
                              id: const Uuid().v4(),
                              name: name,
                              icon: selectedIcon,
                              colorValue: selectedColor,
                              type: selectedType,
                            ),
                          );
                        } else {
                          final idx = _onboardingCategories.indexWhere((c) => c.id == existing.id);
                          if (idx != -1) {
                            _onboardingCategories[idx] = existing.copyWith(
                              name: name,
                              icon: selectedIcon,
                              colorValue: selectedColor,
                              type: selectedType,
                            );
                          }
                        }
                      });
                      Navigator.pop(ctx);
                    },
                    child: Text(existing == null ? 'Add Category' : 'Save Changes', style: const TextStyle(fontWeight: FontWeight.bold)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // --- Slide 6: Step 5b - Set Monthly Budgets with Custom Limits & Presets ---
  Widget _buildSlide6CategoryBudgets(bool isDark) {
    final symbol = _selectedCurrencySymbol ?? '₹';
    final expenseCategories = _onboardingCategories.where((c) => c.type == TransactionType.expense).toList();

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Set Monthly Budgets',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Step 2 of 2: Set custom spending caps or tap preset limits',
            style: TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w600,
              color: AppColors.primaryGreenLight,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Tap amount to type any custom limit, or use quick presets below.',
            style: TextStyle(
              fontSize: 12.5,
              color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
            ),
          ),
          const SizedBox(height: 16),

          if (expenseCategories.isEmpty)
            Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 24),
                child: Text('No expense categories created', style: TextStyle(color: isDark ? AppColors.darkTextTertiary : AppColors.lightTextTertiary)),
              ),
            )
          else
            ...expenseCategories.map((cat) {
              final catId = cat.id;
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
                        ? AppColors.primaryGreenLight.withValues(alpha: 0.4)
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
                            Text(cat.icon, style: const TextStyle(fontSize: 20)),
                            const SizedBox(width: 10),
                            Text(
                              cat.name,
                              style: TextStyle(
                                fontSize: 14.5,
                                fontWeight: FontWeight.w700,
                                color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                              ),
                            ),
                          ],
                        ),
                        // Tap-to-edit inline amount button / chip
                        InkWell(
                          onTap: () => _showCustomBudgetDialog(cat, isDark),
                          borderRadius: BorderRadius.circular(10),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                            decoration: BoxDecoration(
                              color: isEnabled
                                  ? AppColors.primaryGreenLight.withValues(alpha: 0.18)
                                  : (isDark ? const Color(0xFF262626) : const Color(0xFFE0E0E0)),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: isEnabled ? AppColors.primaryGreenLight : Colors.transparent,
                                width: 1,
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  isEnabled ? '$symbol${currentBudget.toStringAsFixed(0)} / mo' : 'Tap to set limit',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w800,
                                    color: isEnabled ? AppColors.primaryGreenLight : Colors.grey,
                                  ),
                                ),
                                const SizedBox(width: 4),
                                Icon(Icons.edit_rounded, size: 12, color: isEnabled ? AppColors.primaryGreenLight : Colors.grey),
                              ],
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
                          _buildPresetBudgetChip(catId, 1000, '${symbol}1k', currentBudget == 1000, isDark),
                          const SizedBox(width: 6),
                          _buildPresetBudgetChip(catId, 2000, '${symbol}2k', currentBudget == 2000, isDark),
                          const SizedBox(width: 6),
                          _buildPresetBudgetChip(catId, 5000, '${symbol}5k', currentBudget == 5000, isDark),
                          const SizedBox(width: 6),
                          _buildPresetBudgetChip(catId, 10000, '${symbol}10k', currentBudget == 10000, isDark),
                          const SizedBox(width: 6),
                          InkWell(
                            onTap: () => _showCustomBudgetDialog(cat, isDark),
                            borderRadius: BorderRadius.circular(10),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                              decoration: BoxDecoration(
                                color: isDark ? const Color(0xFF262626) : const Color(0xFFEFEFEF),
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(color: AppColors.primaryGreenLight.withValues(alpha: 0.3)),
                              ),
                              child: const Text(
                                '✏️ Custom',
                                style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: AppColors.primaryGreenLight),
                              ),
                            ),
                          ),
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

  void _showCustomBudgetDialog(CategoryModel cat, bool isDark) {
    final symbol = _selectedCurrencySymbol ?? '₹';
    final currentBudget = _onboardingBudgets[cat.id] ?? 0.0;
    final ctrl = TextEditingController(text: currentBudget > 0 ? currentBudget.toStringAsFixed(0) : '');

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Text(cat.icon, style: const TextStyle(fontSize: 22)),
            const SizedBox(width: 8),
            Expanded(child: Text('${cat.name} Limit', style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800))),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Enter monthly spending limit:', style: TextStyle(fontSize: 12.5)),
            const SizedBox(height: 10),
            TextField(
              controller: ctrl,
              autofocus: true,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              decoration: InputDecoration(
                prefixText: '$symbol ',
                hintText: 'e.g. 3500',
                filled: true,
                fillColor: isDark ? AppColors.darkSurfaceVariant : Colors.grey.shade100,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              setState(() => _onboardingBudgets[cat.id] = 0);
              Navigator.pop(ctx);
            },
            child: const Text('Clear Limit', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primaryGreenLight,
              foregroundColor: Colors.black,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: () {
              final val = double.tryParse(ctrl.text.trim()) ?? 0.0;
              setState(() => _onboardingBudgets[cat.id] = val);
              Navigator.pop(ctx);
            },
            child: const Text('Save Limit', style: TextStyle(fontWeight: FontWeight.w800)),
          ),
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

  // --- Slide 7: Step 6 - Smart Preferences & Notification Alerts ---
  Widget _buildSlide7Preferences(bool isDark) {
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
