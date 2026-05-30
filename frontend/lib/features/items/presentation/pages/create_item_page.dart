import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:dio/dio.dart' show FormData, MultipartFile;
import 'package:lendloop/core/constants/app_colors.dart';
import 'package:lendloop/models/item_model.dart';
import 'package:lendloop/services/api_client.dart';
import 'package:lendloop/providers/items_provider.dart';

class CreateItemPage extends ConsumerStatefulWidget {
  const CreateItemPage({super.key});
  @override
  ConsumerState<CreateItemPage> createState() => _CreateItemPageState();
}

class _CreateItemPageState extends ConsumerState<CreateItemPage> {
  final _formKey = GlobalKey<FormState>();
  final _titleCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  final _locationCtrl = TextEditingController();
  final _maxDaysCtrl = TextEditingController(text: '7');
  final _depositCtrl = TextEditingController();

  ItemCategory _category = ItemCategory.other;
  ItemCondition _condition = ItemCondition.good;
  bool _requiresDeposit = false;
  bool _isLoading = false;
  String _loadingMessage = 'Creating listing...';

  // Selected images
  final List<XFile> _selectedImages = [];
  final ImagePicker _picker = ImagePicker();

  static const _categories = {
    ItemCategory.books: ('Books', Icons.menu_book_rounded),
    ItemCategory.electronics: ('Electronics', Icons.devices_rounded),
    ItemCategory.stationery: ('Stationery', Icons.edit_rounded),
    ItemCategory.equipment: ('Equipment', Icons.handyman_rounded),
    ItemCategory.clothing: ('Clothing', Icons.checkroom_rounded),
    ItemCategory.sports: ('Sports', Icons.sports_soccer_rounded),
    ItemCategory.tools: ('Tools', Icons.build_rounded),
    ItemCategory.other: ('Other', Icons.category_rounded),
  };

  static const _conditions = {
    ItemCondition.new_item: 'New',
    ItemCondition.like_new: 'Like New',
    ItemCondition.good: 'Good',
    ItemCondition.fair: 'Fair',
    ItemCondition.poor: 'Poor',
  };

  @override
  void dispose() {
    _titleCtrl.dispose(); _descCtrl.dispose(); _locationCtrl.dispose();
    _maxDaysCtrl.dispose(); _depositCtrl.dispose();
    super.dispose();
  }

