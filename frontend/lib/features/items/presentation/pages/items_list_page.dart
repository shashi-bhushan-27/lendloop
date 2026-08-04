/// Items List Page — Browse & Search + My Listings

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lendloop/core/constants/app_colors.dart';
import 'package:lendloop/providers/items_provider.dart';
import 'package:lendloop/widgets/item_card.dart';
import 'package:lendloop/models/item_model.dart';

class ItemsListPage extends ConsumerStatefulWidget {
  const ItemsListPage({super.key});

  @override
  ConsumerState<ItemsListPage> createState() => _ItemsListPageState();
}

class _ItemsListPageState extends ConsumerState<ItemsListPage>
    with SingleTickerProviderStateMixin {
  final _searchCtrl = TextEditingController();
  late TabController _tabs;
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    _tabs.dispose();
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
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Items'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add_rounded),
            onPressed: () => context.push('/items/new'),
            tooltip: 'List an Item',
          ),
        ],
        bottom: TabBar(
          controller: _tabs,
          tabs: const [
            Tab(text: 'Browse', icon: Icon(Icons.explore_outlined, size: 18)),
            Tab(text: 'My Listings', icon: Icon(Icons.inventory_2_outlined, size: 18)),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabs,
        children: [
          // --- Browse Tab ---
          Column(children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: TextField(
                controller: _searchCtrl,
                decoration: InputDecoration(
                  hintText: 'Search by title or description...',
                  prefixIcon: const Icon(Icons.search_rounded),
                  suffixIcon: _searchCtrl.text.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear),
                          onPressed: () {
                            _searchCtrl.clear();
                            ref.read(searchQueryProvider.notifier).state = '';
                            setState(() {});
                          },
                        )
                      : null,
                ),
                onChanged: (v) {
                  setState(() {});
                  _onSearchChanged(v);
                },
              ),
            ),
            // Category filter chips
            Consumer(
              builder: (context, ref, _) {
                final selectedCategory = ref.watch(categoryFilterProvider);
                return SizedBox(
                  height: 52,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    children: [
                      _CategoryChip(
                        label: 'All',
                        selected: selectedCategory == null,
                        onTap: () => ref.read(categoryFilterProvider.notifier).state = null,
                      ),
                      ...ItemCategory.values.map((cat) => _CategoryChip(
                        label: cat.name.replaceAll('_', ' ').capitalize(),
                        selected: selectedCategory == cat.name,
                        onTap: () => ref.read(categoryFilterProvider.notifier).state = cat.name,
                      )),
                    ],
                  ),
                );
              },
            ),
            const Expanded(child: _BrowseGrid()),
          ]),

          // --- My Listings Tab ---
          _MyListingsTab(),
        ],
      ),
    );
  }
}

class _BrowseGrid extends ConsumerWidget {
  const _BrowseGrid();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final itemsAsync = ref.watch(itemsSearchProvider);
    return itemsAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          const Icon(Icons.wifi_off_rounded, size: 48, color: AppColors.textTertiary),
          const SizedBox(height: 16),
          Text('Could not load items', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          TextButton(
            onPressed: () => ref.invalidate(itemsSearchProvider),
            child: const Text('Retry'),
          ),
        ]),
      ),
      data: (items) {
        if (items.isEmpty) {
          return Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            const Icon(Icons.search_off, size: 64, color: AppColors.textTertiary),
            const SizedBox(height: 16),
            Text('No items found', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            const Text(
              'Try different keywords or clear the filter',
              style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
              textAlign: TextAlign.center,
            ),
          ]));
        }
        return RefreshIndicator(
          onRefresh: () async => ref.invalidate(itemsSearchProvider),
          child: GridView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: items.length,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2, childAspectRatio: 0.72,
              crossAxisSpacing: 12, mainAxisSpacing: 12,
            ),
            itemBuilder: (_, i) => ItemCard(
              item: items[i],
              onTap: () => context.push('/items/${items[i].id}'),
            ),
          ),
        );
      },
    );
  }
}

