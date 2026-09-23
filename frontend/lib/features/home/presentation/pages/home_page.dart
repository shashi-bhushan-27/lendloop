import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lendloop/core/constants/app_colors.dart';
import 'package:lendloop/core/constants/category_meta.dart';
import 'package:lendloop/models/item_model.dart';
import 'package:lendloop/models/user_model.dart';
import 'package:lendloop/providers/auth_provider.dart';
import 'package:lendloop/providers/items_provider.dart';
import 'package:lendloop/widgets/item_card.dart';
import 'package:lendloop/widgets/trust_score_badge.dart';

/// Home page — a collapsing header (greeting, pickup location, search) above
/// a pinned Borrow/Lend tab bar. Borrow browses everything available from
/// peers; Lend manages your own listings. Both read from existing providers
/// (itemsSearchProvider / myItemsProvider) — nothing new on the backend.
class HomePage extends ConsumerStatefulWidget {
  const HomePage({super.key});

  @override
  ConsumerState<HomePage> createState() => _HomePageState();
}

class _HomePageState extends ConsumerState<HomePage> with SingleTickerProviderStateMixin {
  late final TabController _tabs;
  final _searchCtrl = TextEditingController();
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 2, vsync: this);
    _tabs.addListener(_onTabChanged);
  }

  void _onTabChanged() {
    // Rebuild so the sticky tab bar's indicator color tracks the active tab,
    // whether it changed via tap or swipe.
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _tabs.removeListener(_onTabChanged);
    _tabs.dispose();
    _searchCtrl.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  void _onSearchChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 400), () {
      ref.read(searchQueryProvider.notifier).state = value.trim();
    });
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(currentUserProvider).value;

    return Scaffold(
      body: NestedScrollView(
        headerSliverBuilder: (context, innerBoxIsScrolled) => [
          SliverToBoxAdapter(
            child: _HeaderContent(
              user: user,
              searchCtrl: _searchCtrl,
              onSearchChanged: _onSearchChanged,
            ),
          ),
          SliverPersistentHeader(
            pinned: true,
            delegate: _TabBarDelegate(
              TabBar(
                controller: _tabs,
                indicatorSize: TabBarIndicatorSize.tab,
                indicatorWeight: 3,
                labelColor: _tabs.index == 0 ? AppColors.borrowColor : AppColors.lendColor,
                unselectedLabelColor: AppColors.textSecondary,
                indicatorColor: _tabs.index == 0 ? AppColors.borrowColor : AppColors.lendColor,
                tabs: const [
                  Tab(icon: Icon(Icons.shopping_bag_outlined), text: 'Borrow'),
                  Tab(icon: Icon(Icons.storefront_outlined), text: 'Lend'),
                ],
              ),
            ),
          ),
        ],
        body: TabBarView(
          controller: _tabs,
          children: [
            _BorrowTab(currentUserId: user?.id),
            _LendTab(user: user),
          ],
        ),
      ),
    );
  }
}

// ── Sticky tab bar wrapper ──────────────────────────────────────────────

class _TabBarDelegate extends SliverPersistentHeaderDelegate {
  final TabBar tabBar;
  _TabBarDelegate(this.tabBar);

  @override
  double get minExtent => tabBar.preferredSize.height;
  @override
  double get maxExtent => tabBar.preferredSize.height;

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) {
    return ColoredBox(
      color: Theme.of(context).scaffoldBackgroundColor,
      child: tabBar,
    );
  }

  @override
  bool shouldRebuild(covariant _TabBarDelegate oldDelegate) => oldDelegate.tabBar != tabBar;
}

// ── Header (greeting + pickup location + search) ────────────────────────

class _HeaderContent extends StatelessWidget {
  final UserModel? user;
  final TextEditingController searchCtrl;
  final ValueChanged<String> onSearchChanged;

