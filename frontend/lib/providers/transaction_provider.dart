/// Transaction Providers

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lendloop/models/transaction_model.dart';
import 'package:lendloop/services/api_client.dart';

final transactionsProvider = FutureProvider<List<TransactionModel>>((ref) async {
  final response = await ApiClient.instance.get('/transactions');
  return (response.data as List)
      .map((e) => TransactionModel.fromJson(e as Map<String, dynamic>))
      .toList();
});

final activeTransactionsProvider = FutureProvider<List<TransactionModel>>((ref) async {
  final all = await ref.watch(transactionsProvider.future);
  return all.where((t) => t.isActive).toList();
});

final completedTransactionsProvider = FutureProvider<List<TransactionModel>>((ref) async {
  final all = await ref.watch(transactionsProvider.future);
  return all.where((t) => t.isCompleted).toList();
});

final transactionDetailProvider = FutureProvider.family<TransactionModel, String>((ref, id) async {
  final response = await ApiClient.instance.get('/transactions/$id');
  return TransactionModel.fromJson(response.data as Map<String, dynamic>);
});

final transactionEvidenceProvider = FutureProvider.family<List<Map<String, dynamic>>, String>(
  (ref, transactionId) async {
    final response = await ApiClient.instance.get('/transactions/$transactionId/evidence');
    return (response.data as List).cast<Map<String, dynamic>>();
  },
);
