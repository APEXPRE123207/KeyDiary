import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:keydiary/app/app.dart';

void main() {
  testWidgets('KeyDiaryApp boots to splash screen smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: KeyDiaryApp(),
      ),
    );
    await tester.pumpAndSettle();

    // Verify KeyDiary title and vault subtitle render
    expect(find.text('KeyDiary'), findsOneWidget);
    expect(find.text('Unlock Vault'), findsOneWidget);
  });
}
