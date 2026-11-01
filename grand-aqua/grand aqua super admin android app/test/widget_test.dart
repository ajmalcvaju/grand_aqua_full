import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:grand_aqua_super_admin/main.dart';

void main() {
  testWidgets('Grand Aqua Super Admin App smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(const ProviderScope(child: GrandAquaSuperAdminApp()));
    expect(find.text('GRAND AQUA'), findsOneWidget);
  });
}
