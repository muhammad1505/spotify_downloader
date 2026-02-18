import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import 'core/theme.dart';
import 'core/queue_engine.dart';
import 'core/download_backend.dart';
import 'platform_bridge/command_executor.dart';
import 'services/environment_service.dart';
import 'services/download_service.dart';
import 'services/storage_service.dart';
import 'services/settings_service.dart';
import 'services/audio_service.dart';
import 'managers/queue_manager.dart';
import 'managers/analytics_manager.dart';
import 'screens/home_screen.dart';
import 'screens/library_screen.dart';
import 'screens/settings_screen.dart';
import 'screens/about_screen.dart';
import 'screens/analytics_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Force dark status bar
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.light,
    systemNavigationBarColor: AppTheme.spotifyDarkGrey,
    systemNavigationBarIconBrightness: Brightness.light,
  ));

  // Initialize services
  final settingsService = SettingsService();
  await settingsService.init();

  final storageService = StorageService();
  final audioService = AudioService();
  await audioService.init();

  final executor = resolveExecutor();
  final envService = EnvironmentService(executor: executor);
  final backend = TermuxDownloadBackend(executor: executor);
  final queueEngine = QueueEngine(backend: backend);

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(
          create: (_) => DownloadService(),
        ),
        ChangeNotifierProvider(
          create: (_) => QueueManager(
            queueEngine: queueEngine,
            settingsService: settingsService,
            storageService: storageService,
          ),
        ),
        ChangeNotifierProvider(
          create: (_) => AnalyticsManager(storageService: storageService),
        ),
        Provider<AudioService>.value(value: audioService),
        Provider<EnvironmentService>.value(value: envService),
      ],
      child: SpotifyDownloaderApp(settingsService: settingsService),
    ),
  );
}

class SpotifyDownloaderApp extends StatelessWidget {
  final SettingsService settingsService;

  const SpotifyDownloaderApp({super.key, required this.settingsService});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Spotify Downloader',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.darkTheme(),
      home: MainShell(settingsService: settingsService),
    );
  }
}

class MainShell extends StatefulWidget {
  final SettingsService settingsService;
  final StorageService? libraryStorageService;

  const MainShell({
    super.key,
    required this.settingsService,
    this.libraryStorageService,
  });

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _currentIndex = 0;

  late final List<Widget> _screens;

  @override
  void initState() {
    super.initState();
    _screens = [
      const HomeScreen(),
      LibraryScreen(storageService: widget.libraryStorageService),
      const AnalyticsScreen(),
      SettingsScreen(settingsService: widget.settingsService),
      const AboutScreen(),
    ];
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 300),
          switchInCurve: Curves.easeOut,
          switchOutCurve: Curves.easeIn,
          child: IndexedStack(
            key: ValueKey<int>(_currentIndex),
            index: _currentIndex,
            children: _screens,
          ),
        ),
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          border: Border(
            top: BorderSide(
              color: AppTheme.spotifyLightGrey.withAlpha(40),
              width: 0.5,
            ),
          ),
        ),
        child: BottomNavigationBar(
          currentIndex: _currentIndex,
          onTap: (index) {
            HapticFeedback.selectionClick();
            setState(() => _currentIndex = index);
          },
          items: const [
            BottomNavigationBarItem(
              icon: Icon(Icons.download_rounded),
              label: 'Download',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.library_music_rounded),
              label: 'Library',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.bar_chart_rounded),
              label: 'Analytics',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.settings_rounded),
              label: 'Settings',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.info_outline_rounded),
              label: 'About',
            ),
          ],
        ),
      ),
    );
  }
}
