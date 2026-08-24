import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'config/theme.dart';
import 'services/auth_service.dart';
import 'screens/auth/login_screen.dart';
import 'screens/home_screen.dart';

void main() {
  runApp(
    const ProviderScope(
      child: FinanceAIApp(),
    ),
  );
}

class FinanceAIApp extends ConsumerWidget {
  const FinanceAIApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authStatus = ref.watch(authStateProvider);

    return MaterialApp(
      title: 'FinanceAI',
      theme: AppTheme.light,
      debugShowCheckedModeBanner: false,
      home: authStatus == AuthStatus.unknown
          ? const Scaffold(
              body: Center(
                child: CircularProgressIndicator(),
              ),
            )
          : authStatus == AuthStatus.authenticated
              ? const HomeScreen()
              : const LoginScreen(),
    );
  }
}
