import 'package:flutter_test/flutter_test.dart';
import 'package:rml_launcher/main.dart' as app;

void main() {
  testWidgets('starts and shows its name', (WidgetTester tester) async {
    app.main();
    await tester.pump();
    expect(find.text('RML Launcher'), findsOneWidget);
  });
}
