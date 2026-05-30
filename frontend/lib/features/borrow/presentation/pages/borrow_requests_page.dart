import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lendloop/core/constants/app_colors.dart';
import 'package:lendloop/services/api_client.dart';

// --- Models ---
enum BorrowRequestStatus { pending, approved, rejected, cancelled }

class BorrowRequestModel {
  final String id;
  final String itemId;
  final String borrowerId;
  final String lenderId;
  final String? message;
  final DateTime proposedStartDate;
  final DateTime proposedEndDate;
  final BorrowRequestStatus status;
  final String? rejectionReason;
  final DateTime createdAt;

  BorrowRequestModel({
    required this.id,
    required this.itemId,
    required this.borrowerId,
    required this.lenderId,
    this.message,
    required this.proposedStartDate,
    required this.proposedEndDate,
    required this.status,
    this.rejectionReason,
    required this.createdAt,
  });

  int get requestedDays => proposedEndDate.difference(proposedStartDate).inDays + 1;

  factory BorrowRequestModel.fromJson(Map<String, dynamic> j) => BorrowRequestModel(
    id: j['id'] as String,
    itemId: j['item_id'] as String,
    borrowerId: j['borrower_id'] as String,
    lenderId: j['lender_id'] as String,
    message: j['message'] as String?,
    proposedStartDate: DateTime.tryParse(j['proposed_start_date'] as String? ?? '') ?? DateTime.now(),
    proposedEndDate: DateTime.tryParse(j['proposed_end_date'] as String? ?? '') ?? DateTime.now(),
    status: BorrowRequestStatus.values.firstWhere(
      (e) => e.name == (j['status'] as String? ?? 'pending'),
      orElse: () => BorrowRequestStatus.pending,
    ),
    rejectionReason: j['rejection_reason'] as String?,
    createdAt: DateTime.tryParse(j['created_at'] as String? ?? '') ?? DateTime.now(),
  );
}

// --- Provider ---
final borrowRequestsProvider = FutureProvider<Map<String, List<BorrowRequestModel>>>((ref) async {
  final received = await ApiClient.instance.get('/borrow/received');
  final sent     = await ApiClient.instance.get('/borrow/sent');
  return {
    'incoming': (received.data as List? ?? [])
        .map((e) => BorrowRequestModel.fromJson(e as Map<String, dynamic>)).toList(),
    'outgoing': (sent.data as List? ?? [])
        .map((e) => BorrowRequestModel.fromJson(e as Map<String, dynamic>)).toList(),
  };
});

// --- Page ---
class BorrowRequestsPage extends ConsumerStatefulWidget {
  const BorrowRequestsPage({super.key});
  @override
  ConsumerState<BorrowRequestsPage> createState() => _BorrowRequestsPageState();
}

class _BorrowRequestsPageState extends ConsumerState<BorrowRequestsPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabs;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() { _tabs.dispose(); super.dispose(); }

  Future<void> _approve(String requestId) async {
    try {
      await ApiClient.instance.post('/borrow/$requestId/approve');
      ref.invalidate(borrowRequestsProvider);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Request approved!'), backgroundColor: AppColors.success),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to approve: $e'), backgroundColor: AppColors.error),
        );
      }
    }
  }

  Future<void> _reject(String requestId) async {
    // Ask for rejection reason
    final reasonCtrl = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Decline Request'),
        content: TextField(
          controller: reasonCtrl,
          decoration: const InputDecoration(
            labelText: 'Reason (required)',
            hintText: 'e.g. Item is not available right now',
          ),
          maxLines: 2,
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
            child: const Text('Decline', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    final reason = reasonCtrl.text.trim();
    if (reason.length < 5) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a reason (min 5 characters)'), backgroundColor: AppColors.warning),
      );
      return;
    }
    try {
      await ApiClient.instance.post('/borrow/$requestId/reject',
          data: {'rejection_reason': reason});
      ref.invalidate(borrowRequestsProvider);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Request declined'), backgroundColor: AppColors.success),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to decline: $e'), backgroundColor: AppColors.error),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final requestsAsync = ref.watch(borrowRequestsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Borrow Requests'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => ref.invalidate(borrowRequestsProvider),
          ),
        ],
        bottom: TabBar(
          controller: _tabs,
          tabs: const [
            Tab(text: 'Incoming', icon: Icon(Icons.inbox_outlined, size: 18)),
            Tab(text: 'My Requests', icon: Icon(Icons.send_outlined, size: 18)),
          ],
        ),
      ),
      body: requestsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            const Icon(Icons.error_outline, size: 56, color: AppColors.error),
            const SizedBox(height: 12),
            Text('Error: $e', textAlign: TextAlign.center,
                style: const TextStyle(color: AppColors.error)),
            const SizedBox(height: 12),
            TextButton(
              onPressed: () => ref.invalidate(borrowRequestsProvider),
              child: const Text('Retry'),
            ),
          ]),
        ),
        data: (data) => TabBarView(
          controller: _tabs,
          children: [
            _RequestList(
              requests: data['incoming'] ?? [],
              isIncoming: true,
              onApprove: _approve,
              onReject: _reject,
              emptyMessage: 'No incoming borrow requests yet',
              emptyIcon: Icons.inbox_outlined,
            ),
            _RequestList(
              requests: data['outgoing'] ?? [],
              isIncoming: false,
              onApprove: _approve,
              onReject: _reject,
              emptyMessage: 'You haven\'t requested to borrow anything yet',
              emptyIcon: Icons.send_outlined,
            ),
          ],
        ),
      ),
    );
  }
}

