import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/category.dart';
import 'api_client.dart';
import 'auth_service.dart';

final categoryServiceProvider = Provider<CategoryService>((ref) {
  return CategoryService(ref.read(apiClientProvider));
});

class CategoryService {
  final ApiClient _apiClient;

  CategoryService(this._apiClient);

  Future<List<Category>> getCategories() async {
    final response = await _apiClient.dio.get('/categories');
    final data = response.data['data'] as List<dynamic>;
    return data.map((e) => Category.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<Category> createCategory({
    required String name,
    required String type,
  }) async {
    final response = await _apiClient.dio.post(
      '/categories',
      data: {
        'name': name,
        'type': type,
      },
    );

    return Category.fromJson(response.data['data'] as Map<String, dynamic>);
  }
}
