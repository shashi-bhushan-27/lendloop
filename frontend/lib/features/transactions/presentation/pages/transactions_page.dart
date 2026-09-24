import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:dio/dio.dart' show FormData, MultipartFile;
import 'package:lendloop/core/constants/app_colors.dart';
import 'package:lendloop/core/constants/category_meta.dart';
import 'package:lendloop/models/transaction_model.dart';
import 'package:lendloop/providers/auth_provider.dart';
import 'package:lendloop/providers/transaction_provider.dart';
import 'package:lendloop/services/api_client.dart';
import 'package:qr_flutter/qr_flutter.dart';

class TransactionsPage extends ConsumerStatefulWidget {
  const TransactionsPage({super.key});

  @override
  ConsumerState<TransactionsPage> createState() => _TransactionsPageState();
}

class _TransactionsPageState extends ConsumerState<TransactionsPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabs;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 3, vsync: this);
    // Refetch on every visit, not just after actions taken on this device —
    // the other party (lender/borrower) may have completed a pickup/return
    // on their own device since we last loaded this list, and a stale
    // "Awaiting Pickup" card offering actions that the backend will now
    // reject is worse than a brief reload.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) ref.invalidate(transactionsProvider);
    });
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  Future<void> _initiateReturn(String txId) async {
    try {
      await ApiClient.instance.post('/transactions/$txId/initiate-return', data: {});
      ref.invalidate(transactionsProvider);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Return initiated. Show the QR code to the lender.'), backgroundColor: AppColors.success),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(apiErrorMessage(e, fallback: 'Failed to initiate return.')), backgroundColor: AppColors.error),
        );
      }
    }
  }

  Future<void> _generateQR(String txId, String qrType) async {
    try {
      final response = await ApiClient.instance.post('/qr/generate', data: {
        'transaction_id': txId,
        'qr_type': qrType,
      });
      final token = response.data['token'] as String?;
      if (token != null && mounted) {
        _showQRDialog(token, qrType);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(apiErrorMessage(e, fallback: 'Failed to generate QR code.')), backgroundColor: AppColors.error),
        );
      }
    }
  }

  void _showQRDialog(String token, String qrType) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(qrType == 'pickup' ? 'Pickup QR Code' : 'Return QR Code'),
        content: SizedBox(
          width: 280,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              QrImageView(
                data: token,
                version: QrVersions.auto,
                size: 240,
                backgroundColor: AppColors.surface,
              ),
              const SizedBox(height: 12),
              Text(
                'Show this to the ${qrType == 'pickup' ? 'borrower' : 'lender'} to scan.',
                textAlign: TextAlign.center,
                style: const TextStyle(color: AppColors.textSecondary, fontSize: 13),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('Close')),
        ],
      ),
    );
  }

  Future<void> _uploadEvidence(String txId, String evidenceType) async {
    final picker = ImagePicker();
    final image = await picker.pickImage(source: ImageSource.camera, imageQuality: 85);
    if (image == null) return;

    try {
      final formData = FormData();
      formData.files.add(MapEntry(
        'file',
        await MultipartFile.fromFile(image.path, filename: 'evidence.jpg'),
      ));
      await ApiClient.instance.uploadFile(
        '/transactions/$txId/evidence?evidence_type=$evidenceType',
        formData,
      );
      ref.invalidate(transactionEvidenceProvider(txId));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Photo uploaded successfully'), backgroundColor: AppColors.success),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(apiErrorMessage(e, fallback: 'Upload failed.')), backgroundColor: AppColors.error),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentUserId = ref.watch(currentUserProvider).value?.id;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Transactions'),
        bottom: TabBar(
          controller: _tabs,
          tabs: const [
            Tab(text: 'Borrowing'),
            Tab(text: 'Lending'),
            Tab(text: 'History'),
          ],
        ),
      ),
      body: ref.watch(transactionsProvider).when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 56, color: AppColors.error),
              const SizedBox(height: 12),
              Text('Error: $e', style: const TextStyle(color: AppColors.error)),
              TextButton(
                onPressed: () => ref.invalidate(transactionsProvider),
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
        data: (txs) {
          final borrowing = txs.where((t) => t.borrowerId == currentUserId && t.isActive).toList();
          final lending = txs.where((t) => t.lenderId == currentUserId && t.isActive).toList();
          final history = txs.where((t) => !t.isActive).toList();

          return TabBarView(
            controller: _tabs,
            children: [
              _TransactionList(
                transactions: borrowing,
                isBorrowing: true,
                onInitiateReturn: _initiateReturn,
                onGenerateQR: _generateQR,
                onUploadEvidence: _uploadEvidence,
              ),
              _TransactionList(
                transactions: lending,
                isBorrowing: false,
                onInitiateReturn: _initiateReturn,
                onGenerateQR: _generateQR,
                onUploadEvidence: _uploadEvidence,
              ),
              _TransactionList(
                transactions: history,
                isBorrowing: false,
                isHistory: true,
                onInitiateReturn: _initiateReturn,
                onGenerateQR: _generateQR,
                onUploadEvidence: _uploadEvidence,
              ),
            ],
          );
        },
      ),
    );
  }
}

