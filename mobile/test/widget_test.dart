import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:financeai_mobile/main.dart';

void main() {
  testWidgets('App renders login screen', (WidgetTester tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: FinanceAIApp(),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Login Screen'), findsOneWidget);
  });
}
