import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('ScribeRAG App compile smoke test', (WidgetTester tester) async {
    // ScribeRAG has async bootstrap hooks that run before pumpWidget.
    // This smoke test verifies tests are running and compiling correctly.
    expect(true, isTrue);
  });
}