  const _HeaderContent({required this.user, required this.searchCtrl, required this.onSearchChanged});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(gradient: AppColors.primaryGradient),
      padding: const EdgeInsets.fromLTRB(20, 56, 20, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Hello, ${user?.fullName.split(' ').first ?? 'Student'}! 👋',
                      style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w700, color: Colors.white),
                    ),
                    const SizedBox(height: 6),
                    GestureDetector(
                      onTap: () => context.push('/profile'),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.location_on_rounded, color: Colors.white70, size: 15),
                          const SizedBox(width: 4),
                          Flexible(
                            child: Text(
                              user?.hostelBlock?.isNotEmpty == true
                                  ? 'VIT Campus · ${user!.hostelBlock}'
                                  : 'VIT Campus · Add your block',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(color: Colors.white70, fontSize: 12.5),
                            ),
                          ),
                          const Icon(Icons.keyboard_arrow_down_rounded, color: Colors.white70, size: 16),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.handshake_outlined, color: Colors.white),
                tooltip: 'Borrow Requests',
                onPressed: () => context.push('/borrow'),
              ),
              IconButton(
                icon: const Icon(Icons.notifications_none_rounded, color: Colors.white),
                onPressed: () => context.push('/notifications'),
              ),
              if (user != null) TrustScoreBadge(score: user!.trustScore, size: 44),
            ],
          ),
          const SizedBox(height: 18),
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.08), blurRadius: 10, offset: const Offset(0, 4))],
            ),
            child: TextField(
              controller: searchCtrl,
              onChanged: onSearchChanged,
              decoration: InputDecoration(
                hintText: 'Search items to borrow...',
                hintStyle: const TextStyle(color: AppColors.textTertiary, fontSize: 14),
                prefixIcon: const Icon(Icons.search_rounded, color: AppColors.textTertiary),
                suffixIcon: IconButton(
                  icon: const Icon(Icons.qr_code_scanner_rounded, color: AppColors.borrowColor),
                  tooltip: 'Scan QR',
                  onPressed: () => context.push('/qr/scan'),
                ),
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(vertical: 14),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Borrow tab ───────────────────────────────────────────────────────────

class _BorrowTab extends ConsumerWidget {
  final String? currentUserId;
  const _BorrowTab({required this.currentUserId});

  List<ItemModel> _trending(List<ItemModel> items) {
    final sorted = [...items]
      ..sort((a, b) => (b.borrowCount * 2 + b.viewCount).compareTo(a.borrowCount * 2 + a.viewCount));
    return sorted.take(5).toList();
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final itemsAsync = ref.watch(itemsSearchProvider);
    final selectedCategory = ref.watch(categoryFilterProvider);

    return RefreshIndicator(
      onRefresh: () async => ref.invalidate(itemsSearchProvider),
      child: itemsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => _ErrorState(message: '$e', onRetry: () => ref.invalidate(itemsSearchProvider)),
        data: (all) {
          final items = all.where((i) => i.ownerId != currentUserId).toList();
          final trending = selectedCategory == null ? _trending(items) : <ItemModel>[];

          return CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              if (trending.isNotEmpty)
                SliverToBoxAdapter(child: _TrendingBanner(items: trending)),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(0, 16, 0, 8),
                  child: _CategoryChipRow(
                    color: AppColors.borrowColor,
                    selected: selectedCategory,
                    onSelect: (cat) =>
                        ref.read(categoryFilterProvider.notifier).state = cat?.name,
                  ),
                ),
              ),
              if (items.isEmpty)
                const SliverFillRemaining(
                  child: _EmptyState(
                    icon: Icons.search_off_rounded,
                    message: 'No items available to borrow right now',
                  ),
                )
              else
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
                  sliver: SliverGrid(
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2, childAspectRatio: 0.72,
                      crossAxisSpacing: 12, mainAxisSpacing: 12,
                    ),
                    delegate: SliverChildBuilderDelegate(
                      (context, i) => ItemCard(
                        item: items[i],
                        onTap: () => context.push('/items/${items[i].id}'),
                      ),
                      childCount: items.length,
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

// ── Lend tab ─────────────────────────────────────────────────────────────

class _LendTab extends ConsumerWidget {
  final UserModel? user;
  const _LendTab({required this.user});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final myItemsAsync = ref.watch(myItemsProvider);

    return RefreshIndicator(
      onRefresh: () async => ref.invalidate(myItemsProvider),
      child: myItemsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => _ErrorState(message: '$e', onRetry: () => ref.invalidate(myItemsProvider)),
        data: (myItems) {
          return CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 4),
                  child: Row(
                    children: [
                      Expanded(child: _statChip(
                        'Active Listings', '${myItems.where((i) => i.isActive).length}', Icons.inventory_2_outlined)),
                      const SizedBox(width: 12),
                      Expanded(child: _statChip(
                        'Total Lends', '${user?.totalLends ?? 0}', Icons.handshake_outlined)),
                    ],
                  ),
                ),
              ),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: _CategoryChipRow(
                    color: AppColors.lendColor,
                    selected: null,
                    quickList: true,
                    onSelect: (cat) => context.push('/items/new?category=${cat?.name}'),
                  ),
                ),
              ),
              if (myItems.isEmpty)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
                    child: _ListFirstItemCta(),
                  ),
                )
              else
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
                  sliver: SliverGrid(
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2, childAspectRatio: 0.72,
                      crossAxisSpacing: 12, mainAxisSpacing: 12,
                    ),
                    delegate: SliverChildBuilderDelegate(
                      (context, i) => ItemCard(
                        item: myItems[i],
                        onTap: () => context.push('/items/${myItems[i].id}'),
                      ),
                      childCount: myItems.length,
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }

  Widget _statChip(String label, String value, IconData icon) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: AppColors.lendColor.withOpacity(0.08),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.lendColor.withOpacity(0.18)),
        ),
        child: Row(
          children: [
            Icon(icon, color: AppColors.lendColor, size: 18),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(value, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
                  Text(label, style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
                ],
              ),
            ),
          ],
        ),
      );
}

