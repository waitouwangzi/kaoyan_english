import 'package:flutter_test/flutter_test.dart';
import 'package:wordmap_build2/main.dart';

void main() {
  testWidgets('Counter increments smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(const WordMapApp());

    expect(find.text('词汇导图'), findsOneWidget);
  });
}
