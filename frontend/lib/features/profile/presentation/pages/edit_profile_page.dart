/// Edit Profile — lets a student fill in the fields the profile page shows
/// as "Not set" (reg number, department, hostel/block, pickup location,
/// phone) plus their display name. Saves via the existing `PUT /users/me`
/// endpoint (already accepts all these fields server-side — no backend or
/// schema changes needed here).

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lendloop/core/constants/app_colors.dart';
import 'package:lendloop/models/user_model.dart';
import 'package:lendloop/providers/auth_provider.dart';
import 'package:lendloop/services/api_client.dart';

class EditProfilePage extends ConsumerStatefulWidget {
  const EditProfilePage({super.key});

  @override
  ConsumerState<EditProfilePage> createState() => _EditProfilePageState();
}

class _EditProfilePageState extends ConsumerState<EditProfilePage> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameCtrl;
  late final TextEditingController _phoneCtrl;
  late final TextEditingController _departmentCtrl;
  late final TextEditingController _regNumberCtrl;
  late final TextEditingController _hostelCtrl;
  late final TextEditingController _pickupCtrl;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    final user = ref.read(currentUserProvider).value;
    _nameCtrl = TextEditingController(text: user?.fullName ?? '');
    _phoneCtrl = TextEditingController(text: user?.phone ?? '');
    _departmentCtrl = TextEditingController(text: user?.department ?? '');
    _regNumberCtrl = TextEditingController(text: user?.regNumber ?? '');
    _hostelCtrl = TextEditingController(text: user?.hostelBlock ?? '');
    _pickupCtrl = TextEditingController(text: user?.preferredPickupLocation ?? '');
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    _departmentCtrl.dispose();
    _regNumberCtrl.dispose();
    _hostelCtrl.dispose();
    _pickupCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSaving = true);
    try {
      final payload = <String, dynamic>{'full_name': _nameCtrl.text.trim()};
      // Only send optional fields when non-empty — an empty string is not
      // the same as "unset" to the backend (it would overwrite with ''),
      // and reg_number in particular is unique, so blanks must never be sent.
      void addIfNotEmpty(String key, String value) {
        if (value.trim().isNotEmpty) payload[key] = value.trim();
      }
      addIfNotEmpty('phone_number', _phoneCtrl.text);
      addIfNotEmpty('department', _departmentCtrl.text);
      addIfNotEmpty('reg_number', _regNumberCtrl.text);
      addIfNotEmpty('hostel_block', _hostelCtrl.text);
      addIfNotEmpty('preferred_pickup_location', _pickupCtrl.text);

      final response = await ApiClient.instance.put('/users/me', data: payload);
      final updated = UserModel.fromJson(response.data as Map<String, dynamic>);
      ref.read(currentUserProvider.notifier).setUser(updated);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Profile updated'), backgroundColor: AppColors.success),
      );
      context.pop();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(apiErrorMessage(e, fallback: 'Failed to save changes.')), backgroundColor: AppColors.error),
      );
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Edit Profile')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            TextFormField(
              controller: _nameCtrl,
              decoration: const InputDecoration(labelText: 'Full Name', prefixIcon: Icon(Icons.person_outline)),
              validator: (v) => (v == null || v.trim().length < 2) ? 'Enter your full name' : null,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _regNumberCtrl,
              decoration: const InputDecoration(labelText: 'Reg Number', prefixIcon: Icon(Icons.badge_outlined)),
              textCapitalization: TextCapitalization.characters,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _departmentCtrl,
              decoration: const InputDecoration(labelText: 'Department', prefixIcon: Icon(Icons.school_outlined)),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _hostelCtrl,
              decoration: const InputDecoration(
                labelText: 'Hostel / Block',
                hintText: 'e.g. Men\'s Hostel P Block',
                prefixIcon: Icon(Icons.apartment_outlined),
              ),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _pickupCtrl,
              decoration: const InputDecoration(
                labelText: 'Preferred Pickup Location',
                hintText: 'e.g. Room 312, near main gate',
                prefixIcon: Icon(Icons.location_on_outlined),
              ),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _phoneCtrl,
              decoration: const InputDecoration(labelText: 'Phone Number', prefixIcon: Icon(Icons.phone_outlined)),
              keyboardType: TextInputType.phone,
            ),
            const SizedBox(height: 28),
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton(
                onPressed: _isSaving ? null : _save,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                child: _isSaving
                    ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.textInverse))
                    : const Text('Save Changes', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.textInverse)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