// ── Shared bits ──────────────────────────────────────────────────────────

class _TrendingBanner extends StatelessWidget {
  final List<ItemModel> items;
  const _TrendingBanner({required this.items});

  static const _gradients = [
    AppColors.primaryGradient,
    AppColors.accentGradient,
    AppColors.cardGradient,
  ];

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(0, 16, 0, 4),
      child: SizedBox(
        height: 168,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 20),
          itemCount: items.length,
          separatorBuilder: (_, __) => const SizedBox(width: 14),
          itemBuilder: (context, i) {
            final item = items[i];
            final gradient = _gradients[i % _gradients.length];
            return GestureDetector(
              onTap: () => context.push('/items/${item.id}'),
              child: Container(
                width: 300,
                decoration: BoxDecoration(gradient: gradient, borderRadius: BorderRadius.circular(20)),
                clipBehavior: Clip.antiAlias,
                child: Stack(
                  children: [
                    if (item.imageUrls.isNotEmpty)
                      Positioned.fill(
                        child: Opacity(
                          opacity: 0.35,
                          child: CachedNetworkImage(
                            imageUrl: item.imageUrls.first,
                            fit: BoxFit.cover,
                            errorWidget: (_, __, ___) => const SizedBox.shrink(),
                          ),
                        ),
                      ),
                    Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: const Row(mainAxisSize: MainAxisSize.min, children: [
                              Icon(Icons.local_fire_department_rounded, color: Colors.white, size: 14),
                              SizedBox(width: 4),
                              Text('Trending', style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w700)),
                            ]),
                          ),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(item.title, maxLines: 1, overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w700)),
                              const SizedBox(height: 4),
                              Text(kCategoryMeta[item.category]?.label ?? 'Item',
                                  style: const TextStyle(color: Colors.white70, fontSize: 12)),
                            ],
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
      ),
    );
  }
}

/// Horizontal category chips. In "quick list" mode (Lend tab) tapping a
/// category jumps straight into a prefilled listing form instead of
/// filtering — there's no persistent selection to show in that mode.
class _CategoryChipRow extends StatelessWidget {
  final Color color;
  final String? selected;
  final bool quickList;
  final void Function(ItemCategory?) onSelect;

  const _CategoryChipRow({
    required this.color,
    required this.selected,
    required this.onSelect,
    this.quickList = false,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 38,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        children: [
          if (!quickList)
            _chip('All', selected == null, () => onSelect(null)),
          ...kCategoryMeta.entries.map((e) => Padding(
                padding: const EdgeInsets.only(left: 8),
                child: _chip(e.value.label, selected == e.key.name, () => onSelect(e.key), icon: e.value.icon),
              )),
        ],
      ),
    );
  }

  Widget _chip(String label, bool isSelected, VoidCallback onTap, {IconData? icon}) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? color : color.withOpacity(0.08),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: isSelected ? color : color.withOpacity(0.2)),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          if (icon != null) ...[
            Icon(icon, size: 14, color: isSelected ? Colors.white : color),
            const SizedBox(width: 6),
          ],
          Text(label, style: TextStyle(
              fontSize: 12.5, fontWeight: FontWeight.w600,
              color: isSelected ? Colors.white : color)),
        ]),
      ),
    );
  }
}

class _ListFirstItemCta extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => context.push('/items/new'),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(gradient: AppColors.accentGradient, borderRadius: BorderRadius.circular(18)),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(color: Colors.white.withOpacity(0.2), borderRadius: BorderRadius.circular(12)),
              child: const Icon(Icons.add_rounded, color: Colors.white),
            ),
            const SizedBox(width: 14),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('List your first item', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 15)),
                  SizedBox(height: 2),
                  Text("Lend something and start earning trust score", style: TextStyle(color: Colors.white70, fontSize: 12)),
                ],
              ),
            ),
            const Icon(Icons.arrow_forward_rounded, color: Colors.white),
          ],
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final IconData icon;
  final String message;
  const _EmptyState({required this.icon, required this.message});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 64, color: AppColors.textTertiary.withOpacity(0.5)),
          const SizedBox(height: 12),
          Text(message, style: const TextStyle(color: AppColors.textSecondary, fontSize: 13), textAlign: TextAlign.center),
        ],
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  const _ErrorState({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.wifi_off_rounded, size: 48, color: AppColors.textTertiary),
          const SizedBox(height: 12),
          Text('Error: $message', style: const TextStyle(color: AppColors.error, fontSize: 13), textAlign: TextAlign.center),
          TextButton(onPressed: onRetry, child: const Text('Retry')),
        ],
      ),
    );
  }
}