class _RequestList extends StatelessWidget {
  final List<BorrowRequestModel> requests;
  final bool isIncoming;
  final Future<void> Function(String) onApprove;
  final Future<void> Function(String) onReject;
  final String emptyMessage;
  final IconData emptyIcon;

  const _RequestList({
    required this.requests,
    required this.isIncoming,
    required this.onApprove,
    required this.onReject,
    required this.emptyMessage,
    required this.emptyIcon,
  });

  @override
  Widget build(BuildContext context) {
    if (requests.isEmpty) {
      return Center(child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(emptyIcon, size: 64, color: AppColors.textSecondary.withOpacity(0.35)),
          const SizedBox(height: 12),
          Text(emptyMessage, style: const TextStyle(color: AppColors.textSecondary),
              textAlign: TextAlign.center),
        ],
      ));
    }
    return RefreshIndicator(
      onRefresh: () async {},
      child: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: requests.length,
        separatorBuilder: (_, __) => const SizedBox(height: 10),
        itemBuilder: (_, i) => _RequestCard(
          request: requests[i],
          isIncoming: isIncoming,
          onApprove: onApprove,
          onReject: onReject,
        ),
      ),
    );
  }
}

class _RequestCard extends StatelessWidget {
  final BorrowRequestModel request;
  final bool isIncoming;
  final Future<void> Function(String) onApprove;
  final Future<void> Function(String) onReject;

  const _RequestCard({
    required this.request,
    required this.isIncoming,
    required this.onApprove,
    required this.onReject,
  });

  static const _statusColors = {
    BorrowRequestStatus.pending: AppColors.warning,
    BorrowRequestStatus.approved: AppColors.success,
    BorrowRequestStatus.rejected: AppColors.error,
    BorrowRequestStatus.cancelled: AppColors.textSecondary,
  };

  static const _statusIcons = {
    BorrowRequestStatus.pending: Icons.hourglass_empty_rounded,
    BorrowRequestStatus.approved: Icons.check_circle_outline,
    BorrowRequestStatus.rejected: Icons.cancel_outlined,
    BorrowRequestStatus.cancelled: Icons.block_outlined,
  };

  String _fmt(DateTime d) => '${d.day}/${d.month}/${d.year}';
  String _timeAgo(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 1) return 'just now';
    if (diff.inHours < 1) return '${diff.inMinutes}m ago';
    if (diff.inDays < 1) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }

  @override
  Widget build(BuildContext context) {
    final statusColor = _statusColors[request.status] ?? AppColors.textSecondary;
    final statusIcon  = _statusIcons[request.status] ?? Icons.help_outline;

    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: statusColor.withOpacity(0.3)),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

        // Header row
        Row(children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: statusColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(statusIcon, color: statusColor, size: 18),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Item ID: ...${request.itemId.substring(request.itemId.length - 8)}',
              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
              maxLines: 1, overflow: TextOverflow.ellipsis,
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: statusColor.withOpacity(0.12),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(request.status.name,
              style: TextStyle(color: statusColor, fontSize: 11, fontWeight: FontWeight.w600)),
          ),
        ]),

        const SizedBox(height: 10),

        // Dates
        Row(children: [
          const Icon(Icons.calendar_today_outlined, size: 13, color: AppColors.textSecondary),
          const SizedBox(width: 4),
          Text(
            '${_fmt(request.proposedStartDate)} → ${_fmt(request.proposedEndDate)}  (${request.requestedDays} days)',
            style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
          ),
        ]),

        // Message
        if (request.message != null && request.message!.isNotEmpty) ...[
          const SizedBox(height: 6),
          Text(
            '"${request.message}"',
            style: const TextStyle(color: AppColors.textSecondary, fontSize: 12, fontStyle: FontStyle.italic),
            maxLines: 2, overflow: TextOverflow.ellipsis,
          ),
        ],

        // Rejection reason
        if (request.rejectionReason != null) ...[
          const SizedBox(height: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: AppColors.error.withOpacity(0.08),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text('Reason: ${request.rejectionReason}',
              style: const TextStyle(color: AppColors.error, fontSize: 11)),
          ),
        ],

        const SizedBox(height: 6),
        Text(_timeAgo(request.createdAt),
          style: const TextStyle(color: AppColors.textSecondary, fontSize: 11)),

        // Approve / Decline buttons (incoming pending only)
        if (isIncoming && request.status == BorrowRequestStatus.pending) ...[
          const SizedBox(height: 12),
          Row(children: [
            Expanded(child: OutlinedButton.icon(
              onPressed: () => onReject(request.id),
              icon: const Icon(Icons.close, size: 16),
              label: const Text('Decline'),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.error,
                side: const BorderSide(color: AppColors.error),
              ),
            )),
            const SizedBox(width: 10),
            Expanded(child: ElevatedButton.icon(
              onPressed: () => onApprove(request.id),
              icon: const Icon(Icons.check, size: 16, color: Colors.white),
              label: const Text('Approve', style: TextStyle(color: Colors.white)),
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.success),
            )),
          ]),
        ],
      ]),
    );
  }
}
