import 'package:flutter_test/flutter_test.dart';
import 'package:recovery_tool/main.dart';

void main() {
  testWidgets('Onboarding screen shows technical title', (tester) async {
    await tester.pumpWidget(const MyApp());

    expect(find.text('RECOVERY SD TOOL'), findsOneWidget);
    expect(find.text('SKIP'), findsOneWidget);
  });
}
