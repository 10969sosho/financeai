class ApiConfig {
  static const String baseUrl = 'https://finance.solusisurabaya.com/api/v1';
  static const Duration timeout = Duration(seconds: 30);
  
  // Endpoints
  static const String login = '/auth/login';
  static const String register = '/auth/register';
  static const String logout = '/auth/logout';
  static const String me = '/me';
  
  static const String sessions = '/sessions';
  static String sessionMessages(int sessionId) => '/sessions/$sessionId/messages';
  
  static const String chat = '/chat';
  static const String transactions = '/transactions';
  static String transaction(int id) => '/transactions/$id';
  static const String categories = '/categories';
  static const String reportsSummary = '/reports/summary';
  static const String reportsBreakdown = '/reports/breakdown';
}
