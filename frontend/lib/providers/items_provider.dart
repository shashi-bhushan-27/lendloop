/// Items Providers

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lendloop/models/item_model.dart';
import 'package:lendloop/services/api_client.dart';

final itemsProvider = FutureProvider<List<ItemModel>>((ref) async {
  final response = await ApiClient.instance.get('/items');
  final data = response.data as Map<String, dynamic>;
  return (data['items'] as List)
      .map((e) => ItemModel.fromJson(e as Map<String, dynamic>))
      .toList();
});

/// Alias for available-only items (used on Home page)
final availableItemsProvider = FutureProvider<List<ItemModel>>((ref) async {
  final all = await ref.watch(itemsProvider.future);
  return all.where((i) => i.status == ItemStatus.available).toList();
});

final myItemsProvider = FutureProvider<List<ItemModel>>((ref) async {
  final response = await ApiClient.instance.get('/items/my');
  return (response.data as List)
      .map((e) => ItemModel.fromJson(e as Map<String, dynamic>))
      .toList();
});

final itemDetailProvider = FutureProvider.family<ItemModel, String>(
  (ref, itemId) async {
    final response = await ApiClient.instance.get('/items/$itemId');
    return ItemModel.fromJson(response.data as Map<String, dynamic>);
  },
);

