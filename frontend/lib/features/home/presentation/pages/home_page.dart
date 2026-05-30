import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lendloop/core/constants/app_colors.dart';
import 'package:lendloop/providers/auth_provider.dart';
import 'package:lendloop/providers/items_provider.dart';
import 'package:lendloop/widgets/item_card.dart';
import 'package:lendloop/widgets/trust_score_badge.dart';

class HomePage extends ConsumerWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    // .value extracts the UserModel? from AsyncValue<UserModel?>
    final user = ref.watch(currentUserProvider).value;
    final itemsAsync = ref.watch(availableItemsProvider);

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 180,
            pinned: true,
            flexibleSpace: FlexibleSpaceBar(
              background: Container(
                decoration: const BoxDecoration(gradient: AppColors.primaryGradient),
                padding: const EdgeInsets.fromLTRB(24, 60, 24, 20),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Column(
                      mainAxisAlignment: MainAxisAlignment.end,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Hello, ${user?.fullName.split(' ').first ?? 'Student'}! 👋',
                          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: Colors.white),
                        ),
                        const SizedBox(height: 4),
                        const Text('What would you like to borrow today?',
                            style: TextStyle(fontSize: 13, color: Colors.white70)),
                      ],
                    ),
                    if (user != null)
                      TrustScoreBadge(score: user.trustScore, size: 56),
                  ],
                ),
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      _QuickAction(
                        icon: Icons.add_box_outlined, label: 'List Item',
                        color: AppColors.primary,
                        onTap: () => context.push('/items/new'),
                      ),
                      const SizedBox(width: 12),
                      _QuickAction(
                        icon: Icons.qr_code_scanner_rounded, label: 'Scan QR',
                        color: AppColors.accent,
                        onTap: () => context.push('/qr/scan'),
                      ),
                      const SizedBox(width: 12),
                      _QuickAction(
                        icon: Icons.history_rounded, label: 'History',
                        color: AppColors.success,
                        onTap: () => context.push('/transactions'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  Text('Available Items', style: theme.textTheme.titleLarge),
                  const SizedBox(height: 4),
                  Text('Browse items your peers are lending',
                      style: theme.textTheme.bodySmall?.copyWith(color: AppColors.textSecondary)),
                ],
              ),
            ),
          ),
          itemsAsync.when(
            loading: () => const SliverFillRemaining(
              child: Center(child: CircularProgressIndicator()),
            ),
            error: (e, _) => SliverFillRemaining(
              child: Center(child: Text('Error loading items: $e')),
            ),
            data: (items) => items.isEmpty
                ? const SliverFillRemaining(
                    child: Center(child: Text('No items available yet')),
                  )
                : SliverPadding(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                    sliver: SliverGrid(
                      delegate: SliverChildBuilderDelegate(
                        (context, index) => ItemCard(
                          item: items[index],
                          onTap: () => context.push('/items/${items[index].id}'),
                        ),
                        childCount: items.length,
                      ),
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 2, childAspectRatio: 0.72,
                        crossAxisSpacing: 12, mainAxisSpacing: 12,
                      ),
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

class _QuickAction extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _QuickAction({required this.icon, required this.label, required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 16),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: color.withOpacity(0.2)),
          ),
          child: Column(children: [
            Icon(icon, color: color, size: 28),
            const SizedBox(height: 8),
            Text(label, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: color)),
          ]),
        ),
      ),
    );
  }
}
