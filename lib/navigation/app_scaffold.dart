import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../providers/app_providers.dart';
import '../theme/app_theme.dart';
import '../widgets/quick_add_transaction_dialog.dart';

class AppScaffold extends ConsumerStatefulWidget {
  final StatefulNavigationShell navigationShell;
  final List<Widget> children;

  const AppScaffold({
    super.key,
    required this.navigationShell,
    required this.children,
  });

  @override
  ConsumerState<AppScaffold> createState() => _AppScaffoldState();
}

class _AppScaffoldState extends ConsumerState<AppScaffold> {
  DateTime? _lastBackPressTime;
  late PageController _pageController;

  @override
  void initState() {
    super.initState();
    _pageController = PageController(initialPage: widget.navigationShell.currentIndex);
  }

  @override
  void didUpdateWidget(AppScaffold oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_pageController.hasClients &&
        widget.navigationShell.currentIndex != _pageController.page?.round()) {
      _pageController.animateToPage(
        widget.navigationShell.currentIndex,
        duration: const Duration(milliseconds: 280),
        curve: Curves.easeOutCubic,
      );
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _handlePopInvoked(bool didPop) {
    if (didPop) return;

    // If currently on a non-home tab (Analytics, Wallets, Settings), switch to Home (tab 0)
    if (widget.navigationShell.currentIndex != 0) {
      _onNavTapped(0);
      return;
    }

    // If on Home tab, check for double back tap within 2 seconds
    final now = DateTime.now();
    if (_lastBackPressTime == null ||
        now.difference(_lastBackPressTime!) > const Duration(seconds: 2)) {
      _lastBackPressTime = now;
      ScaffoldMessenger.of(context).clearSnackBars();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          behavior: SnackBarBehavior.floating,
          content: Text('Press back again to exit'),
          duration: Duration(seconds: 2),
        ),
      );
    } else {
      SystemNavigator.pop();
    }
  }

  void _onNavTapped(int index) {
    HapticFeedback.lightImpact();
    if (_pageController.hasClients) {
      _pageController.animateToPage(
        index,
        duration: const Duration(milliseconds: 280),
        curve: Curves.easeOutCubic,
      );
    }
    widget.navigationShell.goBranch(
      index,
      initialLocation: index == widget.navigationShell.currentIndex,
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final currentIndex = widget.navigationShell.currentIndex;
    final palette = ref.watch(activePaletteProvider);

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) => _handlePopInvoked(didPop),
      child: Scaffold(
        extendBody: true,
        body: PageView(
          controller: _pageController,
          physics: const BouncingScrollPhysics(),
          onPageChanged: (index) {
            widget.navigationShell.goBranch(
              index,
              initialLocation: false,
            );
          },
          children: widget.children,
        ),
        bottomNavigationBar: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: Container(
              height: 64,
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
              decoration: BoxDecoration(
                color: isDark
                    ? const Color(0xFF141414).withValues(alpha: 0.96)
                    : Colors.white.withValues(alpha: 0.96),
                borderRadius: BorderRadius.circular(32),
                border: Border.all(
                  color: isDark
                      ? Colors.white.withValues(alpha: 0.12)
                      : Colors.black.withValues(alpha: 0.08),
                  width: 1.2,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: isDark ? 0.45 : 0.1),
                    blurRadius: 20,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  // 1. Home Tab (Branch 0)
                  _buildNavItem(
                    branchIndex: 0,
                    currentIndex: currentIndex,
                    selectedIcon: Icons.grid_view_rounded,
                    unselectedIcon: Icons.grid_view_outlined,
                    label: 'Home',
                    isDark: isDark,
                    palette: palette,
                  ),

                  // 2. Analytics Tab (Branch 1)
                  _buildNavItem(
                    branchIndex: 1,
                    currentIndex: currentIndex,
                    selectedIcon: Icons.donut_large_rounded,
                    unselectedIcon: Icons.donut_large_outlined,
                    label: 'Analytics',
                    isDark: isDark,
                    palette: palette,
                  ),

                  // 3. Center Floating Elevated (+) Quick Add Button
                  _buildCenterQuickAddButton(context, palette),

                  // 4. Wallets Tab (Branch 2)
                  _buildNavItem(
                    branchIndex: 2,
                    currentIndex: currentIndex,
                    selectedIcon: Icons.account_balance_wallet_rounded,
                    unselectedIcon: Icons.account_balance_wallet_outlined,
                    label: 'Wallets',
                    isDark: isDark,
                    palette: palette,
                  ),

                  // 5. Settings Tab (Branch 3)
                  _buildNavItem(
                    branchIndex: 3,
                    currentIndex: currentIndex,
                    selectedIcon: Icons.settings_rounded,
                    unselectedIcon: Icons.settings_outlined,
                    label: 'Settings',
                    isDark: isDark,
                    palette: palette,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem({
    required int branchIndex,
    required int currentIndex,
    required IconData selectedIcon,
    required IconData unselectedIcon,
    required String label,
    required bool isDark,
    required AppThemePalette palette,
  }) {
    final isSelected = currentIndex == branchIndex;

    return Expanded(
      child: InkWell(
        onTap: () => _onNavTapped(branchIndex),
        borderRadius: BorderRadius.circular(24),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeInOut,
          padding: const EdgeInsets.symmetric(vertical: 4),
          decoration: BoxDecoration(
            color: isSelected
                ? palette.primary.withValues(alpha: isDark ? 0.18 : 0.12)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(24),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                isSelected ? selectedIcon : unselectedIcon,
                size: 21,
                color: isSelected
                    ? palette.primary
                    : (isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary),
              ),
              const SizedBox(height: 2),
              Text(
                label,
                style: TextStyle(
                  fontSize: 10.5,
                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                  color: isSelected
                      ? palette.primary
                      : (isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCenterQuickAddButton(BuildContext context, AppThemePalette palette) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            HapticFeedback.mediumImpact();
            QuickAddTransactionDialog.show(context);
          },
          borderRadius: BorderRadius.circular(24),
          child: Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  palette.primaryDark,
                  palette.primary,
                ],
              ),
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: palette.primary.withValues(alpha: 0.4),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: const Icon(
              Icons.add_rounded,
              color: Colors.white,
              size: 28,
            ),
          ),
        ),
      ),
    );
  }
}
