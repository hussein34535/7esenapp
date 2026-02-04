import 'package:flutter_test/flutter_test.dart';
import 'package:hesen/main.dart';

void main() {
  testWidgets('App loads smoke test', (WidgetTester tester) async {
    // Create a mock FlutterLocalNotificationsPlugin.  The actual
    // initialization is now handled within main.dart, and the
    // instance is passed down through the widget tree.

    // Build our app and trigger a frame.
    await tester.pumpWidget(MyApp(initFuture: Future.value()));

    // Verify that the app has loaded by checking for the title.
    expect(find.text('7eSen TV'), findsOneWidget);
  });
}
