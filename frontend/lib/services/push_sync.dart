/// Push-driven sync.
///
/// The backend sends an FCM push on every state change the other party needs
/// to see (request received/approved/declined/cancelled, pickup confirmed,
/// return initiated/completed). Treating each push as a "something changed"
/// signal and refetching keeps lender and borrower in sync in real time,
/// without keeping a socket open — which wouldn't survive the free-tier
/// backend sleeping anyway.

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lendloop/features/borrow/presentation/pages/borrow_requests_page.dart';
import 'package:lendloop/features/notifications/presentation/pages/notifications_page.dart';
import 'package:lendloop/providers/auth_provider.dart';
import 'package:lendloop/providers/items_provider.dart';
import 'package:lendloop/providers/transaction_provider.dart';

/// Refetch everything a push could have changed. Only providers something is
/// currently watching actually hit the network; the rest just go stale and
/// reload next time they're read.
void refreshForPush(WidgetRef ref) {
  if (ref.read(currentUserProvider).valueOrNull == null) return;
  ref.invalidate(notificationsProvider);
  ref.invalidate(transactionsProvider);
  ref.invalidate(borrowRequestsProvider);
  ref.invalidate(itemsSearchProvider);
  ref.invalidate(availableItemsProvider);
  ref.invalidate(myItemsProvider);
  ref.read(currentUserProvider.notifier).refresh(); // trust score, lend counts
}

/// Where tapping a push should take the user.
String routeForPush(Map<String, dynamic> data) {
  switch (data['reference_type']) {
    case 'transaction':
      return '/transactions';
    case 'borrow_request':
      return '/borrow';
    default:
      return '/notifications';
  }
}
