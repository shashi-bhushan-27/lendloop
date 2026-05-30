/// Notifications Page

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lendloop/core/constants/app_colors.dart';
import 'package:lendloop/services/api_client.dart';

final notificationsProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final response = await ApiClient.instance.get('/notifications');
  return (response.data as List).cast<Map<String, dynamic>>();
});

class NotificationsPage extends ConsumerWidget {
  const NotificationsPage({super.key});

  IconData _iconForType(String type) {
    switch (type) {
      case 'borrow_request':      return Icons.handshake_outlined;
      case 'request_approved':    return Icons.check_circle_outline;
      case 'request_rejected':    return Icons.cancel_outlined;
      case 'pickup_reminder':     return Icons.alarm_outlined;
      case 'return_reminder':     return Icons.assignment_return_outlined;
      case 'overdue_alert':       return Icons.warning_amber_rounded;
      case 'item_returned':       return Icons.keyboard_return_rounded;
      case 'review_received':     return Icons.star_outline_rounded;
      default:                    return Icons.notifications_outlined;
    }
  }

  Color _colorForType(String type) {
    if (type == 'request_approved' || type == 'item_returned') return AppColors.success;
    if (type == 'request_rejected' || type == 'overdue_alert') return AppColors.error;
    if (type == 'review_received') return AppColors.accent;
    return AppColors.primary;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final notifAsync = ref.watch(notificationsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Notifications')),
      body: notifAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (notifs) {
          if (notifs.isEmpty) {
            return Center(
              child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                const Icon(Icons.notifications_none_rounded, size: 72, color: AppColors.textTertiary),
                const SizedBox(height: 16),
                Text('No notifications yet', style: theme.textTheme.titleMedium),
                const SizedBox(height: 8),
                Text('Activity alerts will appear here', 
                    style: theme.textTheme.bodyMedium?.copyWith(color: AppColors.textSecondary)),
              ]),
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.symmetric(vertical: 8),
            itemCount: notifs.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (_, i) {
              final n = notifs[i];
              final type = n['type'] as String? ?? 'system';
              final isRead = n['is_read'] as bool? ?? false;
              return ListTile(
                leading: Container(
                  width: 44, height: 44,
                  decoration: BoxDecoration(
                    color: _colorForType(type).withOpacity(0.12),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(_iconForType(type), color: _colorForType(type), size: 22),
                ),
                title: Text(
                  n['title'] as String? ?? '',
                  style: TextStyle(
                    fontWeight: isRead ? FontWeight.w400 : FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
                subtitle: Text(n['body'] as String? ?? '',
                    style: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
                    maxLines: 2, overflow: TextOverflow.ellipsis),
                tileColor: isRead ? null : AppColors.primary.withOpacity(0.04),
              );
            },
          );
        },
      ),
    );
  }
}
