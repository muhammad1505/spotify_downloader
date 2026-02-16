import 'package:flutter/foundation.dart';
import '../services/storage_service.dart';

class AnalyticsSummary {
  final int totalDownloads;
  final int failedDownloads;
  final String topArtist;
  final String topTrack;

  const AnalyticsSummary({
    required this.totalDownloads,
    required this.failedDownloads,
    required this.topArtist,
    required this.topTrack,
  });
}

class AnalyticsManager extends ChangeNotifier {
  final StorageService _storageService;
  AnalyticsSummary _summary = const AnalyticsSummary(
    totalDownloads: 0,
    failedDownloads: 0,
    topArtist: '-/-',
    topTrack: '-/-',
  );

  AnalyticsSummary get summary => _summary;

  AnalyticsManager({required StorageService storageService})
      : _storageService = storageService;

  Future<void> refresh() async {
    final items = await _storageService.getAllDownloads();
    if (items.isEmpty) {
      _summary = const AnalyticsSummary(
        totalDownloads: 0,
        failedDownloads: 0,
        topArtist: '-/-',
        topTrack: '-/-',
      );
      notifyListeners();
      return;
    }

    final total = items.length;
    final failed = items.where((i) => i.status == 'error').length;

    final artistCount = <String, int>{};
    final trackCount = <String, int>{};
    for (final item in items) {
      artistCount[item.artist] = (artistCount[item.artist] ?? 0) + 1;
      trackCount[item.title] = (trackCount[item.title] ?? 0) + 1;
    }

    String topArtist = artistCount.entries.isEmpty
        ? '-/-'
        : (artistCount.entries.toList()..sort((a, b) => b.value - a.value))
            .first
            .key;
    String topTrack = trackCount.entries.isEmpty
        ? '-/-'
        : (trackCount.entries.toList()..sort((a, b) => b.value - a.value))
            .first
            .key;

    _summary = AnalyticsSummary(
      totalDownloads: total,
      failedDownloads: failed,
      topArtist: topArtist,
      topTrack: topTrack,
    );
    notifyListeners();
  }
}
