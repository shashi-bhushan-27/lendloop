import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lendloop/core/constants/app_colors.dart';
import 'package:lendloop/models/item_model.dart';
import 'package:lendloop/providers/items_provider.dart';
import 'package:lendloop/providers/auth_provider.dart';
import 'package:lendloop/services/api_client.dart';
import 'package:dio/dio.dart';

class ItemDetailPage extends ConsumerWidget {
  final String itemId;
  const ItemDetailPage({super.key, required this.itemId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final itemAsync = ref.watch(itemDetailProvider(itemId));
    final currentUser = ref.watch(currentUserProvider).value;

    return Scaffold(
      body: itemAsync.when(
        loading: () => const Scaffold(body: Center(child: CircularProgressIndicator())),
        error: (e, _) => Scaffold(body: Center(child: Text('Error: $e'))),
        data: (item) => _ItemDetailBody(item: item, currentUserId: currentUser?.id),
      ),
    );
  }
}

class _ItemDetailBody extends ConsumerStatefulWidget {
  final ItemModel item;
  final String? currentUserId;
  const _ItemDetailBody({required this.item, this.currentUserId});

  @override
  ConsumerState<_ItemDetailBody> createState() => _ItemDetailBodyState();
}

class _ItemDetailBodyState extends ConsumerState<_ItemDetailBody> {
  bool _isRequesting = false;
  int _borrowDays = 7;

  bool get _isOwner => widget.currentUserId == widget.item.ownerId;

  static const _conditionColors = {
    ItemCondition.new_item: AppColors.success,
    ItemCondition.like_new: AppColors.success,
    ItemCondition.good: AppColors.info,
    ItemCondition.fair: AppColors.warning,
    ItemCondition.poor: AppColors.error,
  };

  static const _categoryIcons = {
    ItemCategory.books: Icons.menu_book_rounded,
    ItemCategory.electronics: Icons.devices_rounded,
    ItemCategory.stationery: Icons.edit_rounded,
    ItemCategory.equipment: Icons.handyman_rounded,
    ItemCategory.clothing: Icons.checkroom_rounded,
    ItemCategory.sports: Icons.sports_soccer_rounded,
    ItemCategory.tools: Icons.build_rounded,
    ItemCategory.other: Icons.category_rounded,
  };