class _TransactionList extends StatelessWidget {
  final List<TransactionModel> transactions;
  final bool isBorrowing;
  final bool isHistory;
  final Future<void> Function(String) onInitiateReturn;
  final Future<void> Function(String, String) onGenerateQR;
  final Future<void> Function(String, String) onUploadEvidence;

  const _TransactionList({
    required this.transactions,
    this.isBorrowing = false,
    this.isHistory = false,
    required this.onInitiateReturn,
    required this.onGenerateQR,
    required this.onUploadEvidence,
  });

  @override
  Widget build(BuildContext context) {
    if (transactions.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              isHistory ? Icons.history_rounded : Icons.swap_horiz_rounded,
              size: 72,
              color: AppColors.textSecondary.withOpacity(0.3),
            ),
            const SizedBox(height: 16),
            Text(
              isHistory ? 'No history yet' : 'No active transactions',
              style: const TextStyle(fontSize: 16, color: AppColors.textSecondary),
            ),
          ],
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: transactions.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (_, i) => _TransactionCard(
        tx: transactions[i],
        isBorrowing: isBorrowing,
        isHistory: isHistory,
        onInitiateReturn: onInitiateReturn,
        onGenerateQR: onGenerateQR,
        onUploadEvidence: onUploadEvidence,
      ),
    );
  }
}

class _TransactionCard extends StatelessWidget {
  final TransactionModel tx;
  final bool isBorrowing;
  final bool isHistory;
  final Future<void> Function(String) onInitiateReturn;
  final Future<void> Function(String, String) onGenerateQR;
  final Future<void> Function(String, String) onUploadEvidence;

  const _TransactionCard({
    required this.tx,
    required this.isBorrowing,
    this.isHistory = false,
    required this.onInitiateReturn,
    required this.onGenerateQR,
    required this.onUploadEvidence,
  });

  Color get _statusColor {
    switch (tx.status) {
      case TransactionStatus.awaitingPickup:
        return AppColors.warning;
      case TransactionStatus.borrowed:
        return AppColors.info;
      case TransactionStatus.returnPending:
        return AppColors.accent;
      case TransactionStatus.completed:
        return AppColors.success;
      case TransactionStatus.overdue:
        return AppColors.error;
      case TransactionStatus.disputed:
        return AppColors.error;
      case TransactionStatus.cancelled:
        return AppColors.textSecondary;
    }
  }

  String get _statusLabel {
    switch (tx.status) {
      case TransactionStatus.awaitingPickup:
        return 'Awaiting Pickup';
      case TransactionStatus.borrowed:
        return 'Borrowed';
      case TransactionStatus.returnPending:
        return 'Return Pending';
      case TransactionStatus.completed:
        return 'Completed';
      case TransactionStatus.overdue:
        return 'Overdue';
      case TransactionStatus.disputed:
        return 'Disputed';
      case TransactionStatus.cancelled:
        return 'Cancelled';
    }
  }

