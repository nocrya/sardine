import 'package:flutter_test/flutter_test.dart';
import 'package:sardine/app.dart';

void main() {
  testWidgets('SardineApp 可挂载', (tester) async {
    await tester.pumpWidget(const SardineApp());
    expect(find.text('Sardine'), findsOneWidget);
    expect(find.textContaining('Current backend:'), findsOneWidget);
  });
}
