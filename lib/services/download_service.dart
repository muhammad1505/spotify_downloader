import 'package:flutter/foundation.dart';
import '../core/constants.dart';
import '../models/download_options.dart';
import 'settings_service.dart';

class DownloadService extends ChangeNotifier {
  final SettingsService _settingsService;

  DownloadOptions _options = const DownloadOptions();

  DownloadService({
    required SettingsService settingsService,
  }) : _settingsService = settingsService;

  // Getters
  DownloadOptions get options => _options;

  void updateOptions(DownloadOptions options) {
    _options = options;
    notifyListeners();
  }

  /// Validate a Spotify URL
  Future<Map<String, dynamic>> validateUrl(String url) async {
    // First do a quick regex check
    if (AppConstants.spotifyAnyRegex.hasMatch(url)) {
      String type = 'track';
      if (AppConstants.spotifyPlaylistRegex.hasMatch(url)) {
        type = 'playlist';
      } else if (AppConstants.spotifyAlbumRegex.hasMatch(url)) {
        type = 'album';
      }
      return {'valid': true, 'type': type};
    }
    return {'valid': false, 'type': null};
  }

  @override
  void dispose() {
    super.dispose();
  }
}