  // ── Image picking ────────────────────────────────────────────────────────
  Future<void> _pickImages() async {
    if (_selectedImages.length >= 5) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Maximum 5 images allowed'), backgroundColor: AppColors.warning),
      );
      return;
    }
    await showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(width: 40, height: 4,
                decoration: BoxDecoration(color: AppColors.border, borderRadius: BorderRadius.circular(2))),
              const SizedBox(height: 16),
              const Text('Add Photos', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
              const SizedBox(height: 20),
              Row(children: [
                Expanded(child: _PickerOption(
                  icon: Icons.photo_library_outlined,
                  label: 'Gallery',
                  onTap: () async {
                    Navigator.pop(context);
                    final remaining = 5 - _selectedImages.length;
                    final images = await _picker.pickMultiImage(limit: remaining);
                    if (images.isNotEmpty && mounted) {
                      setState(() => _selectedImages.addAll(images));
                    }
                  },
                )),
                const SizedBox(width: 12),
                Expanded(child: _PickerOption(
                  icon: Icons.camera_alt_outlined,
                  label: 'Camera',
                  onTap: () async {
                    Navigator.pop(context);
                    final image = await _picker.pickImage(
                      source: ImageSource.camera,
                      imageQuality: 85,
                    );
                    if (image != null && mounted) {
                      setState(() => _selectedImages.add(image));
                    }
                  },
                )),
              ]),
            ],
          ),
        ),
      ),
    );
  }

  void _removeImage(int index) {
    setState(() => _selectedImages.removeAt(index));
  }

  // ── Submit ───────────────────────────────────────────────────────────────
  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() { _isLoading = true; _loadingMessage = 'Creating listing...'; });
    try {
      // 1. Create the item
      final createResponse = await ApiClient.instance.post('/items', data: {
        'title': _titleCtrl.text.trim(),
        'description': _descCtrl.text.trim(),
        'category': _category.name,
        'condition': _condition.name,
        'pickup_location': _locationCtrl.text.trim(),
        'max_borrow_days': int.parse(_maxDaysCtrl.text),
        'requires_deposit': _requiresDeposit,
        if (_requiresDeposit && _depositCtrl.text.isNotEmpty)
          'deposit_amount': double.parse(_depositCtrl.text),
        'tags': [],
      });

      final itemId = (createResponse.data as Map<String, dynamic>)['id'] as String;

      // 2. Upload images if any
      if (_selectedImages.isNotEmpty) {
        setState(() => _loadingMessage = 'Uploading ${_selectedImages.length} image(s)...');
        final formData = FormData();
        for (int i = 0; i < _selectedImages.length; i++) {
          final file = _selectedImages[i];
          formData.files.add(MapEntry(
            'files',
            await MultipartFile.fromFile(file.path, filename: 'image_$i.jpg'),
          ));
        }
        await ApiClient.instance.uploadFile('/items/$itemId/images', formData);
      }

      ref.invalidate(itemsProvider);
      ref.invalidate(myItemsProvider);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Item listed successfully!'), backgroundColor: AppColors.success),
      );
      if (context.canPop()) { context.pop(); } else { context.go('/items'); }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed: $e'), backgroundColor: AppColors.error),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // ── Build ────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('List an Item'),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: Stack(
        children: [
          Form(
            key: _formKey,
            child: ListView(
              padding: const EdgeInsets.all(20),
              children: [

                // ── Image Picker Section ──────────────────────────────────
                Text('Photos', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
                const SizedBox(height: 4),
                Text('Add up to 5 photos to attract more borrowers',
                  style: theme.textTheme.bodySmall?.copyWith(color: AppColors.textSecondary)),
                const SizedBox(height: 12),

                SizedBox(
                  height: 110,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    children: [
                      // Add photo button
                      if (_selectedImages.length < 5)
                        GestureDetector(
                          onTap: _pickImages,
                          child: Container(
                            width: 96, height: 96,
                            margin: const EdgeInsets.only(right: 10),
                            decoration: BoxDecoration(
                              color: AppColors.primary.withOpacity(0.08),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: AppColors.primary.withOpacity(0.4), width: 1.5,
                                style: BorderStyle.solid),
                            ),
                            child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                              Icon(Icons.add_photo_alternate_outlined, color: AppColors.primary, size: 32),
                              const SizedBox(height: 4),
                              Text('Add Photo', style: TextStyle(fontSize: 11,
                                color: AppColors.primary, fontWeight: FontWeight.w600)),
                            ]),
                          ),
                        ),

                      // Selected image thumbnails
                      ...List.generate(_selectedImages.length, (i) => Stack(
                        children: [
                          Container(
                            width: 96, height: 96,
                            margin: const EdgeInsets.only(right: 10),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: AppColors.border),
                            ),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(11),
                              child: Image.file(
                                File(_selectedImages[i].path),
                                fit: BoxFit.cover,
                                width: 96, height: 96,
                              ),
                            ),
                          ),
                          // Remove button
                          Positioned(
                            top: 4, right: 14,
                            child: GestureDetector(
                              onTap: () => _removeImage(i),
                              child: Container(
                                width: 22, height: 22,
                                decoration: BoxDecoration(
                                  color: AppColors.error,
                                  shape: BoxShape.circle,
                                  boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 4)],
                                ),
                                child: const Icon(Icons.close, color: Colors.white, size: 14),
                              ),
                            ),
                          ),
                          // First image badge
                          if (i == 0)
                            Positioned(
                              bottom: 8, left: 4,
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: Colors.black54,
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: const Text('Cover', style: TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.w700)),
                              ),
                            ),
                        ],
                      )),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                const Divider(),
                const SizedBox(height: 16),

                // ── Item Details ──────────────────────────────────────────
                TextFormField(
                  controller: _titleCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Item Title *',
                    prefixIcon: Icon(Icons.label_outline),
                    hintText: 'e.g. Scientific Calculator',
                  ),
                  validator: (v) => (v == null || v.trim().length < 3) ? 'Title must be at least 3 characters' : null,
                ),
                const SizedBox(height: 16),

                TextFormField(
                  controller: _descCtrl,
                  maxLines: 3,
                  decoration: const InputDecoration(
                    labelText: 'Description *',
                    prefixIcon: Icon(Icons.description_outlined),
                    hintText: 'Describe the item, its condition, usage instructions...',
                    alignLabelWithHint: true,
                  ),
                  validator: (v) => (v == null || v.trim().length < 10) ? 'Please add a brief description' : null,
                ),
                const SizedBox(height: 16),

                // Category
                Text('Category', style: theme.textTheme.labelLarge),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8, runSpacing: 8,
                  children: _categories.entries.map((e) {
                    final selected = _category == e.key;
                    return FilterChip(
                      avatar: Icon(e.value.$2, size: 16,
                        color: selected ? Colors.white : AppColors.textSecondary),
                      label: Text(e.value.$1),
                      selected: selected,
                      onSelected: (_) => setState(() => _category = e.key),
                      selectedColor: AppColors.primary,
                      labelStyle: TextStyle(
                        color: selected ? Colors.white : AppColors.textSecondary,
                        fontSize: 12,
                      ),
                      checkmarkColor: Colors.white,
                    );
                  }).toList(),
                ),
                const SizedBox(height: 16),

                // Condition
                Text('Condition', style: theme.textTheme.labelLarge),
                const SizedBox(height: 8),
                DropdownButtonFormField<ItemCondition>(
                  value: _condition,
                  decoration: const InputDecoration(prefixIcon: Icon(Icons.star_outline)),
                  items: _conditions.entries.map((e) =>
                    DropdownMenuItem(value: e.key, child: Text(e.value))
                  ).toList(),
                  onChanged: (v) => setState(() => _condition = v!),
                ),
                const SizedBox(height: 16),

                // Pickup location
                TextFormField(
                  controller: _locationCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Pickup Location *',
                    prefixIcon: Icon(Icons.location_on_outlined),
                    hintText: 'e.g. AB1 Block, Room 312',
                  ),
                  validator: (v) => (v == null || v.trim().isEmpty) ? 'Please enter a pickup location' : null,
                ),
                const SizedBox(height: 16),

                // Max borrow days
                TextFormField(
                  controller: _maxDaysCtrl,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Max Borrow Duration (days) *',
                    prefixIcon: Icon(Icons.calendar_today_outlined),
                  ),
                  validator: (v) {
                    final n = int.tryParse(v ?? '');
                    if (n == null || n < 1 || n > 90) return 'Enter 1–90 days';
                    return null;
                  },
                ),
                const SizedBox(height: 16),

                // Deposit
                SwitchListTile(
                  value: _requiresDeposit,
                  onChanged: (v) => setState(() => _requiresDeposit = v),
                  title: const Text('Requires Security Deposit'),
                  subtitle: const Text('Borrower pays a refundable deposit'),
                  activeColor: AppColors.primary,
                  contentPadding: EdgeInsets.zero,
                ),
                if (_requiresDeposit) ...[
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: _depositCtrl,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(
                      labelText: 'Deposit Amount (₹)',
                      prefixIcon: Icon(Icons.currency_rupee),
                    ),
                    validator: (v) {
                      if (!_requiresDeposit) return null;
                      final n = double.tryParse(v ?? '');
                      if (n == null || n <= 0) return 'Enter a valid deposit amount';
                      return null;
                    },
                  ),
                ],

                const SizedBox(height: 32),
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _submit,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                    child: _isLoading
                        ? const SizedBox(height: 20, width: 20,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : const Text('List Item',
                            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Colors.white)),
                  ),
                ),
                const SizedBox(height: 24),
              ],
            ),
          ),

          // Loading overlay
          if (_isLoading)
            Container(
              color: Colors.black45,
              child: Center(
                child: Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: Theme.of(context).cardColor,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                    const CircularProgressIndicator(),
                    const SizedBox(height: 16),
                    Text(_loadingMessage,
                      style: const TextStyle(fontWeight: FontWeight.w600)),
                  ]),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _PickerOption extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  const _PickerOption({required this.icon, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
      padding: const EdgeInsets.symmetric(vertical: 20),
      decoration: BoxDecoration(
        color: AppColors.surfaceVariant,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(children: [
        Icon(icon, size: 32, color: AppColors.primary),
        const SizedBox(height: 8),
        Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
      ]),
    ),
  );
}
