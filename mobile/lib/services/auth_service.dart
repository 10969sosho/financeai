import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/user.dart';
import 'api_client.dart';

final apiClientProvider = Provider<ApiClient>((ref) {
  return ApiClient();
});

final authServiceProvider = Provider<AuthService>((ref) {
  return AuthService(ref.read(apiClientProvider));
});

final authStateProvider = StateNotifierProvider<AuthState, AuthStatus>((ref) {
  return AuthState(ref.read(authServiceProvider));
});

enum AuthStatus { unknown, authenticated, unauthenticated }

class AuthState extends StateNotifier<AuthStatus> {
  final AuthService _authService;

  AuthState(this._authService) : super(AuthStatus.unknown) {
    _checkAuth();
  }

  Future<void> _checkAuth() async {
    final hasToken = await _authService.hasToken();
    state = hasToken ? AuthStatus.authenticated : AuthStatus.unauthenticated;
  }

  Future<void> login(String email, String password) async {
    await _authService.login(email, password);
    state = AuthStatus.authenticated;
  }

  Future<void> register(String name, String email, String password, String passwordConfirmation) async {
    await _authService.register(name, email, password, passwordConfirmation);
    state = AuthStatus.authenticated;
  }

  Future<void> logout() async {
    await _authService.logout();
    state = AuthStatus.unauthenticated;
  }
}

class AuthService {
  final ApiClient _apiClient;

  AuthService(this._apiClient);

  Future<bool> hasToken() async {
    return _apiClient.hasToken();
  }

  Future<User> login(String email, String password) async {
    final response = await _apiClient.dio.post(
      '/auth/login',
      data: {
        'email': email,
        'password': password,
      },
    );

    final token = response.data['token'] as String;
    await _apiClient.setToken(token);

    return User.fromJson(response.data['user'] as Map<String, dynamic>);
  }

  Future<User> register(String name, String email, String password, String passwordConfirmation) async {
    final response = await _apiClient.dio.post(
      '/auth/register',
      data: {
        'name': name,
        'email': email,
        'password': password,
        'password_confirmation': passwordConfirmation,
      },
    );

    final token = response.data['token'] as String;
    await _apiClient.setToken(token);

    return User.fromJson(response.data['user'] as Map<String, dynamic>);
  }

  Future<void> logout() async {
    try {
      await _apiClient.dio.post('/auth/logout');
    } finally {
      await _apiClient.clearToken();
    }
  }

  Future<User> getMe() async {
    final response = await _apiClient.dio.get('/me');
    return User.fromJson(response.data['user'] as Map<String, dynamic>);
  }
}
