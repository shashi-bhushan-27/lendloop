enum TransactionStatus {
  awaitingPickup,
  borrowed,
  returnPending,
  completed,
  overdue,
  disputed,
  cancelled,
}

class TransactionModel {
  final String id;
  final String borrowRequestId;
  final String itemId;
  final String borrowerId;
  final String lenderId;
  final DateTime startDate;
  final DateTime dueDate;
  final DateTime? pickupTime;
  final DateTime? returnTime;
  final TransactionStatus status;
  final bool isOverdue;
  final String? returnImageUrl;
  final String? returnNotes;
  final DateTime createdAt;

  const TransactionModel({
    required this.id,
    required this.borrowRequestId,
    required this.itemId,
    required this.borrowerId,
    required this.lenderId,
    required this.startDate,
    required this.dueDate,
    this.pickupTime,
    this.returnTime,
    required this.status,
    required this.isOverdue,
    this.returnImageUrl,
    this.returnNotes,
    required this.createdAt,
  });

  factory TransactionModel.fromJson(Map<String, dynamic> json) {
    TransactionStatus parseStatus(String? s) {
      switch (s) {
        case 'awaiting_pickup': return TransactionStatus.awaitingPickup;
        case 'borrowed': return TransactionStatus.borrowed;
        case 'return_pending': return TransactionStatus.returnPending;
        case 'completed': return TransactionStatus.completed;
        case 'overdue': return TransactionStatus.overdue;
        case 'disputed': return TransactionStatus.disputed;
        case 'cancelled': return TransactionStatus.cancelled;
        default: return TransactionStatus.awaitingPickup;
      }
    }

    return TransactionModel(
      id: json['id'] as String,
      borrowRequestId: json['borrow_request_id'] as String? ?? '',
      itemId: json['item_id'] as String? ?? '',
      borrowerId: json['borrower_id'] as String? ?? '',
      lenderId: json['lender_id'] as String? ?? '',
      startDate: DateTime.tryParse(json['start_date'] as String? ?? '') ?? DateTime.now(),
      dueDate: DateTime.tryParse(json['due_date'] as String? ?? '') ?? DateTime.now(),
      pickupTime: json['pickup_time'] != null
          ? DateTime.tryParse(json['pickup_time'] as String)
          : null,
      returnTime: json['return_time'] != null
          ? DateTime.tryParse(json['return_time'] as String)
          : null,
      status: parseStatus(json['status'] as String?),
      isOverdue: json['is_overdue'] as bool? ?? false,
      returnImageUrl: json['return_image_url'] as String?,
      returnNotes: json['return_notes'] as String?,
      createdAt: DateTime.tryParse(json['created_at'] as String? ?? '') ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'borrow_request_id': borrowRequestId,
    'item_id': itemId,
    'borrower_id': borrowerId,
    'lender_id': lenderId,
    'start_date': startDate.toIso8601String(),
    'due_date': dueDate.toIso8601String(),
    'pickup_time': pickupTime?.toIso8601String(),
    'return_time': returnTime?.toIso8601String(),
    'status': _statusToString(),
    'is_overdue': isOverdue,
    'return_image_url': returnImageUrl,
    'return_notes': returnNotes,
    'created_at': createdAt.toIso8601String(),
  };

  String _statusToString() {
    switch (status) {
      case TransactionStatus.awaitingPickup: return 'awaiting_pickup';
      case TransactionStatus.borrowed: return 'borrowed';
      case TransactionStatus.returnPending: return 'return_pending';
      case TransactionStatus.completed: return 'completed';
      case TransactionStatus.overdue: return 'overdue';
      case TransactionStatus.disputed: return 'disputed';
      case TransactionStatus.cancelled: return 'cancelled';
    }
  }

  bool get isActive =>
      status == TransactionStatus.awaitingPickup ||
      status == TransactionStatus.borrowed ||
      status == TransactionStatus.returnPending;

  bool get isCompleted => status == TransactionStatus.completed;

  bool get isAwaitingPickup => status == TransactionStatus.awaitingPickup;
  bool get isBorrowed => status == TransactionStatus.borrowed;
  bool get isReturnPending => status == TransactionStatus.returnPending;

  int get daysRemaining => dueDate.difference(DateTime.now()).inDays;
}
