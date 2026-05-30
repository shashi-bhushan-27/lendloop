import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lendloop/core/constants/app_colors.dart';
import 'package:lendloop/services/api_client.dart';

enum TransactionStatus { active, completed, overdue, disputed }

class TransactionModel {
  final String id;
  final String itemTitle;
  final String borrowerName;
  final String lenderName;
  final int borrowedDays;
  final DateTime startDate;
  final DateTime dueDate;
  final TransactionStatus status;
  final bool isBorrower;

  TransactionModel({
    required this.id, required this.itemTitle,
    required this.borrowerName, required this.lenderName,
    required this.borrowedDays, required this.startDate,
    required this.dueDate, required this.status, required this.isBorrower,
  });

  factory TransactionModel.fromJson(Map<String, dynamic> j, String currentUserId) {
    final borrowerId = j['borrower_id'] as String? ?? '';
    return TransactionModel(
      id: j['id'] as String,
      itemTitle: (j['item'] as Map<String, dynamic>?)?['title'] as String? ?? 'Unknown Item',
      borrowerName: (j['borrower'] as Map<String, dynamic>?)?['full_name'] as String? ?? 'Unknown',
      lenderName: (j['lender'] as Map<String, dynamic>?)?['full_name'] as String? ?? 'Unknown',
      borrowedDays: (j['borrowed_days'] as num?)?.toInt() ?? 0,
      startDate: DateTime.tryParse(j['start_date'] as String? ?? '') ?? DateTime.now(),
      dueDate: DateTime.tryParse(j['due_date'] as String? ?? '') ?? DateTime.now(),
      status: TransactionStatus.values.firstWhere(
        (e) => e.name == (j['status'] as String? ?? 'active'),
        orElse: () => TransactionStatus.active,
      ),
      isBorrower: borrowerId == currentUserId,
    );
  }
}

final transactionsProvider = FutureProvider<List<TransactionModel>>((ref) async {
  final response = await ApiClient.instance.get('/transactions');
  // TODO: pass real currentUserId; for now mark all as borrower for display
  return (response.data as List? ?? [])
      .map((e) => TransactionModel.fromJson(e as Map<String, dynamic>, ''))
      .toList();
});

class TransactionsPage extends ConsumerWidget {
  const TransactionsPage({super.key});

  static const _statusColors = {
    TransactionStatus.active: AppColors.info,
    TransactionStatus.completed: AppColors.success,
    TransactionStatus.overdue: AppColors.error,
    TransactionStatus.disputed: AppColors.warning,
  };

  static const _statusIcons = {
    TransactionStatus.active: Icons.swap_horiz_rounded,
    TransactionStatus.completed: Icons.check_circle_outline,
    TransactionStatus.overdue: Icons.warning_amber_rounded,
    TransactionStatus.disputed: Icons.gavel_rounded,
  };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final txAsync = ref.watch(transactionsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Transaction History'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => ref.invalidate(transactionsProvider),
          ),
        ],
      ),
      body: txAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            const Icon(Icons.error_outline, size: 56, color: AppColors.error),
            const SizedBox(height: 12),
            Text('Error loading transactions', style: const TextStyle(color: AppColors.error)),
            const SizedBox(height: 8),
            TextButton(onPressed: () => ref.invalidate(transactionsProvider), child: const Text('Retry')),
          ]),
        ),
        data: (txs) => txs.isEmpty
            ? Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                Icon(Icons.receipt_long_outlined, size: 72, color: AppColors.textSecondary.withOpacity(0.3)),
                const SizedBox(height: 16),
                const Text('No transactions yet', style: TextStyle(fontSize: 16, color: AppColors.textSecondary)),
                const SizedBox(height: 8),
                const Text('Borrow or lend items to see your history', style: TextStyle(color: AppColors.textSecondary, fontSize: 13)),
              ]))
            : ListView.separated(
                padding: const EdgeInsets.all(16),
                itemCount: txs.length,
                separatorBuilder: (_, __) => const SizedBox(height: 10),
                itemBuilder: (_, i) {
                  final tx = txs[i];
                  final statusColor = _statusColors[tx.status] ?? AppColors.textSecondary;
                  final statusIcon = _statusIcons[tx.status] ?? Icons.swap_horiz_rounded;
                  final daysLeft = tx.dueDate.difference(DateTime.now()).inDays;

                  return Container(
                    decoration: BoxDecoration(
                      color: Theme.of(context).cardColor,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: statusColor.withOpacity(0.25)),
                    ),
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: statusColor.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Icon(statusIcon, color: statusColor, size: 20),
                          ),
                          const SizedBox(width: 12),
                          Expanded(child: Text(tx.itemTitle,
                            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
                            maxLines: 1, overflow: TextOverflow.ellipsis)),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: statusColor.withOpacity(0.15),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(tx.status.name,
                              style: TextStyle(color: statusColor, fontSize: 11, fontWeight: FontWeight.w600)),
                          ),
                        ]),
                        const SizedBox(height: 12),
                        _row('${tx.isBorrower ? "Lender" : "Borrower"}',
                          tx.isBorrower ? tx.lenderName : tx.borrowerName,
                          tx.isBorrower ? Icons.person_outline : Icons.person_outlined),
                        const SizedBox(height: 6),
                        _row('Duration', '${tx.borrowedDays} days', Icons.calendar_today_outlined),
                        const SizedBox(height: 6),
                        _row('Due Date', _formatDate(tx.dueDate), Icons.event_outlined),
                        if (tx.status == TransactionStatus.active) ...[
                          const SizedBox(height: 8),
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              color: daysLeft <= 1 ? AppColors.error.withOpacity(0.1) : AppColors.info.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              daysLeft < 0
                                  ? '${daysLeft.abs()} days overdue!'
                                  : daysLeft == 0 ? 'Due today!'
                                  : '$daysLeft days remaining',
                              style: TextStyle(
                                color: daysLeft <= 1 ? AppColors.error : AppColors.info,
                                fontSize: 12, fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  );
                },
              ),
      ),
    );
  }

  Widget _row(String label, String value, IconData icon) => Row(children: [
    Icon(icon, size: 14, color: AppColors.textSecondary),
    const SizedBox(width: 6),
    Text('$label: ', style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
    Text(value, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
  ]);

  String _formatDate(DateTime d) => '${d.day}/${d.month}/${d.year}';
}
