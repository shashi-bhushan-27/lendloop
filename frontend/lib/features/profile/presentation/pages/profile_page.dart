import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lendloop/core/constants/app_colors.dart';
import 'package:lendloop/providers/auth_provider.dart';
import 'package:lendloop/widgets/trust_score_badge.dart';

class ProfilePage extends ConsumerWidget {
  const ProfilePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final user = ref.watch(currentUserProvider).value;

    if (user == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 220,
            pinned: true,
            flexibleSpace: FlexibleSpaceBar(
              background: Container(
                decoration: const BoxDecoration(gradient: AppColors.accentGradient),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const SizedBox(height: 60),
                    CircleAvatar(
                      radius: 44,
                      backgroundColor: Colors.white,
                      child: user.avatarUrl != null
                          ? ClipOval(
                              child: Image.network(user.avatarUrl!, width: 80, height: 80, fit: BoxFit.cover))
                          : Text(user.fullName[0].toUpperCase(),
                              style: const TextStyle(fontSize: 32, fontWeight: FontWeight.w700, color: AppColors.accent)),
                    ),
                    const SizedBox(height: 12),
                    Text(user.fullName,
                        style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w700)),
                    Text(user.email,
                        style: const TextStyle(color: Colors.white70, fontSize: 13)),
                  ],
                ),
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  // Trust Score Card
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: [
                          TrustScoreBadge(score: user.trustScore, size: 80),
                          Column(
                            children: [
                              _StatItem(label: 'Items Lent', value: '${user.totalLends}'),
                              const SizedBox(height: 12),
                              _StatItem(label: 'Items Borrowed', value: '${user.totalBorrows}'),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  // Info Card
                  Card(
                    child: Column(
                      children: [
                        _InfoTile(icon: Icons.badge_outlined, label: 'Reg Number',
                            value: user.regNumber ?? 'Not set'),
                        const Divider(height: 1),
                        _InfoTile(icon: Icons.school_outlined, label: 'Department',
                            value: user.department ?? 'Not set'),
                        const Divider(height: 1),
                        _InfoTile(
                          icon: Icons.apartment_outlined,
                          label: 'Hostel / Block',
                          value: user.hostelBlock ?? 'Not set',
                        ),
                        const Divider(height: 1),
                        _InfoTile(
                          icon: Icons.location_on_outlined,
                          label: 'Preferred Pickup',
                          value: user.preferredPickupLocation ?? 'Not set',
                        ),
                        const Divider(height: 1),
                        _InfoTile(
                          icon: Icons.phone_outlined,
                          label: 'Phone',
                          value: user.phone ?? 'Not verified',
                          trailing: user.phoneVerified
                              ? const Icon(Icons.verified, color: AppColors.success, size: 18)
                              : null,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      icon: const Icon(Icons.logout_rounded),
                      label: const Text('Sign Out'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.error,
                        side: const BorderSide(color: AppColors.error),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      onPressed: () async {
                        await ref.read(authServiceProvider).signOut();
                        if (context.mounted) context.go('/login');
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _StatItem extends StatelessWidget {
  final String label;
  final String value;
  const _StatItem({required this.label, required this.value});
  @override
  Widget build(BuildContext context) => Column(children: [
    Text(value, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w700, color: AppColors.primary)),
    Text(label, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
  ]);
}

class _InfoTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Widget? trailing;
  const _InfoTile({required this.icon, required this.label, required this.value, this.trailing});
  @override
  Widget build(BuildContext context) => ListTile(
    leading: Icon(icon, color: AppColors.primary, size: 20),
    title: Text(label, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
    subtitle: Text(value, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500)),
    trailing: trailing,
  );
}
