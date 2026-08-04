/// Items Providers
///
/// Provides:
/// - [searchQueryProvider]  — Current search string (debounced by UI layer)
/// - [categoryFilterProvider] — Current category filter
/// - [itemsSearchProvider]  — Fetches items from API with search + category params
/// - [availableItemsProvider] — Alias for unfiltered available items (Home page)
/// - [myItemsProvider]      — Current user's own listings
/// - [itemDetailProvider]   — Single item by ID

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lendloop/models/item_model.dart';
import 'package:lendloop/services/api_client.dart';

// ── Search & Filter State ──────────────────────────────

/// Holds the current search query string entered by the user.
final searchQueryProvider = StateProvider<String>((ref) => '');

/// Holds the current category filter (null = all categories).
final categoryFilterProvider = StateProvider<String?>((ref) => null);

// ── Items Search Provider ──────────────────────────────

/// Fetches items from the API using current search query and category filter.
/// Re-executes whenever searchQueryProvider or categoryFilterProvider changes.
final itemsSearchProvider = FutureProvider<List<ItemModel>>((ref) async {
  final search = ref.watch(searchQueryProvider).trim();
  final category = ref.watch(categoryFilterProvider);

  final queryParams = <String, dynamic>{};
  if (search.isNotEmpty) queryParams['search'] = search;
  if (category != null && category.isNotEmpty) queryParams['category'] = category;

  final response = await ApiClient.instance.get(
    '/items',
    params: queryParams,
  );
  final data = response.data as Map<String, dynamic>;
  return (data['items'] as List)
      .map((e) => ItemModel.fromJson(e as Map<String, dynamic>))
      .toList();
});

// ── Available Items (Home page — no search filter) ─────

/// Fetches all available items without any search filter.
/// Used on the Home page for the general browse view.
final availableItemsProvider = FutureProvider<List<ItemModel>>((ref) async {
  final response = await ApiClient.instance.get('/items');
  final data = response.data as Map<String, dynamic>;
  return (data['items'] as List)
      .map((e) => ItemModel.fromJson(e as Map<String, dynamic>))
      .where((i) => i.status == ItemStatus.available)
      .toList();
});

// ── My Items ───────────────────────────────────────────

final myItemsProvider = FutureProvider<List<ItemModel>>((ref) async {
  final response = await ApiClient.instance.get('/items/my');
  return (response.data as List)
      .map((e) => ItemModel.fromJson(e as Map<String, dynamic>))
      .toList();
});

// ── Backward-compatible alias ─────────────────────────

/// Legacy alias kept for pages that still reference itemsProvider.
/// Delegates to itemsSearchProvider (which reads current search state).
final itemsProvider = itemsSearchProvider;

final itemDetailProvider = FutureProvider.family<ItemModel, String>(
  (ref, itemId) async {
    final response = await ApiClient.instance.get('/items/$itemId');
    return ItemModel.fromJson(response.data as Map<String, dynamic>);
  },
);
