import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:uuid/uuid.dart';
import '../../models/wallet_model.dart';
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

    if (_currentPage < 2) {
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

    // Save settings
    await ref.read(settingsProvider.notifier).updateSettings(
          ref.read(settingsProvider).copyWith(
                userName: name,
                currencySymbol: currencySymbol,
                currencyCode: currencyCode,
                isOnboarded: true,
              ),
        );

    // Save the created onboarding wallets
    final storage = ref.read(storageServiceProvider);
    await storage.saveWallets(_onboardingWallets);
    ref.invalidate(walletsProvider);

    // Request notification and other permissions
    await NotificationService().requestPermissions();

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
            // Top Navigation Row without Skip button
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  if (_currentPage > 0)
                    IconButton(
                      icon: const Icon(Icons.arrow_back_rounded),
                      onPressed: () => _pageController.previousPage(
                        duration: const Duration(milliseconds: 300),
                        curve: Curves.easeInOut,
                      ),
                    )
                  else
                    const SizedBox(width: 48, height: 48),
                  Text(
                    'Step ${_currentPage + 1} of 3',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                    ),
                  ),
                  const SizedBox(width: 48),
                ],
              ),
            ),

            // PageView
            Expanded(
              child: PageView(
                controller: _pageController,
                physics: const NeverScrollableScrollPhysics(), // Require button click for validation
                onPageChanged: (page) => setState(() => _currentPage = page),
                children: [
                  _buildWelcomeSlide(isDark),
                  _buildProfileSlide(isDark),
                  _buildWalletsSlide(isDark),
                ],
              ),
            ),

            // Bottom Navigation & Dots
            Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                children: [
                  // Dot Indicators
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(3, (index) {
                      final isSel = index == _currentPage;
                      return AnimatedContainer(
                        duration: const Duration(milliseconds: 250),
                        margin: const EdgeInsets.symmetric(horizontal: 4),
                        width: isSel ? 24 : 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: isSel
                              ? AppColors.primaryGreenLight
                              : (isDark ? const Color(0xFF333333) : const Color(0xFFE0E0E0)),
                          borderRadius: BorderRadius.circular(4),
                        ),
                      );
                    }),
                  ),
                  const SizedBox(height: 20),

                  // Action Button
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: ElevatedButton(
                      onPressed: _nextPage,
                      child: Text(
                        _currentPage == 2 ? 'Get Started' : 'Continue',
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
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

  Widget _buildWelcomeSlide(bool isDark) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 28),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 110,
            height: 110,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF1B5E20), Color(0xFF4CAF50)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: AppColors.primaryGreenLight.withValues(alpha: 0.3),
                  blurRadius: 24,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            alignment: Alignment.center,
            child: const Text('🌿', style: TextStyle(fontSize: 54)),
          ),
          const SizedBox(height: 32),
          Text(
            'Welcome to Pocket',
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.w800,
              color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Track your personal expenses, manage multiple wallets, and gain deep financial clarity.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 15,
              height: 1.4,
              color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProfileSlide(bool isDark) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
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
            'Enter your name and choose your primary currency',
            style: TextStyle(
              fontSize: 14,
              color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
            ),
          ),
          const SizedBox(height: 24),

          // Name Input (Starts empty)
          const Text('Your Name *', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.primaryGreenLight)),
          const SizedBox(height: 8),
          TextField(
            controller: _nameController,
            decoration: const InputDecoration(
              hintText: 'e.g. Nandha',
              prefixIcon: Icon(Icons.person_outline_rounded),
            ),
          ),
          const SizedBox(height: 24),

          // Currency Selector (Starts unselected)
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Select Currency *', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.primaryGreenLight)),
              if (_selectedCurrencyCode != null)
                Text(
                  'Selected: $_selectedCurrencySymbol ($_selectedCurrencyCode)',
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.primaryGreenLight),
                ),
            ],
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: _currencies.map((c) {
              final isSel = _selectedCurrencyCode == c['code'];
              return ChoiceChip(
                label: Text('${c['symbol']} ${c['code']}'),
                selected: isSel,
                selectedColor: AppColors.primaryGreenLight.withValues(alpha: 0.25),
                onSelected: (_) {
                  setState(() {
                    _selectedCurrencySymbol = c['symbol']!;
                    _selectedCurrencyCode = c['code']!;
                  });
                },
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildWalletsSlide(bool isDark) {
    final currencySymbol = _selectedCurrencySymbol ?? '₹';

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Set Up Your Wallets',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w800,
              color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Create at least 1 account or wallet to record your cash flow',
            style: TextStyle(
              fontSize: 14,
              color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
            ),
          ),
          const SizedBox(height: 20),

          // Add Wallet Button
          OutlinedButton.icon(
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              side: const BorderSide(color: AppColors.primaryGreenLight, width: 1.5),
            ),
            icon: const Icon(Icons.add_circle_outline_rounded, color: AppColors.primaryGreenLight),
            label: const Text(
              '+ Setup New Wallet',
              style: TextStyle(
                color: AppColors.primaryGreenLight,
                fontWeight: FontWeight.w700,
                fontSize: 15,
              ),
            ),
            onPressed: () => _showAddWalletModal(context, currencySymbol),
          ),
          const SizedBox(height: 16),

          // List of Created Wallets or Empty State
          Expanded(
            child: _onboardingWallets.isEmpty
                ? Center(
                    child: Container(
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: isDark ? AppColors.darkSurfaceVariant : Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: isDark ? AppColors.darkCardBorder : AppColors.lightCardBorder,
                        ),
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Text('👛', style: TextStyle(fontSize: 38)),
                          const SizedBox(height: 10),
                          Text(
                            'No wallets added yet',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Tap the button above to add Cash, Bank, UPI, or Cards',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 12,
                              color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                : ListView.separated(
                    itemCount: _onboardingWallets.length,
                    separatorBuilder: (context, index) => const SizedBox(height: 10),
                    itemBuilder: (context, index) {
                      final wallet = _onboardingWallets[index];
                      return Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: isDark ? AppColors.darkSurfaceVariant : Colors.white,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: isDark ? AppColors.darkCardBorder : AppColors.lightCardBorder,
                          ),
                        ),
                        child: Row(
                          children: [
                            Text(wallet.icon, style: const TextStyle(fontSize: 22)),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    wallet.name,
                                    style: TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w700,
                                      color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                                    ),
                                  ),
                                  Text(
                                    'Starting: $currencySymbol${wallet.initialBalance.toStringAsFixed(2)} • ${wallet.walletType.name.toUpperCase()}',
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete_outline_rounded, color: AppColors.expenseRed, size: 20),
                              onPressed: () {
                                setState(() => _onboardingWallets.removeAt(index));
                              },
                            ),
                          ],
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  void _showAddWalletModal(BuildContext context, String currencySymbol) {
    final nameCtrl = TextEditingController();
    final balanceCtrl = TextEditingController();
    final limitCtrl = TextEditingController();
    WalletType selectedType = WalletType.cash;
    String selectedIcon = '💵';
    bool enableLimit = false;

    final icons = ['💵', '🏦', '📱', '💳', '💰', '🪙', '💼'];

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text('Setup New Wallet'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Wallet Type', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 6,
                  children: WalletType.values.map((type) {
                    final isSel = selectedType == type;
                    return ChoiceChip(
                      label: Text(type.name.toUpperCase()),
                      selected: isSel,
                      onSelected: (_) {
                        setDialogState(() {
                          selectedType = type;
                          if (type == WalletType.cash) {
                            selectedIcon = '💵';
                            nameCtrl.text = 'Cash Wallet';
                          }
                          if (type == WalletType.bank) {
                            selectedIcon = '🏦';
                            nameCtrl.text = 'Bank Account';
                          }
                          if (type == WalletType.upi) {
                            selectedIcon = '📱';
                            nameCtrl.text = 'UPI / Online';
                          }
                          if (type == WalletType.creditCard) {
                            selectedIcon = '💳';
                            nameCtrl.text = 'Credit Card';
                          }
                          if (type == WalletType.savings) {
                            selectedIcon = '💰';
                            nameCtrl.text = 'Savings Account';
                          }
                        });
                      },
                    );
                  }).toList(),
                ),
                const SizedBox(height: 14),
                const Text('Wallet Name *', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                const SizedBox(height: 6),
                TextField(
                  controller: nameCtrl,
                  decoration: const InputDecoration(hintText: 'e.g. Cash or HDFC Bank'),
                ),
                const SizedBox(height: 14),
                Text('Starting Balance ($currencySymbol)', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                const SizedBox(height: 6),
                TextField(
                  controller: balanceCtrl,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: InputDecoration(
                    prefixText: '$currencySymbol ',
                    hintText: '0.00',
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
                      onChanged: (val) => setDialogState(() => enableLimit = val),
                    ),
                  ],
                ),
                if (enableLimit) ...[
                  const SizedBox(height: 6),
                  TextField(
                    controller: limitCtrl,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: InputDecoration(
                      prefixText: '$currencySymbol ',
                      hintText: 'Monthly limit',
                    ),
                  ),
                ],
                const SizedBox(height: 14),
                const Text('Choose Icon', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 10,
                  children: icons.map((icon) {
                    final isSel = selectedIcon == icon;
                    return InkWell(
                      onTap: () => setDialogState(() => selectedIcon = icon),
                      borderRadius: BorderRadius.circular(8),
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: isSel ? AppColors.primaryGreenLight.withValues(alpha: 0.25) : Colors.transparent,
                          borderRadius: BorderRadius.circular(8),
                          border: isSel ? Border.all(color: AppColors.primaryGreenLight) : null,
                        ),
                        child: Text(icon, style: const TextStyle(fontSize: 22)),
                      ),
                    );
                  }).toList(),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            ElevatedButton(
              onPressed: () {
                final name = nameCtrl.text.trim();
                if (name.isEmpty) return;

                final startBal = double.tryParse(balanceCtrl.text.trim()) ?? 0.0;
                final limit = enableLimit ? double.tryParse(limitCtrl.text.trim()) : null;

                final newWallet = WalletModel(
                  id: const Uuid().v4(),
                  name: name,
                  icon: selectedIcon,
                  colorValue: 0xFF2E7D32,
                  initialBalance: startBal,
                  currentBalance: startBal,
                  walletType: selectedType,
                  spendingLimit: limit,
                  isDefault: _onboardingWallets.isEmpty,
                );

                setState(() {
                  _onboardingWallets.add(newWallet);
                });

                Navigator.pop(ctx);
              },
              child: const Text('Add Wallet'),
            ),
          ],
        ),
      ),
    );
  }
}