  Future<void> _sendBorrowRequest() async {
    setState(() => _isRequesting = true);
    try {
      final now = DateTime.now();
      final startDate = now.toIso8601String().split('T')[0];             // "YYYY-MM-DD"
      final endDate = now.add(Duration(days: _borrowDays - 1))
          .toIso8601String().split('T')[0];
      await ApiClient.instance.post('/borrow', data: {
        'item_id': widget.item.id,
        'proposed_start_date': startDate,
        'proposed_end_date': endDate,
        'message': 'Hi, I would like to borrow this item for $_borrowDays day(s).',
      });
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Borrow request sent!'), backgroundColor: AppColors.success),
      );
      if (context.canPop()) { context.pop(); } else { context.go('/items'); }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to send request: $e'), backgroundColor: AppColors.error),
      );
    } finally {
      if (mounted) setState(() => _isRequesting = false);
    }
  }

  Future<void> _toggleListing(WidgetRef ref) async {
    final isActive = widget.item.isActive;
    final action = isActive ? 'unlist' : 'relist';
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(isActive ? 'Unlist Item?' : 'Relist Item?'),
        content: Text(isActive
            ? 'This will hide "${widget.item.title}" from the browse list. You can relist it anytime.'
            : 'This will make "${widget.item.title}" visible to other students again.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: isActive ? AppColors.error : AppColors.success,
            ),
            child: Text(isActive ? 'Unlist' : 'Relist',
                style: const TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() => _isRequesting = true);
    try {
      if (isActive) {
        await ApiClient.instance.delete('/items/${widget.item.id}');
      } else {
        await ApiClient.instance.put('/items/${widget.item.id}', data: {'is_active': true});
      }
      ref.invalidate(itemsProvider);
      ref.invalidate(myItemsProvider);
      ref.invalidate(availableItemsProvider);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(isActive ? 'Item unlisted successfully' : 'Item relisted successfully'),
          backgroundColor: AppColors.success,
        ),
      );
      if (context.canPop()) { context.pop(); } else { context.go('/items'); }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to $action item: $e'), backgroundColor: AppColors.error),
      );
    } finally {
      if (mounted) setState(() => _isRequesting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final condColor = _conditionColors[widget.item.condition] ?? AppColors.info;
    final catIcon = _categoryIcons[widget.item.category] ?? Icons.category_rounded;

    return CustomScrollView(
      slivers: [
        SliverAppBar(
          expandedHeight: widget.item.imageUrls.isNotEmpty ? 280 : 120,
          pinned: true,
          flexibleSpace: FlexibleSpaceBar(
            background: widget.item.imageUrls.isNotEmpty
                ? Image.network(widget.item.imageUrls.first, fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Container(
                      decoration: const BoxDecoration(gradient: AppColors.primaryGradient),
                      child: const Icon(Icons.image_not_supported, size: 64, color: Colors.white54),
                    ))
                : Container(
                    decoration: const BoxDecoration(gradient: AppColors.primaryGradient),
                    child: Icon(catIcon, size: 80, color: Colors.white30),
                  ),
          ),
          leading: IconButton(
            icon: const CircleAvatar(
              backgroundColor: Colors.black45,
              child: Icon(Icons.arrow_back, color: Colors.white, size: 18),
            ),
            onPressed: () => context.pop(),
          ),
        ),

        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Title + status
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text(widget.item.title, style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700)),
                    ),
                    const SizedBox(width: 12),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: widget.item.isAvailable ? AppColors.success.withOpacity(0.15) : AppColors.error.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        widget.item.isAvailable ? 'Available' : 'Unavailable',
                        style: TextStyle(
                          color: widget.item.isAvailable ? AppColors.success : AppColors.error,
                          fontSize: 12, fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // Chips row
                Wrap(
                  spacing: 8, runSpacing: 8,
                  children: [
                    _chip(condColor, widget.item.condition.name, Icons.star_rate_rounded),
                    _chip(AppColors.primary, widget.item.category.name, catIcon),
                    _chip(AppColors.textSecondary, '${widget.item.maxBorrowDays} days max', Icons.calendar_today_outlined),
                    _chip(AppColors.textSecondary, '${widget.item.viewCount} views', Icons.visibility_outlined),
                  ],
                ),
                const SizedBox(height: 20),

                // Description
                Text('Description', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
                const SizedBox(height: 8),
                Text(widget.item.description, style: theme.textTheme.bodyMedium?.copyWith(height: 1.6, color: AppColors.textSecondary)),
                const SizedBox(height: 20),

                // Pickup location
                _infoRow(Icons.location_on_outlined, 'Pickup Location', widget.item.pickupLocation),
                const SizedBox(height: 12),

                // Deposit
                if (widget.item.requiresDeposit)
                  _infoRow(Icons.currency_rupee, 'Security Deposit',
                    widget.item.depositAmount != null
                        ? '₹${widget.item.depositAmount!.toStringAsFixed(0)} (refundable)'
                        : 'Required'),

                const SizedBox(height: 24),

                // Borrow duration selector (only if available + not owner)
                if (widget.item.isAvailable && !_isOwner) ...[
                  Text('Borrow Duration', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      IconButton.outlined(
                        onPressed: _borrowDays > 1 ? () => setState(() => _borrowDays--) : null,
                        icon: const Icon(Icons.remove),
                      ),
                      const SizedBox(width: 16),
                      Text('$_borrowDays days',
                        style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700, color: AppColors.primary)),
                      const SizedBox(width: 16),
                      IconButton.outlined(
                        onPressed: _borrowDays < widget.item.maxBorrowDays ? () => setState(() => _borrowDays++) : null,
                        icon: const Icon(Icons.add),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),

                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: ElevatedButton.icon(
                      onPressed: _isRequesting ? null : _sendBorrowRequest,
                      icon: _isRequesting
                          ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                          : const Icon(Icons.handshake_outlined, color: Colors.white),
                      label: Text(_isRequesting ? 'Sending...' : 'Request to Borrow',
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Colors.white)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                    ),
                  ),
                ],

                if (_isOwner) ...[                  
                  // Owner badge
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.info.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.info.withOpacity(0.2)),
                    ),
                    child: const Row(children: [
                      Icon(Icons.inventory_2_outlined, color: AppColors.info, size: 18),
                      SizedBox(width: 8),
                      Text('Your listed item', style: TextStyle(color: AppColors.info, fontWeight: FontWeight.w600, fontSize: 13)),
                    ]),
                  ),
                  const SizedBox(height: 12),
                  // Unlist / Relist button
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: ElevatedButton.icon(
                      onPressed: _isRequesting ? null : () => _toggleListing(ref),
                      icon: _isRequesting
                          ? const SizedBox(height: 18, width: 18,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                          : Icon(
                              widget.item.isActive ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                              color: Colors.white),
                      label: Text(
                        _isRequesting
                            ? 'Processing...'
                            : widget.item.isActive ? 'Unlist This Item' : 'Relist This Item',
                        style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: Colors.white),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: widget.item.isActive ? AppColors.error : AppColors.success,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                    ),
                  ),
                ],

                const SizedBox(height: 32),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _chip(Color color, String label, IconData icon) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
    decoration: BoxDecoration(
      color: color.withOpacity(0.1),
      borderRadius: BorderRadius.circular(20),
    ),
    child: Row(mainAxisSize: MainAxisSize.min, children: [
      Icon(icon, size: 14, color: color),
      const SizedBox(width: 4),
      Text(label, style: TextStyle(fontSize: 12, color: color, fontWeight: FontWeight.w500)),
    ]),
  );

  Widget _infoRow(IconData icon, String label, String value) => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Icon(icon, size: 20, color: AppColors.primary),
      const SizedBox(width: 10),
      Expanded(child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w600)),
        ],
      )),
    ],
  );
}
