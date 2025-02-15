import 'package:flutter_test/flutter_test.dart';
import 'package:hesen/main.dart';

void main() {
  testWidgets('App loads smoke test', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(MyApp());

    // Verify that the app has loaded by checking for the title.
    expect(find.text('7eSen TV'), findsOneWidget);
  });
}
