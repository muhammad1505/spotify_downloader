import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:spotdl_downloader/main.dart' as app;

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('Navigate between main menus', (tester) async {
    app.main();
    await tester.pumpAndSettle(const Duration(seconds: 2));

    expect(find.text('Spotify Downloader'), findsOneWidget);

    await tester.tap(find.text('Library'));
    await tester.pumpAndSettle(const Duration(seconds: 1));
    expect(find.text('Library'), findsWidgets);

    await tester.tap(find.text('Settings'));
    await tester.pumpAndSettle(const Duration(seconds: 1));
    expect(find.text('Settings'), findsWidgets);

    await tester.tap(find.text('About'));
    await tester.pumpAndSettle(const Duration(seconds: 1));
    expect(find.text('POWERED BY'), findsOneWidget);
  });
}
