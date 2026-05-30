import 'package:json_annotation/json_annotation.dart';

part 'transaction_model.g.dart';

enum TransactionStatus { active, pickedUp, returned, overdue, disputed, cancelled }

@JsonSerializable()
class TransactionModel {
  final String id;
  @JsonKey(name: 'borrow_request_id')
  final String borrowRequestId;
  @JsonKey(name: 'item_id')
  final String itemId;
  @JsonKey(name: 'borrower_id')
  final String borrowerId;
  @JsonKey(name: 'lender_id')
  final String lenderId;
  @JsonKey(name: 'start_date')
  final DateTime startDate;
  @JsonKey(name: 'due_date')
  final DateTime dueDate;
  @JsonKey(name: 'pickup_time')
  final DateTime? pickupTime;
  @JsonKey(name: 'return_time')
  final DateTime? returnTime;
  final TransactionStatus status;
  @JsonKey(name: 'is_overdue')
  final bool isOverdue;
  @JsonKey(name: 'return_image_url')
  final String? returnImageUrl;
  @JsonKey(name: 'return_notes')
  final String? returnNotes;
  @JsonKey(name: 'created_at')
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

  factory TransactionModel.fromJson(Map<String, dynamic> json) => _$TransactionModelFromJson(json);
  Map<String, dynamic> toJson() => _$TransactionModelToJson(this);

  bool get isActive => status == TransactionStatus.active || status == TransactionStatus.pickedUp;

  int get daysRemaining => dueDate.difference(DateTime.now()).inDays;
}
