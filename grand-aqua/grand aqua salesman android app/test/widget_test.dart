import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:grand_aqua_salesman/main.dart';

void main() {
  testWidgets('Grand Aqua Salesman App smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(const ProviderScope(child: GrandAquaSalesmanApp()));
    expect(find.text('GRAND AQUA'), findsOneWidget);
  });
}