class _MyListingsTab extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final myItemsAsync = ref.watch(myItemsProvider);
    return myItemsAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Error: $e')),
      data: (items) {
        if (items.isEmpty) {
          return Center(child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.inventory_2_outlined, size: 72,
                  color: AppColors.textSecondary.withOpacity(0.3)),
              const SizedBox(height: 16),
              const Text('No items listed yet', style: TextStyle(fontSize: 16, color: AppColors.textSecondary)),
              const SizedBox(height: 8),
              const Text('Tap the + button to list your first item',
                  style: TextStyle(color: AppColors.textSecondary, fontSize: 13)),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: () => context.push('/items/new'),
                icon: const Icon(Icons.add, color: Colors.white),
                label: const Text('List an Item', style: TextStyle(color: Colors.white)),
                style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
              ),
            ],
          ));
        }
        return RefreshIndicator(
          onRefresh: () async => ref.invalidate(myItemsProvider),
          child: ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: items.length,
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemBuilder: (_, i) {
              final item = items[i];
              return GestureDetector(
                onTap: () => context.push('/items/${item.id}'),
                child: Container(
                  decoration: BoxDecoration(
                    color: Theme.of(context).cardColor,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: item.isActive
                          ? AppColors.success.withOpacity(0.3)
                          : AppColors.error.withOpacity(0.3),
                    ),
                  ),
                  padding: const EdgeInsets.all(14),
                  child: Row(children: [
                    // Item image or category icon
                    ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: item.imageUrls.isNotEmpty
                          ? Image.network(item.imageUrls.first,
                              width: 64, height: 64, fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) => _categoryBox(item))
                          : _categoryBox(item),
                    ),
                    const SizedBox(width: 14),
                    Expanded(child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(item.title,
                          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
                          maxLines: 1, overflow: TextOverflow.ellipsis),
                        const SizedBox(height: 4),
                        Text(item.category.name, style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
                        const SizedBox(height: 6),
                        Row(children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: item.isActive
                                  ? AppColors.success.withOpacity(0.15)
                                  : AppColors.error.withOpacity(0.15),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              item.isActive ? 'Listed' : 'Unlisted',
                              style: TextStyle(
                                fontSize: 11, fontWeight: FontWeight.w600,
                                color: item.isActive ? AppColors.success : AppColors.error,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text('${item.viewCount} views',
                              style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
                        ]),
                      ],
                    )),
                    const Icon(Icons.chevron_right_rounded, color: AppColors.textSecondary),
                  ]),
                ),
              );
            },
          ),
        );
      },
    );
  }

  Widget _categoryBox(ItemModel item) {
    const icons = {
      ItemCategory.books: Icons.menu_book_rounded,
      ItemCategory.electronics: Icons.devices_rounded,
      ItemCategory.stationery: Icons.edit_rounded,
      ItemCategory.equipment: Icons.handyman_rounded,
      ItemCategory.clothing: Icons.checkroom_rounded,
      ItemCategory.sports: Icons.sports_soccer_rounded,
      ItemCategory.tools: Icons.build_rounded,
      ItemCategory.other: Icons.category_rounded,
    };
    return Container(
      width: 64, height: 64,
      decoration: BoxDecoration(
        gradient: AppColors.primaryGradient,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Icon(icons[item.category] ?? Icons.category_rounded, color: Colors.white, size: 28),
    );
  }
}

class _CategoryChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _CategoryChip({required this.label, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        margin: const EdgeInsets.only(right: 8),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          color: selected ? AppColors.primary : AppColors.surfaceVariant,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: selected ? AppColors.primary : AppColors.border),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13, fontWeight: FontWeight.w500,
            color: selected ? Colors.white : AppColors.textSecondary,
          ),
        ),
      ),
    );
  }
}

extension StringExt on String {
  String capitalize() => isEmpty ? this : '${this[0].toUpperCase()}${substring(1)}';
}
