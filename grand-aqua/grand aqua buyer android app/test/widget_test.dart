import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:grand_aqua_buyer/main.dart';

void main() {
  testWidgets('Buyer App initial smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: GrandAquaBuyerApp(),
      ),
    );
    await tester.pumpAndSettle();
  });
}
