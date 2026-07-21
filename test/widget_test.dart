import 'package:flutter_test/flutter_test.dart';
import 'package:recovery_tool/main.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:flutter/widgets.dart';

void main() {
  testWidgets('Onboarding screen shows technical title', (tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: MyApp(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('RECOVERY SD TOOL'), findsOneWidget);
    expect(find.text('BỎ QUA'), findsOneWidget);
  });
}
