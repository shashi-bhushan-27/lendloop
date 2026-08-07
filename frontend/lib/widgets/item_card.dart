/// Item Card Widget

import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:shimmer/shimmer.dart';
import 'package:lendloop/core/constants/app_colors.dart';
import 'package:lendloop/models/item_model.dart';

class ItemCard extends StatelessWidget {
  final ItemModel item;
  final VoidCallback onTap;

  const ItemCard({super.key, required this.item, required this.onTap});

  Color get _statusColor {
    switch (item.status) {
      case ItemStatus.available:   return AppColors.statusAvailable;
      case ItemStatus.borrowed:    return AppColors.statusBorrowed;
      case ItemStatus.reserved:    return AppColors.statusBorrowed;
      case ItemStatus.unavailable: return AppColors.statusUnavailable;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(color: AppColors.shadow, blurRadius: 12, offset: const Offset(0, 4)),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Image
            ClipRRect(
              borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
              child: AspectRatio(
                aspectRatio: 4 / 3,
                child: item.imageUrls.isEmpty
                    ? Container(
                        color: AppColors.surfaceVariant,
                        child: const Icon(Icons.image_outlined, size: 48, color: AppColors.textTertiary),
                      )
                    : CachedNetworkImage(
                        imageUrl: item.imageUrls.first,
                        fit: BoxFit.cover,
                        placeholder: (_, __) => Shimmer.fromColors(
                          baseColor: AppColors.surfaceVariant,
                          highlightColor: AppColors.surface,
                          child: Container(color: AppColors.surfaceVariant),
                        ),
                        errorWidget: (_, __, ___) => Container(
                          color: AppColors.surfaceVariant,
                          child: const Icon(Icons.broken_image, color: AppColors.textTertiary),
                        ),
                      ),
              ),
            ),
            // Info
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: _statusColor.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          item.status.name.toUpperCase(),
                          style: TextStyle(
                            fontSize: 10, fontWeight: FontWeight.w700,
                            color: _statusColor, letterSpacing: 0.5,
                          ),
                        ),
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            '${item.maxBorrowDays}d max',
                            style: theme.textTheme.labelSmall?.copyWith(color: AppColors.textTertiary),
                          ),
                          if (item.status == ItemStatus.available && item.expiresAt != null)
                            Text(
                              'Exp: ${item.expiresAt!.difference(DateTime.now()).inDays}d',
                              style: theme.textTheme.labelSmall?.copyWith(
                                color: AppColors.warning,
                                fontSize: 9,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    item.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      const Icon(Icons.location_on_outlined, size: 12, color: AppColors.textTertiary),
                      const SizedBox(width: 2),
                      Expanded(
                        child: Text(
                          item.pickupLocation,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.bodySmall?.copyWith(color: AppColors.textTertiary),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
