import 'package:flutter_test/flutter_test.dart';
import 'package:recovery_tool/main.dart';

void main() {
  testWidgets('Home screen shows image recovery entry point', (tester) async {
    await tester.pumpWidget(const MyApp());

    expect(find.text('KHÔI PHỤC TỪ ẢNH BACKUP (.IMG)'), findsOneWidget);
    expect(find.text('Recovery Tool'), findsOneWidget);
  });
}
