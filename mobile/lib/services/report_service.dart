import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/report.dart';
import 'api_client.dart';
import 'auth_service.dart';

final reportServiceProvider = Provider<ReportService>((ref) {
  return ReportService(ref.read(apiClientProvider));
});

class ReportService {
  final ApiClient _apiClient;

  ReportService(this._apiClient);

  Future<ReportSummary> getSummary({String? period}) async {
    final queryParams = <String, dynamic>{};
    if (period != null) queryParams['period'] = period;

    final response = await _apiClient.dio.get(
      '/reports/summary',
      queryParameters: queryParams,
    );

    return ReportSummary.fromJson(response.data['data'] as Map<String, dynamic>);
  }

  Future<ReportBreakdown> getBreakdown({String? period}) async {
    final queryParams = <String, dynamic>{};
    if (period != null) queryParams['period'] = period;

    final response = await _apiClient.dio.get(
      '/reports/breakdown',
      queryParameters: queryParams,
    );

    return ReportBreakdown.fromJson(response.data['data'] as Map<String, dynamic>);
  }
}
