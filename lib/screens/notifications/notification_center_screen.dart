import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../models/notification_model.dart';
import '../../providers/app_providers.dart';
import '../../theme/app_theme.dart';

class NotificationCenterScreen extends ConsumerWidget {
  const NotificationCenterScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notifs = ref.watch(notificationsProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Notifications & Alerts'),
        actions: [
          if (notifs.isNotEmpty) ...[
            TextButton(
              onPressed: () => ref.read(notificationsProvider.notifier).markAllAsRead(),
              child: const Text('Mark Read', style: TextStyle(color: AppColors.primaryGreenLight, fontWeight: FontWeight.w600)),
            ),
            IconButton(
              icon: const Icon(Icons.delete_sweep_outlined, color: AppColors.expenseRed),
              tooltip: 'Clear All',
              onPressed: () => ref.read(notificationsProvider.notifier).clearAll(),
            ),
          ],
          const SizedBox(width: 8),
        ],
      ),
      body: notifs.isEmpty
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: AppColors.primaryGreenLight.withValues(alpha: 0.15),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.notifications_none_rounded, size: 48, color: AppColors.primaryGreenLight),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'All Caught Up!',
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                        color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'You will see budget warnings, recurring payment notices, and daily check-ins here.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 13,
                        color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            )
          : ListView.separated(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              itemCount: notifs.length,
              separatorBuilder: (context, index) => const SizedBox(height: 10),
              itemBuilder: (context, index) {
                final notif = notifs[index];

                return InkWell(
                  onTap: () => ref.read(notificationsProvider.notifier).markAsRead(notif.id),
                  borderRadius: BorderRadius.circular(16),
                  child: Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: notif.isRead
                          ? (isDark ? AppColors.darkSurfaceVariant : Colors.white)
                          : (isDark ? const Color(0xFF1F2F23) : const Color(0xFFE8F5E9)),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: notif.isRead
                            ? (isDark ? AppColors.darkCardBorder : AppColors.lightCardBorder)
                            : AppColors.primaryGreenLight.withValues(alpha: 0.5),
                        width: notif.isRead ? 1 : 1.5,
                      ),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: notif.type.color.withValues(alpha: 0.18),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(notif.type.icon, size: 20, color: notif.type.color),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Expanded(
                                    child: Text(
                                      notif.title,
                                      style: TextStyle(
                                        fontSize: 14,
                                        fontWeight: notif.isRead ? FontWeight.w600 : FontWeight.w800,
                                        color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                                      ),
                                    ),
                                  ),
                                  Text(
                                    DateFormat('d MMM, h:mm a').format(notif.createdAt),
                                    style: TextStyle(
                                      fontSize: 10,
                                      color: isDark ? AppColors.darkTextTertiary : AppColors.lightTextTertiary,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              Text(
                                notif.message,
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
              },
            ),
    );
  }
}
