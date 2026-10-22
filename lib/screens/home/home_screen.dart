import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../models/transaction_model.dart';
import '../../providers/app_providers.dart';
import '../../theme/app_theme.dart';
import '../../widgets/balance_card.dart';
import '../../widgets/transaction_tile.dart';
import '../../widgets/nlp_quick_add_modal.dart';
import '../../widgets/user_avatar_widget.dart';
import '../../widgets/waving_hand_emoji.dart';
import '../../widgets/pending_transactions_capsule.dart';
import '../../widgets/subscription_candidate_card.dart';
import '../../widgets/sms_inbox_scanner_sheet.dart';
import '../../widgets/top_capsule_toast.dart';
import '../../services/notification_service.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> with WidgetsBindingObserver {
  bool _checkedStartupPermissions = false;
  bool _smsPermissionMissing = false;
  bool _dismissedPermissionBanner = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkAndAskStartupPermissions();
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _verifyCurrentPermissions();
    }
  }

  Future<void> _verifyCurrentPermissions() async {
    try {
      final perms = await ref.read(autoImportServiceProvider).checkPermissions();
      if (mounted) {
        setState(() {
          _smsPermissionMissing = !perms.isSmsListenerEnabled;
        });
      }
    } catch (_) {}
  }

  Future<void> _checkAndAskStartupPermissions() async {
    if (_checkedStartupPermissions) return;
    _checkedStartupPermissions = true;

    final settings = ref.read(settingsProvider);
    final autoImport = ref.read(autoImportServiceProvider);

    // 1. Check & Request Notification Permission (Android 13+)
    try {
      await NotificationService().requestPermissions();
    } catch (_) {}

    // 2. Check & Request SMS Permissions if missing and auto-read is enabled
    try {
      final perms = await autoImport.checkPermissions();
      if (!perms.isSmsListenerEnabled && settings.autoReadSmsEnabled) {
        final granted = await autoImport.requestSmsPermission();
        if (mounted) {
          setState(() {
            _smsPermissionMissing = !granted;
          });
        }
        if (granted) {
          ref.read(pendingTransactionsProvider.notifier).fetchPendingTransactions();
        }
      } else {
        if (mounted) {
          setState(() {
            _smsPermissionMissing = !perms.isSmsListenerEnabled && settings.autoReadSmsEnabled;
          });
        }
      }
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(settingsProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        titleSpacing: 16,
        title: Consumer(
          builder: (context, ref, child) {
            final palette = ref.watch(activePaletteProvider);
            return InkWell(
              onTap: () => context.push('/settings'),
              borderRadius: BorderRadius.circular(20),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    UserAvatarWidget(
                      avatarId: settings.selectedAvatarId,
                      size: 38,
                      glowColor: palette.primary,
                      fallbackInitial: settings.userName,
                    ),
                    const SizedBox(width: 12),
                    Text(
                      'Hi, ${settings.userName} ',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: isDark
                            ? AppColors.darkTextPrimary
                            : AppColors.lightTextPrimary,
                      ),
                    ),
                    const WavingHandEmoji(fontSize: 18),
                  ],
                ),
              ),
            );
          },
        ),
        actions: [
          Consumer(
            builder: (context, ref, child) {
              final unreadCount = ref.watch(unreadNotificationsCountProvider);
              return Stack(
                alignment: Alignment.center,
                children: [
                  IconButton(
                    icon: const Icon(Icons.notifications_outlined, size: 24),
                    tooltip: 'Notifications',
                    onPressed: () => context.push('/notifications'),
                  ),
                  if (unreadCount > 0)
                    Positioned(
                      top: 10,
                      right: 10,
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: const BoxDecoration(
                          color: AppColors.accentOrange,
                          shape: BoxShape.circle,
                        ),
                        constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
                        child: Text(
                          '$unreadCount',
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 9,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                ],
              );
            },
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SafeArea(
        bottom: false,
        child: RefreshIndicator(
          onRefresh: () async {
            await ref.read(pendingTransactionsProvider.notifier).fetchPendingTransactions();
          },
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 1. Top Pinned Area: Hero Balance Card + Quick Hub + Capsule + Section Header
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Missing Permission Banner (Prompt on startup / dismissed)
                    if (_smsPermissionMissing && !_dismissedPermissionBanner)
                      _buildMissingPermissionBanner(isDark),

                    // Balance Summary Card (with Integrated Accounts Carousel)
                    const BalanceCard(),
                    const SizedBox(height: 14),

                    // Quick Hub Row: Recurring, Goals, & Debts
                    Consumer(
                      builder: (context, ref, _) {
                        final recurringRules = ref.watch(recurringRulesProvider);
                        final activeRulesCount = recurringRules.where((r) => r.isActive).length;
                        final totalLent = ref.watch(totalLentProvider);
                        final totalBorrowed = ref.watch(totalBorrowedProvider);
                        final netDebt = totalLent - totalBorrowed;
                        final goals = ref.watch(goalsProvider);
                        final totalSavedInGoals = ref.watch(totalSavedInGoalsProvider);

                        return SizedBox(
                          height: 62,
                          child: ListView(
                            scrollDirection: Axis.horizontal,
                            physics: const BouncingScrollPhysics(),
                            children: [
                              _buildQuickHubCard(
                                title: 'Recurring Dues',
                                subtitle: '$activeRulesCount active',
                                subtitleColor: AppColors.primaryGreenLight,
                                icon: Icons.autorenew_rounded,
                                iconColor: AppColors.primaryGreenLight,
                                bgColor: isDark ? const Color(0xFF18221B) : const Color(0xFFEDF7F1),
                                borderColor: AppColors.primaryGreenLight.withValues(alpha: isDark ? 0.3 : 0.4),
                                onTap: () => context.push('/recurring-rules'),
                                isDark: isDark,
                              ),
                              const SizedBox(width: 8),
                              _buildQuickHubCard(
                                title: 'Savings Goals',
                                subtitle: '${goals.length} goals (${settings.formatCompact(totalSavedInGoals)})',
                                subtitleColor: Colors.amber,
                                icon: Icons.savings_rounded,
                                iconColor: Colors.amber,
                                bgColor: isDark ? const Color(0xFF231E14) : const Color(0xFFFEF8E8),
                                borderColor: Colors.amber.withValues(alpha: isDark ? 0.3 : 0.4),
                                onTap: () => context.push('/wallets'),
                                isDark: isDark,
                              ),
                              const SizedBox(width: 8),
                              _buildQuickHubCard(
                                title: 'Debts & Loans',
                                subtitle: netDebt >= 0
                                    ? '+${settings.formatCompact(netDebt)}'
                                    : '-${settings.formatCompact(netDebt.abs())}',
                                subtitleColor: netDebt >= 0 ? AppColors.incomeGreen : AppColors.expenseRed,
                                icon: Icons.handshake_outlined,
                                iconColor: AppColors.infoBlue,
                                bgColor: isDark ? const Color(0xFF141E28) : const Color(0xFFEEF5FB),
                                borderColor: AppColors.infoBlue.withValues(alpha: isDark ? 0.3 : 0.4),
                                onTap: () => context.push('/debts'),
                                isDark: isDark,
                              ),
                            ],
                          ),
                        );
                      },
                    ),

                    // Detected Payments Capsule
                    const PendingTransactionsCapsule(),

                    // Subscription Auto-Detector Confirmation Banner
                    Consumer(
                      builder: (context, ref, _) {
                        final candidates = ref.watch(subscriptionCandidatesProvider);
                        if (candidates.isEmpty) return const SizedBox.shrink();
                        return SubscriptionCandidateCard(candidate: candidates.first);
                      },
                    ),
                    const SizedBox(height: 14),

                    // Section Header: Recent Transactions
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Recent Transactions',
                          style: TextStyle(
                            fontSize: 15.5,
                            fontWeight: FontWeight.w700,
                            color: isDark
                                ? AppColors.darkTextPrimary
                                : AppColors.lightTextPrimary,
                          ),
                        ),
                        TextButton(
                          onPressed: () => context.push('/transactions'),
                          style: TextButton.styleFrom(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            minimumSize: Size.zero,
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                'See All',
                                style: TextStyle(
                                  color: AppColors.primaryGreenLight,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 13,
                                ),
                              ),
                              SizedBox(width: 4),
                              Icon(
                                Icons.arrow_forward_rounded,
                                size: 14,
                                color: AppColors.primaryGreenLight,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),

              // 2. Containerized Scrolling Recent Activity Section with Day Indicators
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Consumer(
                    builder: (context, ref, _) {
                      final allTxs = ref.watch(transactionsProvider);
                      final displayList = allTxs.take(30).toList();
                      final bottomPadding = MediaQuery.paddingOf(context).bottom + 92;

                      if (displayList.isEmpty) {
                        return SingleChildScrollView(
                          physics: const AlwaysScrollableScrollPhysics(),
                          padding: EdgeInsets.only(bottom: bottomPadding),
                          child: Container(
                            width: double.infinity,
                            margin: const EdgeInsets.only(top: 8),
                            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 36),
                            decoration: BoxDecoration(
                              color: isDark
                                  ? AppColors.darkSurfaceVariant
                                  : Colors.white,
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: isDark
                                    ? AppColors.darkCardBorder
                                    : AppColors.lightCardBorder,
                              ),
                            ),
                            child: Column(
                              children: [
                                const Text(
                                  '🌿',
                                  style: TextStyle(fontSize: 42),
                                ),
                                const SizedBox(height: 12),
                                Text(
                                  'No transactions logged yet',
                                  style: TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w700,
                                    color: isDark
                                        ? AppColors.darkTextPrimary
                                        : AppColors.lightTextPrimary,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Tap + button below to record an entry',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: isDark
                                        ? AppColors.darkTextSecondary
                                        : AppColors.lightTextSecondary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      }

                      // Group recent transactions by day header
                      final Map<String, List<TransactionModel>> grouped = {};
                      for (final tx in displayList) {
                        final key = _formatDateHeader(tx.date);
                        grouped.putIfAbsent(key, () => []).add(tx);
                      }

                      final groupKeys = grouped.keys.toList();

                      return Container(
                        decoration: BoxDecoration(
                          color: isDark
                              ? AppColors.darkSurfaceVariant
                              : Colors.white,
                          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
                          border: Border.all(
                            color: isDark
                                ? AppColors.darkCardBorder
                                : AppColors.lightCardBorder,
                          ),
                        ),
                        clipBehavior: Clip.antiAlias,
                        child: ListView.builder(
                          physics: const AlwaysScrollableScrollPhysics(),
                          padding: EdgeInsets.only(bottom: bottomPadding),
                          itemCount: groupKeys.length,
                          itemBuilder: (context, groupIndex) {
                            final dateKey = groupKeys[groupIndex];
                            final txs = grouped[dateKey]!;

                            return Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                // Day Indicator Header Bar
                                Container(
                                  width: double.infinity,
                                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                                  decoration: BoxDecoration(
                                    color: isDark
                                        ? const Color(0xFF191D26)
                                        : const Color(0xFFF4F6FA),
                                    border: Border(
                                      top: groupIndex > 0
                                          ? BorderSide(
                                              color: isDark
                                                  ? AppColors.darkCardBorder
                                                  : AppColors.lightCardBorder,
                                              width: 1,
                                            )
                                          : BorderSide.none,
                                      bottom: BorderSide(
                                        color: isDark
                                            ? AppColors.darkCardBorder
                                            : AppColors.lightCardBorder,
                                        width: 0.8,
                                      ),
                                    ),
                                  ),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(
                                        dateKey.toUpperCase(),
                                        style: TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w800,
                                          letterSpacing: 0.8,
                                          color: isDark
                                              ? AppColors.darkTextSecondary
                                              : AppColors.lightTextSecondary,
                                        ),
                                      ),
                                      Text(
                                        '${txs.length} ${txs.length == 1 ? 'entry' : 'entries'}',
                                        style: TextStyle(
                                          fontSize: 10.5,
                                          fontWeight: FontWeight.w600,
                                          color: isDark ? Colors.white38 : Colors.black38,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                // Transaction Tiles for this date
                                for (int i = 0; i < txs.length; i++) ...[
                                  TransactionTile(
                                    transaction: txs[i],
                                    onTap: () => context.push(
                                      '/transaction-detail',
                                      extra: txs[i],
                                    ),
                                  ),
                                  if (i < txs.length - 1)
                                    Divider(
                                      height: 1,
                                      color: isDark
                                          ? AppColors.darkCardBorder
                                          : AppColors.lightCardBorder,
                                    ),
                                ],
                              ],
                            );
                          },
                        ),
                      );
                    },
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatDateHeader(DateTime dt) {
    final now = DateTime.now();
    if (dt.year == now.year && dt.month == now.month && dt.day == now.day) {
      return 'Today, ${DateFormat('d MMM').format(dt)}';
    }
    final yesterday = now.subtract(const Duration(days: 1));
    if (dt.year == yesterday.year &&
        dt.month == yesterday.month &&
        dt.day == yesterday.day) {
      return 'Yesterday, ${DateFormat('d MMM').format(dt)}';
    }
    if (dt.year == now.year) {
      return DateFormat('EEE, d MMM').format(dt);
    }
    return DateFormat('d MMM yyyy').format(dt);
  }

  Widget _buildMissingPermissionBanner(bool isDark) {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF26190B) : const Color(0xFFFFF7ED),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: AppColors.accentOrange.withValues(alpha: isDark ? 0.35 : 0.45),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.accentOrange.withValues(alpha: isDark ? 0.08 : 0.05),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.accentOrange.withValues(alpha: 0.18),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.sms_failed_rounded,
                  color: AppColors.accentOrange,
                  size: 20,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'SMS Permission Missing',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        color: isDark
                            ? AppColors.darkTextPrimary
                            : AppColors.lightTextPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    const Text(
                      'Auto-track bank spending',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: AppColors.accentOrange,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: Icon(
                  Icons.close_rounded,
                  size: 18,
                  color: isDark ? AppColors.darkTextTertiary : AppColors.lightTextTertiary,
                ),
                tooltip: 'Dismiss',
                onPressed: () {
                  setState(() {
                    _dismissedPermissionBanner = true;
                  });
                },
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Pocket parses incoming bank SMS on your device to log expenses automatically. Grant permission to activate live tracking.',
            style: TextStyle(
              fontSize: 12,
              height: 1.35,
              color: isDark
                  ? AppColors.darkTextSecondary
                  : AppColors.lightTextSecondary,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              ElevatedButton.icon(
                onPressed: () async {
                  final autoImport = ref.read(autoImportServiceProvider);
                  final granted = await autoImport.requestSmsPermission();
                  if (granted) {
                    setState(() {
                      _smsPermissionMissing = false;
                    });
                    if (mounted) {
                      TopCapsuleToast.show(
                        context,
                        message: 'SMS Auto-Read Activated ✓',
                        isSuccess: true,
                      );
                    }
                    ref.read(pendingTransactionsProvider.notifier).fetchPendingTransactions();
                  } else {
                    if (mounted) {
                      TopCapsuleToast.show(
                        context,
                        message: 'Opening App Settings to grant SMS permission...',
                        isSuccess: false,
                      );
                    }
                    await autoImport.openAppSettings();
                  }
                },
                icon: const Icon(Icons.security_update_good_rounded, size: 16),
                label: const Text('Grant Permission'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.accentOrange,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 0,
                ),
              ),
              const SizedBox(width: 10),
              TextButton(
                onPressed: () {
                  setState(() {
                    _dismissedPermissionBanner = true;
                  });
                },
                child: Text(
                  'Not Now',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: isDark
                        ? AppColors.darkTextTertiary
                        : AppColors.lightTextTertiary,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildQuickHubCard({
    required String title,
    required String subtitle,
    required Color subtitleColor,
    required IconData icon,
    required Color iconColor,
    required Color bgColor,
    required Color borderColor,
    required VoidCallback onTap,
    required bool isDark,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        constraints: const BoxConstraints(minWidth: 155),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: borderColor, width: 1.2),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(7),
              decoration: BoxDecoration(
                color: iconColor.withValues(alpha: 0.18),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 16, color: iconColor),
            ),
            const SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                    color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                  ),
                ),
                const SizedBox(height: 1.5),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: subtitleColor,
                  ),
                ),
              ],
            ),
            const SizedBox(width: 4),
            Icon(Icons.chevron_right_rounded, size: 16, color: isDark ? AppColors.darkTextTertiary : AppColors.lightTextTertiary),
          ],
        ),
      ),
    );
  }
}
