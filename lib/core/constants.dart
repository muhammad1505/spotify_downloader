class AppConstants {
  // App Info
  static const String appName = 'Spotify Downloader';
  static const String appVersion = '1.0.0';
  static const int buildNumber = 1;
  static const String appDescription = 'Full Offline Spotify Downloader';
  static const String githubUrl = 'https://github.com/muhammad1505/spotify_downloader';

  // Method Channel
  static const String methodChannel = 'com.spotify.downloader/bridge';
  static const String eventChannel = 'com.spotify.downloader/progress';

  // Spotify URL Patterns
  static final RegExp spotifyTrackRegex = RegExp(
    r'https?://open\.spotify\.com/track/[a-zA-Z0-9]+',
  );
  static final RegExp spotifyPlaylistRegex = RegExp(
    r'https?://open\.spotify\.com/playlist/[a-zA-Z0-9]+',
  );
  static final RegExp spotifyAlbumRegex = RegExp(
    r'https?://open\.spotify\.com/album/[a-zA-Z0-9]+',
  );
  static final RegExp spotifyAnyRegex = RegExp(
    r'https?://open\.spotify\.com/(track|playlist|album)/[a-zA-Z0-9]+',
  );

  // Quality Options
  static const List<String> qualityOptions = ['128', '192', '320'];
  static const String defaultQuality = '320';

  // Download Modes
  static const String modeSingle = 'single';
  static const String modePlaylist = 'playlist';

  // Database
  static const String dbName = 'spotify_downloads.db';
  static const int dbVersion = 1;
  static const String tableDownloads = 'downloads';

  // Settings Keys
  static const String keyDefaultQuality = 'default_quality';
  static const String keyDefaultMode = 'default_mode';
  static const String keyAutoClearLogs = 'auto_clear_logs';
  static const String keyAutoOpenFolder = 'auto_open_folder';
  static const String keyMaxConcurrent = 'max_concurrent';
  static const String keyRetryOnFailure = 'retry_on_failure';
  static const String keyBackgroundDownload = 'background_download';
  static const String keyOutputDirectory = 'output_directory';
  static const String keyShowDebugLogs = 'show_debug_logs';
  static const String keySkipExisting = 'skip_existing';
  static const String keyEmbedArt = 'embed_art';
  static const String keyNormalizeAudio = 'normalize_audio';

  // Download Status
  static const String statusPending = 'pending';
  static const String statusDownloading = 'downloading';
  static const String statusConverting = 'converting';
  static const String statusCompleted = 'completed';
  static const String statusError = 'error';
  static const String statusCancelled = 'cancelled';
}
