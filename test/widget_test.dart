import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:spotdl_downloader/main.dart';
import 'package:spotdl_downloader/services/download_service.dart';
import 'package:spotdl_downloader/services/settings_service.dart';
import 'package:spotdl_downloader/models/download_item.dart';
import 'package:spotdl_downloader/services/storage_service.dart';

class FakeStorageService extends StorageService {
  @override
  Future<List<DownloadItem>> getAllDownloads() async => [];

  @override
  Future<List<DownloadItem>> getDownloadsSorted(String sortBy) async => [];

  @override
  Future<List<DownloadItem>> getDownloadsByType(String type) async => [];

  @override
  Future<List<DownloadItem>> searchDownloads(String query) async => [];

  @override
  Future<int> insertDownload(DownloadItem item) async => 0;

  @override
  Future<int> deleteDownload(int id) async => 0;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('Bottom navigation switches between all screens', (tester) async {
    GoogleFonts.config.allowRuntimeFetching = false;
    SharedPreferences.setMockInitialValues({});
    final settingsService = SettingsService();
    await settingsService.init();

    final fakeStorage = FakeStorageService();

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<DownloadService>(
            create: (_) => DownloadService(
              storageService: fakeStorage,
              settingsService: settingsService,
            ),
          ),
        ],
        child: MaterialApp(
          home: MainShell(
            settingsService: settingsService,
            libraryStorageService: fakeStorage,
          ),
        ),
      ),
    );

    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.text('Spotify Downloader'), findsOneWidget);

    await tester.tap(find.text('Library'));
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('Library'), findsWidgets);

    await tester.tap(find.text('Analytics'));
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('Analytics'), findsWidgets);

    await tester.tap(find.text('Settings'));
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('Settings'), findsWidgets);

    await tester.tap(find.text('About'));
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('POWERED BY'), findsOneWidget);
  });
}
