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

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> with TickerProviderStateMixin {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  late final AnimationController _iconAnimCtrl;
  late final AnimationController _featuresAnimCtrl;

  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  String? _selectedCurrencySymbol = '₹';
  String? _selectedCurrencyCode = 'INR';

  // Theme preferences
  AppThemeMode _selectedThemeMode = AppThemeMode.autoTime;
  ManualThemeStyle _selectedThemeStyle = ManualThemeStyle.pureBlack;
  bool _isPureBlack = true;

  // Budget Rollover
  bool _isBudgetRolloverEnabled = true;

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

  String _selectedCountryCode = '+91';
  String _selectedCountryFlag = '🇮🇳';

  final List<Map<String, String>> _countryCodes = [
    {'code': '+91', 'flag': '🇮🇳', 'name': 'India'},
    {'code': '+1', 'flag': '🇺🇸', 'name': 'United States / Canada'},
    {'code': '+44', 'flag': '🇬🇧', 'name': 'United Kingdom'},
    {'code': '+971', 'flag': '🇦🇪', 'name': 'United Arab Emirates'},
    {'code': '+61', 'flag': '🇦🇺', 'name': 'Australia'},
    {'code': '+81', 'flag': '🇯🇵', 'name': 'Japan'},
    {'code': '+49', 'flag': '🇩🇪', 'name': 'Germany'},
    {'code': '+65', 'flag': '🇸🇬', 'name': 'Singapore'},
    {'code': '+33', 'flag': '🇫🇷', 'name': 'France'},
    {'code': '+966', 'flag': '🇸🇦', 'name': 'Saudi Arabia'},
    {'code': '+86', 'flag': '🇨🇳', 'name': 'China'},
    {'code': '+7', 'flag': '🇷🇺', 'name': 'Russia'},
    {'code': '+55', 'flag': '🇧🇷', 'name': 'Brazil'},
    {'code': '+27', 'flag': '🇿🇦', 'name': 'South Africa'},
    {'code': '+60', 'flag': '🇲🇾', 'name': 'Malaysia'},
  ];

  @override
  void initState() {
    super.initState();
    _iconAnimCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat(reverse: true);

    _featuresAnimCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..forward();

    _onboardingCategories = List.from(defaultCategories);
    // Starts with clean slate for Profile and Wallet Setup
  }

  @override
  void dispose() {
    _iconAnimCtrl.dispose();
    _featuresAnimCtrl.dispose();
    _pageController.dispose();
    _nameController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  void _applyThemeRealtime({
    AppThemeMode? mode,
    ManualThemeStyle? style,
    bool? pureBlack,
  }) {
    setState(() {
      if (mode != null) _selectedThemeMode = mode;
      if (style != null) _selectedThemeStyle = style;
      if (pureBlack != null) _isPureBlack = pureBlack;
    });

    final currentSettings = ref.read(settingsProvider);
    ref.read(settingsProvider.notifier).updateSettings(
          currentSettings.copyWith(
            themeMode: _selectedThemeMode,
            manualThemeStyle: _selectedThemeStyle,
            isPureBlackEnabled: _isPureBlack,
          ),
        );
  }

  void _nextPage() {
    FocusScope.of(context).unfocus();

    if (_currentPage == 1) {
      // Validate Profile page
      final name = _nameController.text.trim();
      if (name.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Please enter your name to personalize your matrix'),
            duration: Duration(seconds: 3),
          ),
        );
        return;
      }
      if (_selectedCurrencySymbol == null || _selectedCurrencyCode == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Please select your preferred currency'),
            duration: Duration(seconds: 3),
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
            content: Text('Please keep or add at least 1 account to proceed'),
            duration: Duration(seconds: 3),
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
      _pageController.animateToPage(3, duration: const Duration(milliseconds: 300), curve: Curves.easeOutCubic);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          behavior: SnackBarBehavior.floating,
          content: Text('Please add at least 1 account to get started'),
          duration: Duration(seconds: 3),
        ),
      );
      return;
    }

    final name = _nameController.text.trim();
    final rawPhone = _phoneController.text.trim();
    final phone = rawPhone.isNotEmpty ? '$_selectedCountryCode $rawPhone' : null;
    final currencySymbol = _selectedCurrencySymbol ?? '₹';
    final currencyCode = _selectedCurrencyCode ?? 'INR';

    // 1. Save all settings & preferences
    await ref.read(settingsProvider.notifier).updateSettings(
          ref.read(settingsProvider).copyWith(
                userName: name,
                userPhoneNumber: phone,
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

    // 4. Save configured category budgets with rollover state
    final now = DateTime.now();
    final List<CategoryBudgetModel> budgetsToSave = [];
    _onboardingBudgets.forEach((catId, limit) {
      if (limit > 0) {
        budgetsToSave.add(
          CategoryBudgetModel(
            id: const Uuid().v4(),
            categoryId: catId,
            monthlyLimit: limit,
            isRolloverEnabled: _isBudgetRolloverEnabled,
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
            // Top Futuristic Animated Step Indicator Bar (7 steps)
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

            // Page View (7 Responsive, Scroll-Safe Slides)
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

  // --- Slide 1: Welcome & Enterprise Security Matrix ---
  Widget _buildSlide1Welcome(bool isDark) {
    final features = [
      {'icon': Icons.lock_rounded, 'label': '🔒 Hardware AES-256 Encryption • Zero-knowledge offline privacy'},
      {'icon': Icons.auto_graph_rounded, 'label': '🔮 On-Device AI Forecasting • Confidence bands & burn rate predictions'},
      {'icon': Icons.auto_fix_high_rounded, 'label': '✨ Natural Language Entry • Type or speak "1200 for dinner yesterday"'},
      {'icon': Icons.alt_route_rounded, 'label': '🌊 Sankey Money Topology & 0–1000 Financial Health Score Gauge'},
      {'icon': Icons.bolt_rounded, 'label': '⚡ Instant UPI Share-to-Log • Auto-parse payment receipts with OCR'},
      {'icon': Icons.track_changes_rounded, 'label': '🎯 Savings Goals, Budget Rollover & Bill Due Calendar View'},
    ];

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      child: Column(
        children: [
          const SizedBox(height: 12),
          // Pulsing Animated Pocket Logo with Glowing Halo
          AnimatedBuilder(
            animation: _iconAnimCtrl,
            builder: (context, child) {
              final scale = 1.0 + (_iconAnimCtrl.value * 0.08);
              final glowAlpha = 0.2 + (_iconAnimCtrl.value * 0.25);
              return Transform.scale(
                scale: scale,
                child: Container(
                  width: 96,
                  height: 96,
                  decoration: BoxDecoration(
                    color: AppColors.primaryGreenLight.withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: AppColors.primaryGreenLight.withValues(alpha: 0.4),
                      width: 2.5,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.primaryGreenLight.withValues(alpha: glowAlpha),
                        blurRadius: 28,
                        spreadRadius: 4,
                      ),
                    ],
                  ),
                  child: const Center(
                    child: Text('💳', style: TextStyle(fontSize: 48)),
                  ),
                ),
              );
            },
          ),
          const SizedBox(height: 24),
          Text(
            'Welcome to Pocket',
            style: TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.w900,
              letterSpacing: -0.5,
              color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Next-generation offline personal financial intelligence suite with AMOLED Pure Black aesthetics.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13,
              height: 1.4,
              color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
            ),
          ),
          const SizedBox(height: 20),

          // Staggered Feature Cards Cascading in
          ...List.generate(features.length, (index) {
            final start = (index * 0.12).clamp(0.0, 0.7);
            final end = (start + 0.3).clamp(0.0, 1.0);
            final animation = CurvedAnimation(
              parent: _featuresAnimCtrl,
              curve: Interval(start, end, curve: Curves.easeOutCubic),
            );

            return AnimatedBuilder(
              animation: animation,
              builder: (context, child) {
                final offset = Offset(0, 30 * (1.0 - animation.value));
                return Opacity(
                  opacity: animation.value.clamp(0.0, 1.0),
                  child: Transform.translate(
                    offset: offset,
                    child: Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: _buildFeaturePill(
                        features[index]['icon'] as IconData,
                        features[index]['label'] as String,
                        isDark,
                      ),
                    ),
                  ),
                );
              },
            );
          }),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Widget _buildFeaturePill(IconData icon, String label, bool isDark) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurfaceVariant : Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isDark ? AppColors.darkCardBorder : AppColors.lightCardBorder,
        ),
      ),
      child: Row(
        children: [
          Icon(icon, size: 16, color: AppColors.primaryGreenLight),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 12,
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
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Profile Setup',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Personalize your name and preferred global currency.',
            style: TextStyle(
              fontSize: 12.5,
              color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
            ),
          ),
          const SizedBox(height: 20),
          const Text('Your Name', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600)),
          const SizedBox(height: 6),
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
          const SizedBox(height: 16),

          // User Mobile Number Input
          const Text('Mobile Number (Optional)', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600)),
          const SizedBox(height: 6),
          TextField(
            controller: _phoneController,
            keyboardType: TextInputType.phone,
            decoration: InputDecoration(
              hintText: '9876543210',
              hintStyle: TextStyle(
                color: isDark ? Colors.white30 : Colors.black26,
                fontSize: 13,
                fontWeight: FontWeight.w400,
              ),
              prefixIcon: InkWell(
                onTap: () => _showCountryCodePicker(isDark),
                borderRadius: BorderRadius.circular(12),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(_selectedCountryFlag, style: const TextStyle(fontSize: 18)),
                      const SizedBox(width: 4),
                      Text(
                        _selectedCountryCode,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                        ),
                      ),
                      const SizedBox(width: 2),
                      const Icon(Icons.arrow_drop_down_rounded, size: 18, color: Colors.grey),
                      const SizedBox(width: 6),
                      Container(height: 20, width: 1, color: isDark ? Colors.white24 : Colors.black12),
                      const SizedBox(width: 6),
                    ],
                  ),
                ),
              ),
              filled: true,
              fillColor: isDark ? AppColors.darkSurfaceVariant : Colors.white,
            ),
          ),
          const SizedBox(height: 20),

          const Text('Select Currency', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600)),
          const SizedBox(height: 10),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              mainAxisSpacing: 8,
              crossAxisSpacing: 8,
              childAspectRatio: 2.3,
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
                      width: isSelected ? 1.5 : 1,
                    ),
                  ),
                  child: Row(
                    children: [
                      Text(
                        c['symbol']!,
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: isSelected ? AppColors.primaryGreenLight : (isDark ? Colors.white : Colors.black),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              c['code']!,
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: isSelected ? AppColors.primaryGreenLight : (isDark ? Colors.white : Colors.black),
                              ),
                            ),
                            Text(
                              c['name']!,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 9.5,
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
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Theme & Display',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Choose your visual appearance and AMOLED display optimization.',
            style: TextStyle(
              fontSize: 12.5,
              color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
            ),
          ),
          const SizedBox(height: 20),

          _buildThemeModeCard(
            title: 'Auto Mode (Time-Based)',
            subtitle: 'Automatically switches to Light (6AM-6PM) & Dark (6PM-6AM)',
            icon: Icons.auto_mode_rounded,
            isSelected: _selectedThemeMode == AppThemeMode.autoTime,
            onTap: () => _applyThemeRealtime(mode: AppThemeMode.autoTime),
            isDark: isDark,
          ),
          const SizedBox(height: 10),

          _buildThemeModeCard(
            title: 'Dark Theme',
            subtitle: 'Always dark background with soft mint green accents',
            icon: Icons.dark_mode_rounded,
            isSelected: _selectedThemeMode == AppThemeMode.manual && _selectedThemeStyle == ManualThemeStyle.dark,
            onTap: () => _applyThemeRealtime(
              mode: AppThemeMode.manual,
              style: ManualThemeStyle.dark,
            ),
            isDark: isDark,
          ),
          const SizedBox(height: 10),

          _buildThemeModeCard(
            title: 'Light Theme',
            subtitle: 'Crisp, clean bright appearance with high contrast',
            icon: Icons.light_mode_rounded,
            isSelected: _selectedThemeMode == AppThemeMode.manual && _selectedThemeStyle == ManualThemeStyle.light,
            onTap: () => _applyThemeRealtime(
              mode: AppThemeMode.manual,
              style: ManualThemeStyle.light,
            ),
            isDark: isDark,
          ),
          const SizedBox(height: 18),

          // AMOLED Pure Black Toggle
          Container(
            padding: const EdgeInsets.all(14),
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
                          fontSize: 13,
                          color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'True #000000 pixels for maximum battery savings',
                        style: TextStyle(
                          fontSize: 11,
                          color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                Switch(
                  value: _isPureBlack,
                  activeThumbColor: AppColors.primaryGreenLight,
                  onChanged: (val) => _applyThemeRealtime(pureBlack: val),
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
        padding: const EdgeInsets.all(14),
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
                      color: isSelected ? AppColors.primaryGreenLight : (isDark ? Colors.white : Colors.black),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 11,
                      color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                    ),
                  ),
                ],
              ),
            ),
            if (isSelected)
              const Icon(Icons.check_circle_rounded, color: AppColors.primaryGreenLight, size: 18),
          ],
        ),
      ),
    );
  }

  void _showCountryCodePicker(bool isDark) {
    showModalBottomSheet(
      context: context,
      useRootNavigator: true,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.65,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.withValues(alpha: 0.4),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 14),
            const Text(
              'Select Country Code',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: ListView.separated(
                itemCount: _countryCodes.length,
                separatorBuilder: (context, index) => Divider(
                  height: 1,
                  color: isDark ? AppColors.darkCardBorder : AppColors.lightCardBorder,
                ),
                itemBuilder: (context, index) {
                  final item = _countryCodes[index];
                  final isSelected = _selectedCountryCode == item['code'];
                  return ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    leading: Text(item['flag']!, style: const TextStyle(fontSize: 22)),
                    title: Text(
                      item['name']!,
                      style: TextStyle(
                        fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                        color: isSelected ? AppColors.primaryGreenLight : null,
                      ),
                    ),
                    trailing: Text(
                      item['code']!,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: isSelected ? AppColors.primaryGreenLight : Colors.grey,
                      ),
                    ),
                    onTap: () {
                      setState(() {
                        _selectedCountryCode = item['code']!;
                        _selectedCountryFlag = item['flag']!;
                      });
                      Navigator.pop(ctx);
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  // --- Slide 4: Wallet Setup ---
  Widget _buildSlide4Wallets(bool isDark) {
    final symbol = _selectedCurrencySymbol ?? '₹';

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
                    'Wallet Setup',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Add your bank accounts, cash in hand, UPI, or cards.',
                    style: TextStyle(
                      fontSize: 12,
                      color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),

          if (_onboardingWallets.isEmpty) ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 22),
              decoration: BoxDecoration(
                color: isDark ? AppColors.darkSurfaceVariant : Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: isDark ? AppColors.darkCardBorder : AppColors.lightCardBorder,
                ),
              ),
              child: Center(
                child: Column(
                  children: [
                    const Text('💳', style: TextStyle(fontSize: 32)),
                    const SizedBox(height: 8),
                    Text(
                      'No accounts added yet',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                        color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Tap below to add your primary bank, cash, or UPI.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 11.5,
                        color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 14),
          ],

          // Added Wallets List
          ..._onboardingWallets.map((w) {
            return Container(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.all(14),
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
                            Flexible(
                              child: Text(
                                w.name,
                                style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            if (w.maskedAccountNumber.isNotEmpty) ...[
                              const SizedBox(width: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                                decoration: BoxDecoration(
                                  color: isDark ? Colors.white10 : Colors.black.withValues(alpha: 0.05),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  w.maskedAccountNumber,
                                  style: const TextStyle(fontSize: 9.5, fontWeight: FontWeight.w700),
                                ),
                              ),
                            ],
                          ],
                        ),
                        const SizedBox(height: 3),
                        InkWell(
                          onTap: () => _showEditBalanceDialog(w, isDark),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                'Starting: $symbol${w.currentBalance.toStringAsFixed(0)}',
                                style: const TextStyle(color: AppColors.primaryGreenLight, fontWeight: FontWeight.w700, fontSize: 12),
                              ),
                              const SizedBox(width: 4),
                              const Icon(Icons.edit_outlined, size: 12, color: AppColors.primaryGreenLight),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.delete_outline_rounded, size: 18, color: Colors.grey),
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
          const SizedBox(height: 8),

          // Quick Template Add Buttons
          Row(
            children: [
              Expanded(
                child: _buildQuickWalletButton(
                  icon: Icons.account_balance_rounded,
                  label: '+ Bank',
                  onTap: () => _showAddWalletDialog(isDark, initialType: WalletType.bank),
                  isDark: isDark,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildQuickWalletButton(
                  icon: Icons.payments_outlined,
                  label: '+ Cash',
                  onTap: () => _showAddWalletDialog(isDark, initialType: WalletType.cash),
                  isDark: isDark,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildQuickWalletButton(
                  icon: Icons.qr_code_2_rounded,
                  label: '+ UPI',
                  onTap: () => _showAddWalletDialog(isDark, initialType: WalletType.upi),
                  isDark: isDark,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildQuickWalletButton(
                  icon: Icons.credit_card_rounded,
                  label: '+ Card',
                  onTap: () => _showAddWalletDialog(isDark, initialType: WalletType.creditCard),
                  isDark: isDark,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildQuickWalletButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    required bool isDark,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: isDark ? AppColors.darkSurfaceVariant : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.primaryGreenLight.withValues(alpha: 0.35)),
        ),
        alignment: Alignment.center,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 14, color: AppColors.primaryGreenLight),
            const SizedBox(width: 4),
            Text(
              label,
              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 11.5, color: AppColors.primaryGreenLight),
            ),
          ],
        ),
      ),
    );
  }

  void _showEditBalanceDialog(WalletModel wallet, bool isDark) {
    final symbol = _selectedCurrencySymbol ?? '₹';
    final ctrl = TextEditingController(text: wallet.currentBalance > 0 ? wallet.currentBalance.toStringAsFixed(0) : '');

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('${wallet.name} Balance', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: InputDecoration(
            prefixText: '$symbol ',
            hintText: '0.00',
            filled: true,
            fillColor: isDark ? AppColors.darkSurfaceVariant : Colors.grey.shade100,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primaryGreenLight,
              foregroundColor: Colors.black,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: () {
              final bal = double.tryParse(ctrl.text.trim()) ?? 0.0;
              final idx = _onboardingWallets.indexWhere((w) => w.id == wallet.id);
              if (idx != -1) {
                setState(() {
                  _onboardingWallets[idx] = wallet.copyWith(
                    initialBalance: bal,
                    currentBalance: bal,
                  );
                });
              }
              Navigator.pop(ctx);
            },
            child: const Text('Save Balance', style: TextStyle(fontWeight: FontWeight.w800)),
          ),
        ],
      ),
    );
  }

  void _showAddWalletDialog(bool isDark, {WalletType? initialType}) {
    final selectedType = initialType ?? WalletType.bank;
    String selectedIcon = '🏦';
    String placeholderHint = 'e.g. Canara Bank, SBI, HDFC';
    String dialogTitle = 'Add Bank Account';

    if (selectedType == WalletType.cash) {
      selectedIcon = '💵';
      placeholderHint = 'e.g. Cash in Hand, Pocket Cash';
      dialogTitle = 'Add Cash Account';
    } else if (selectedType == WalletType.upi) {
      selectedIcon = '📱';
      placeholderHint = 'e.g. Google Pay, PhonePe, Paytm';
      dialogTitle = 'Add UPI Account';
    } else if (selectedType == WalletType.creditCard) {
      selectedIcon = '💳';
      placeholderHint = 'e.g. Amazon ICICI, HDFC Millennia';
      dialogTitle = 'Add Credit Card';
    } else if (selectedType == WalletType.savings) {
      selectedIcon = '💰';
      placeholderHint = 'e.g. Emergency Fund, Gold Vault';
      dialogTitle = 'Add Savings Vault';
    }

    final nameCtrl = TextEditingController();
    final balanceCtrl = TextEditingController();
    final last4Ctrl = TextEditingController();

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
                Row(
                  children: [
                    Text(selectedIcon, style: const TextStyle(fontSize: 22)),
                    const SizedBox(width: 8),
                    Text(dialogTitle, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  ],
                ),
                const SizedBox(height: 16),

                const Text('Account Name', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                const SizedBox(height: 6),
                TextField(
                  controller: nameCtrl,
                  decoration: InputDecoration(
                    hintText: placeholderHint,
                    hintStyle: TextStyle(
                      color: isDark ? Colors.white30 : Colors.black26,
                      fontSize: 13,
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                ),
                const SizedBox(height: 14),

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
                      hintStyle: TextStyle(
                        color: isDark ? Colors.white30 : Colors.black26,
                        fontSize: 13,
                        fontWeight: FontWeight.w400,
                      ),
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
                    hintStyle: TextStyle(
                      color: isDark ? Colors.white30 : Colors.black26,
                      fontSize: 13,
                      fontWeight: FontWeight.w400,
                    ),
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
                            duration: Duration(seconds: 3),
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

  // --- Slide 5: Personalize Categories (Add, Edit, Remove) ---
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
                    'Spending Categories',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  const Text(
                    'Customize icons, tags, and colors.',
                    style: TextStyle(fontSize: 12, color: Colors.grey),
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
          const SizedBox(height: 14),

          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _onboardingCategories.length,
            separatorBuilder: (context, i) => const SizedBox(height: 8),
            itemBuilder: (context, index) {
              final cat = _onboardingCategories[index];
              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
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
                      width: 34,
                      height: 34,
                      decoration: BoxDecoration(
                        color: Color(cat.colorValue).withValues(alpha: 0.18),
                        shape: BoxShape.circle,
                      ),
                      alignment: Alignment.center,
                      child: Text(cat.icon, style: const TextStyle(fontSize: 17)),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            cat.name,
                            style: TextStyle(
                              fontSize: 13.5,
                              fontWeight: FontWeight.w700,
                              color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                            ),
                          ),
                          Text(
                            cat.type == TransactionType.expense ? 'Expense' : 'Income',
                            style: TextStyle(
                              fontSize: 10.5,
                              fontWeight: FontWeight.w600,
                              color: cat.type == TransactionType.expense ? AppColors.expenseRed : AppColors.incomeGreen,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.edit_outlined, size: 17, color: Colors.grey),
                      tooltip: 'Edit category',
                      onPressed: () => _showAddOrEditCategoryModal(isDark, existing: cat),
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete_outline_rounded, size: 17, color: Colors.grey),
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
                  decoration: InputDecoration(
                    hintText: 'e.g. Coffee, Subscriptions',
                    hintStyle: TextStyle(
                      color: isDark ? Colors.white30 : Colors.black26,
                      fontSize: 13,
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                ),
                const SizedBox(height: 14),

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

  // --- Slide 6: Monthly Budgets & Budget Rollover ---
  Widget _buildSlide6CategoryBudgets(bool isDark) {
    final symbol = _selectedCurrencySymbol ?? '₹';
    final expenseCategories = _onboardingCategories.where((c) => c.type == TransactionType.expense).toList();

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Monthly Budgets & Rollover',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Set category spending limits & carry over unspent savings.',
            style: TextStyle(
              fontSize: 12.5,
              color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
            ),
          ),
          const SizedBox(height: 16),

          // Budget Rollover Master Toggle Card
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: isDark
                    ? [const Color(0xFF142918), const Color(0xFF191919)]
                    : [const Color(0xFFE8F5E9), const Color(0xFFFAFAFA)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.primaryGreenLight.withValues(alpha: 0.35)),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColors.primaryGreenLight.withValues(alpha: 0.2),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.autorenew_rounded, color: AppColors.primaryGreenLight, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Budget Rollover Carry-Forward',
                        style: TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 13,
                          color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Unspent monthly budget balance carries over to expand next month\'s limit.',
                        style: TextStyle(
                          fontSize: 11,
                          color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                Switch(
                  value: _isBudgetRolloverEnabled,
                  activeThumbColor: AppColors.primaryGreenLight,
                  onChanged: (val) => setState(() => _isBudgetRolloverEnabled = val),
                ),
              ],
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
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: isDark ? AppColors.darkSurfaceVariant : Colors.white,
                  borderRadius: BorderRadius.circular(16),
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
                            Text(cat.icon, style: const TextStyle(fontSize: 18)),
                            const SizedBox(width: 8),
                            Text(
                              cat.name,
                              style: TextStyle(
                                fontSize: 13.5,
                                fontWeight: FontWeight.w700,
                                color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                              ),
                            ),
                          ],
                        ),
                        InkWell(
                          onTap: () => _showCustomBudgetDialog(cat, isDark),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: isEnabled
                                  ? AppColors.primaryGreenLight.withValues(alpha: 0.18)
                                  : (isDark ? const Color(0xFF262626) : const Color(0xFFE0E0E0)),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: isEnabled ? AppColors.primaryGreenLight : Colors.transparent,
                                width: 1,
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  isEnabled ? '$symbol${currentBudget.toStringAsFixed(0)} / mo' : 'Set limit',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w800,
                                    color: isEnabled ? AppColors.primaryGreenLight : Colors.grey,
                                  ),
                                ),
                                const SizedBox(width: 4),
                                Icon(Icons.edit_rounded, size: 10, color: isEnabled ? AppColors.primaryGreenLight : Colors.grey),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
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
                            borderRadius: BorderRadius.circular(8),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                              decoration: BoxDecoration(
                                color: isDark ? const Color(0xFF262626) : const Color(0xFFEFEFEF),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: AppColors.primaryGreenLight.withValues(alpha: 0.3)),
                              ),
                              child: const Text(
                                '✏️ Custom',
                                style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.primaryGreenLight),
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
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.primaryGreenLight
              : (isDark ? const Color(0xFF262626) : const Color(0xFFEFEFEF)),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            color: isSelected ? Colors.black : (isDark ? Colors.white70 : Colors.black87),
          ),
        ),
      ),
    );
  }

  // --- Slide 7: Smart Preferences & Notification Alerts ---
  Widget _buildSlide7Preferences(bool isDark) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Smart Alerts & Launch',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Configure daily reminders and proactive debt & budget alarms.',
            style: TextStyle(
              fontSize: 12.5,
              color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
            ),
          ),
          const SizedBox(height: 18),

          // Daily Reminder Card
          Container(
            padding: const EdgeInsets.all(14),
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
                              fontSize: 13.5,
                              color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Daily prompt to review spend',
                            style: TextStyle(
                              fontSize: 11.5,
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
                  const SizedBox(height: 8),
                  Divider(height: 1, color: isDark ? AppColors.darkCardBorder : AppColors.lightCardBorder),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Reminder Time',
                        style: TextStyle(
                          fontSize: 13,
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
          const SizedBox(height: 12),

          // Proactive Alerts Card
          Container(
            padding: const EdgeInsets.all(14),
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
                const SizedBox(height: 6),
                Divider(height: 1, color: isDark ? AppColors.darkCardBorder : AppColors.lightCardBorder),
                const SizedBox(height: 6),
                _buildPreferenceSwitchRow(
                  icon: Icons.error_outline_rounded,
                  iconColor: AppColors.expenseRed,
                  title: 'Budget 100% Exceeded Alert',
                  subtitle: 'Notify immediately when limit is reached',
                  value: _budgetExceededEnabled,
                  onChanged: (v) => setState(() => _budgetExceededEnabled = v),
                  isDark: isDark,
                ),
                const SizedBox(height: 6),
                Divider(height: 1, color: isDark ? AppColors.darkCardBorder : AppColors.lightCardBorder),
                const SizedBox(height: 6),
                _buildPreferenceSwitchRow(
                  icon: Icons.notifications_active_outlined,
                  iconColor: AppColors.primaryGreenLight,
                  title: 'Debt Due-Date Reminders',
                  subtitle: 'Alarms 1-day prior & morning of due date',
                  value: _recurringDueEnabled,
                  onChanged: (v) => setState(() => _recurringDueEnabled = v),
                  isDark: isDark,
                ),
                const SizedBox(height: 6),
                Divider(height: 1, color: isDark ? AppColors.darkCardBorder : AppColors.lightCardBorder),
                const SizedBox(height: 6),
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
          padding: const EdgeInsets.all(7),
          decoration: BoxDecoration(
            color: iconColor.withValues(alpha: 0.15),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: iconColor, size: 16),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                  color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                ),
              ),
              Text(
                subtitle,
                style: TextStyle(
                  fontSize: 11,
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
