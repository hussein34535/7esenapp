import 'package:flutter_test/flutter_test.dart';
import 'package:hesen/main.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

void main() {
  testWidgets('App loads smoke test', (WidgetTester tester) async {
    // Create a mock FlutterLocalNotificationsPlugin.  The actual
    // initialization is now handled within main.dart, and the
    // instance is passed down through the widget tree.
    final mockFlutterLocalNotificationsPlugin =
        FlutterLocalNotificationsPlugin();

    // Build our app and trigger a frame.
    await tester.pumpWidget(MyApp());

    // Verify that the app has loaded by checking for the title.
    expect(find.text('7eSen TV'), findsOneWidget);
  });
}