  @override
  Widget build(BuildContext context) {
    final daysLeft = tx.daysRemaining;

    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _statusColor.withOpacity(0.3)),
        boxShadow: [
          BoxShadow(color: AppColors.shadow, blurRadius: 8, offset: const Offset(0, 2)),
        ],
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (tx.item != null) ...[
            GestureDetector(
              onTap: () => context.push('/items/${tx.item!.id}'),
              child: Row(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: SizedBox(
                      width: 56, height: 56,
                      child: tx.item!.imageUrls.isNotEmpty
                          ? CachedNetworkImage(
                              imageUrl: tx.item!.imageUrls.first,
                              fit: BoxFit.cover,
                              errorWidget: (_, __, ___) => _itemFallbackIcon(),
                              placeholder: (_, __) => _itemFallbackIcon(),
                            )
                          : _itemFallbackIcon(),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          tx.item!.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
                        ),
                        const SizedBox(height: 2),
                        Row(children: [
                          Icon(Icons.location_on_outlined, size: 12, color: AppColors.textTertiary),
                          const SizedBox(width: 2),
                          Expanded(
                            child: Text(
                              tx.item!.pickupLocation,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontSize: 12, color: AppColors.textTertiary),
                            ),
                          ),
                        ]),
                      ],
                    ),
                  ),
                  const Icon(Icons.chevron_right_rounded, color: AppColors.textTertiary),
                ],
              ),
            ),
            const Divider(height: 24),
          ],
          // Status row
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: _statusColor.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  _statusLabel,
                  style: TextStyle(color: _statusColor, fontSize: 12, fontWeight: FontWeight.w700),
                ),
              ),
              const Spacer(),
              if (!isHistory) ...[
                Icon(Icons.calendar_today_outlined, size: 14, color: AppColors.textSecondary),
                const SizedBox(width: 4),
                Text(
                  daysLeft < 0
                      ? '${daysLeft.abs()} days overdue'
                      : daysLeft == 0
                          ? 'Due today'
                          : '$daysLeft days left',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: daysLeft <= 1 ? AppColors.error : AppColors.textSecondary,
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 12),

          // Due date
          _infoRow(Icons.event_outlined, 'Due Date', _fmt(tx.dueDate)),
          const SizedBox(height: 6),
          if (tx.pickupTime != null)
            _infoRow(Icons.login_outlined, 'Picked up', _fmt(tx.pickupTime!)),
          if (tx.returnTime != null)
            _infoRow(Icons.logout_outlined, 'Returned', _fmt(tx.returnTime!)),

          const SizedBox(height: 12),

          // Actions
          if (!isHistory) ...[
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                // Borrower actions
                if (isBorrowing && tx.isBorrowed)
                  _ActionButton(
                    label: 'Initiate Return',
                    icon: Icons.assignment_return_outlined,
                    color: AppColors.accent,
                    onTap: () => onInitiateReturn(tx.id),
                  ),
                if (isBorrowing && tx.isReturnPending)
                  _ActionButton(
                    label: 'Show Return QR',
                    icon: Icons.qr_code,
                    color: AppColors.primary,
                    onTap: () => onGenerateQR(tx.id, 'return'),
                  ),

                // Borrower: scan the pickup QR the lender is showing
                if (isBorrowing && tx.isAwaitingPickup)
                  _ActionButton(
                    label: 'Scan Pickup QR',
                    icon: Icons.qr_code_scanner,
                    color: AppColors.success,
                    onTap: () => context.push('/qr/scan'),
                  ),

                // Lender actions
                if (!isBorrowing && tx.isAwaitingPickup)
                  _ActionButton(
                    label: 'Show Pickup QR',
                    icon: Icons.qr_code,
                    color: AppColors.primary,
                    onTap: () => onGenerateQR(tx.id, 'pickup'),
                  ),
                if (!isBorrowing && tx.isReturnPending)
                  _ActionButton(
                    label: 'Scan Return QR',
                    icon: Icons.qr_code_scanner,
                    color: AppColors.success,
                    onTap: () => context.push('/qr/scan'),
                  ),

                // Common actions
                if (tx.isAwaitingPickup || tx.isBorrowed || tx.isReturnPending)
                  _ActionButton(
                    label: 'Upload Photo',
                    icon: Icons.camera_alt_outlined,
                    color: AppColors.info,
                    onTap: () => _showEvidenceTypePicker(context, tx.id),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _itemFallbackIcon() => Container(
    color: AppColors.surfaceVariant,
    alignment: Alignment.center,
    child: Icon(
      tx.item != null ? (kCategoryMeta[tx.item!.category]?.icon ?? Icons.inventory_2_outlined) : Icons.inventory_2_outlined,
      color: AppColors.textTertiary, size: 24,
    ),
  );

  Widget _infoRow(IconData icon, String label, String value) {
    return Row(
      children: [
        Icon(icon, size: 14, color: AppColors.textSecondary),
        const SizedBox(width: 6),
        Text('$label: ', style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
        Text(value, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
      ],
    );
  }

  String _fmt(DateTime d) => '${d.day}/${d.month}/${d.year}';

  void _showEvidenceTypePicker(BuildContext context, String txId) {
    showModalBottomSheet(
      context: context,
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Upload Condition Photo', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
              const SizedBox(height: 16),
              ListTile(
                leading: const Icon(Icons.camera_alt_outlined, color: AppColors.primary),
                title: const Text('Pickup Condition'),
                onTap: () {
                  Navigator.pop(sheetContext);
                  onUploadEvidence(txId, 'pickup');
                },
              ),
              ListTile(
                leading: const Icon(Icons.camera_alt_outlined, color: AppColors.accent),
                title: const Text('Return Condition'),
                onTap: () {
                  Navigator.pop(sheetContext);
                  onUploadEvidence(txId, 'return');
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const _ActionButton({
    required this.label,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ActionChip(
      avatar: Icon(icon, size: 16, color: color),
      label: Text(label, style: TextStyle(fontSize: 12, color: color, fontWeight: FontWeight.w600)),
      backgroundColor: color.withOpacity(0.1),
      side: BorderSide(color: color.withOpacity(0.3)),
      onPressed: onTap,
    );
  }
}
