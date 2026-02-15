import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:spotdl_downloader/main.dart' as app;

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('Navigate between main menus', (tester) async {
    app.main();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.text('Spotify Downloader'), findsOneWidget);

    await tester.tap(find.text('Library'));
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('Library'), findsWidgets);

    await tester.tap(find.text('Settings'));
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('Settings'), findsWidgets);

    await tester.tap(find.text('About'));
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('POWERED BY'), findsOneWidget);
  });
}
