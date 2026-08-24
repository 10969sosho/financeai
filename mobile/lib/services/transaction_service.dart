import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/transaction.dart';
import 'api_client.dart';
import 'auth_service.dart';

final transactionServiceProvider = Provider<TransactionService>((ref) {
  return TransactionService(ref.read(apiClientProvider));
});

class TransactionService {
  final ApiClient _apiClient;

  TransactionService(this._apiClient);

  Future<List<Transaction>> getTransactions({
    String? type,
    String? from,
    String? to,
    int? categoryId,
    int perPage = 20,
  }) async {
    final queryParams = <String, dynamic>{
      'per_page': perPage,
    };
    
    if (type != null) queryParams['type'] = type;
    if (from != null) queryParams['from'] = from;
    if (to != null) queryParams['to'] = to;
    if (categoryId != null) queryParams['category_id'] = categoryId;

    final response = await _apiClient.dio.get(
      '/transactions',
      queryParameters: queryParams,
    );

    final data = response.data['data'] as List<dynamic>;
    return data.map((e) => Transaction.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<Transaction> createTransaction({
    required String type,
    required int amount,
    required String description,
    required int categoryId,
    String? occurredAt,
  }) async {
    final response = await _apiClient.dio.post(
      '/transactions',
      data: {
        'type': type,
        'amount': amount,
        'description': description,
        'category_id': categoryId,
        if (occurredAt != null) 'occurred_at': occurredAt,
      },
    );

    return Transaction.fromJson(response.data['data'] as Map<String, dynamic>);
  }

  Future<Transaction> updateTransaction(int id, {
    String? type,
    int? amount,
    String? description,
    int? categoryId,
    String? occurredAt,
  }) async {
    final data = <String, dynamic>{};
    if (type != null) data['type'] = type;
    if (amount != null) data['amount'] = amount;
    if (description != null) data['description'] = description;
    if (categoryId != null) data['category_id'] = categoryId;
    if (occurredAt != null) data['occurred_at'] = occurredAt;

    final response = await _apiClient.dio.put('/transactions/$id', data: data);
    return Transaction.fromJson(response.data['data'] as Map<String, dynamic>);
  }

  Future<void> deleteTransaction(int id) async {
    await _apiClient.dio.delete('/transactions/$id');
  }
}
