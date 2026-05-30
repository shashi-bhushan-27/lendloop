enum ItemCategory { electronics, books, stationery, equipment, clothing, sports, tools, other }
enum ItemCondition { new_item, like_new, good, fair, poor }
enum ItemStatus { available, borrowed, reserved, unavailable }

class ItemModel {
  final String id;
  final String ownerId;
  final String title;
  final String description;
  final ItemCategory category;
  final ItemCondition condition;
  final List<String> tags;
  final List<String> imageUrls;
  final int maxBorrowDays;
  final bool requiresDeposit;
  final double? depositAmount;
  final String pickupLocation;
  final ItemStatus status;
  final bool isActive;
  final int viewCount;
  final int borrowCount;
  final DateTime createdAt;

  const ItemModel({
    required this.id,
    required this.ownerId,
    required this.title,
    required this.description,
    required this.category,
    required this.condition,
    required this.tags,
    required this.imageUrls,
    required this.maxBorrowDays,
    required this.requiresDeposit,
    this.depositAmount,
    required this.pickupLocation,
    required this.status,
    required this.isActive,
    required this.viewCount,
    required this.borrowCount,
    required this.createdAt,
  });

  factory ItemModel.fromJson(Map<String, dynamic> json) {
    return ItemModel(
      id: json['id'] as String,
      ownerId: json['owner_id'] as String,
      title: json['title'] as String,
      description: json['description'] as String? ?? '',
      category: ItemCategory.values.firstWhere(
        (e) => e.name == (json['category'] as String? ?? 'other'),
        orElse: () => ItemCategory.other,
      ),
      condition: ItemCondition.values.firstWhere(
        (e) => e.name == (json['condition'] as String? ?? 'good'),
        orElse: () => ItemCondition.good,
      ),
      tags: (json['tags'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? [],
      imageUrls: (json['image_urls'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? [],
      maxBorrowDays: (json['max_borrow_days'] as num?)?.toInt() ?? 7,
      requiresDeposit: json['requires_deposit'] as bool? ?? false,
      depositAmount: (json['deposit_amount'] as num?)?.toDouble(),
      pickupLocation: json['pickup_location'] as String? ?? '',
      status: ItemStatus.values.firstWhere(
        (e) => e.name == (json['status'] as String? ?? 'available'),
        orElse: () => ItemStatus.available,
      ),
      isActive: json['is_active'] as bool? ?? true,
      viewCount: (json['view_count'] as num?)?.toInt() ?? 0,
      borrowCount: (json['borrow_count'] as num?)?.toInt() ?? 0,
      createdAt: DateTime.tryParse(json['created_at'] as String? ?? '') ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'owner_id': ownerId,
    'title': title,
    'description': description,
    'category': category.name,
    'condition': condition.name,
    'tags': tags,
    'image_urls': imageUrls,
    'max_borrow_days': maxBorrowDays,
    'requires_deposit': requiresDeposit,
    'deposit_amount': depositAmount,
    'pickup_location': pickupLocation,
    'status': status.name,
    'is_active': isActive,
    'view_count': viewCount,
    'borrow_count': borrowCount,
    'created_at': createdAt.toIso8601String(),
  };

  bool get isAvailable => status == ItemStatus.available && isActive;
}
