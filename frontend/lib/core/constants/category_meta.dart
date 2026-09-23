/// Shared category display metadata (label + icon) for [ItemCategory].
/// Single source of truth — reused by item detail, item creation, browse,
/// and the home page category grids.

import 'package:flutter/material.dart';
import 'package:lendloop/models/item_model.dart';

class CategoryMeta {
  final String label;
  final IconData icon;
  const CategoryMeta(this.label, this.icon);
}

const Map<ItemCategory, CategoryMeta> kCategoryMeta = {
  ItemCategory.books: CategoryMeta('Books', Icons.menu_book_rounded),
  ItemCategory.electronics: CategoryMeta('Electronics', Icons.devices_rounded),
  ItemCategory.stationery: CategoryMeta('Stationery', Icons.edit_rounded),
  ItemCategory.equipment: CategoryMeta('Equipment', Icons.handyman_rounded),
  ItemCategory.clothing: CategoryMeta('Clothing', Icons.checkroom_rounded),
  ItemCategory.sports: CategoryMeta('Sports', Icons.sports_soccer_rounded),
  ItemCategory.tools: CategoryMeta('Tools', Icons.build_rounded),
  ItemCategory.other: CategoryMeta('Other', Icons.category_rounded),
};
