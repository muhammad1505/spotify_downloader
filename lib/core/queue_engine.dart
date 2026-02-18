import 'dart:async';
import 'dart:collection';
import 'dart:math';

import 'download_backend.dart';

class QueueEngine {
  final DownloadBackend backend;
  final StreamController<Map<String, dynamic>> _events =
      StreamController<Map<String, dynamic>>.broadcast();

  final Queue<DownloadRequest> _queue = Queue<DownloadRequest>();
  int _running = 0;
  int maxConcurrent = 1;

  QueueEngine({required this.backend});

  Stream<Map<String, dynamic>> get events => _events.stream;

  Future<String> enqueue({
    required String url,
    required String outputDir,
    required String quality,
    required bool skipExisting,
    required bool embedArt,
    required bool normalize,
  }) async {
    final id = _generateId();
    final request = DownloadRequest(
      id: id,
      url: url,
      outputDir: outputDir,
      quality: quality,
      skipExisting: skipExisting,
      embedArt: embedArt,
      normalize: normalize,
    );
    _queue.add(request);
    _events.add({
      'id': id,
      'status': 'queued',
      'progress': 0,
      'message': 'Queued',
    });
    _process();
    return id;
  }

  void _process() {
    while (_running < maxConcurrent && _queue.isNotEmpty) {
      final req = _queue.removeFirst();
      _running++;
      _run(req);
    }
  }

  Future<void> _run(DownloadRequest request) async {
    _events.add({
      'id': request.id,
      'status': 'downloading',
      'progress': 5,
      'message': 'Starting...'
    });
    final outcome = await _runWithStreaming(request);
    _events.add({
      'id': request.id,
      'status': outcome.success ? 'completed' : 'error',
      'progress': outcome.success ? 100 : 0,
      'message': outcome.message,
    });
    _running = (_running - 1).clamp(0, 9999);
    _process();
  }

  String _generateId() {
    final rand = Random().nextInt(999999);
    final ts = DateTime.now().microsecondsSinceEpoch;
    return '$ts-$rand';
  }

  void dispose() {
    _events.close();
  }

  Future<_RunOutcome> _runWithStreaming(DownloadRequest request) async {
    if (backend is! TermuxDownloadBackend) {
      final result = await backend.runDownload(request);
      final msg = _parseSpotdlOutput(result.stdout, result.message);
      return _RunOutcome(success: result.success, message: msg);
    }

    final termuxBackend = backend as TermuxDownloadBackend;
    final handle = await termuxBackend.startDownload(request);
    var lastStdout = '';
    var lastStderr = '';
    while (true) {
      final status = await termuxBackend.checkDownload(handle.id);
      if (status.stdout.isNotEmpty) lastStdout = status.stdout;
      if (status.stderr.isNotEmpty) lastStderr = status.stderr;
      final pct = _extractMaxPercent(lastStdout);
      if (pct > 0 && pct < 100) {
        _events.add({
          'id': request.id,
          'status': 'downloading',
          'progress': pct,
          'message': 'Downloading... $pct%',
        });
      }
      if (status.done) {
        final success = (status.exitCode ?? 1) == 0;
        final msg = success ? 'Download completed' : (lastStderr.trim().isNotEmpty ? lastStderr : lastStdout);
        final parsed = _parseSpotdlOutput(lastStdout, msg.isEmpty ? 'Download failed' : msg);
        return _RunOutcome(success: success, message: parsed);
      }
      await Future<void>.delayed(const Duration(seconds: 2));
    }
  }

  String _parseSpotdlOutput(String stdout, String fallback) {
    final percentMatches = RegExp(r'(\\d{1,3})%').allMatches(stdout);
    int maxPct = 0;
    for (final m in percentMatches) {
      final val = int.tryParse(m.group(1) ?? '') ?? 0;
      if (val > maxPct && val <= 100) maxPct = val;
    }
    if (maxPct > 0) {
      return '$fallback (max $maxPct%)';
    }
    return fallback;
  }

  int _extractMaxPercent(String text) {
    final percentMatches = RegExp(r'(\\d{1,3})%').allMatches(text);
    int maxPct = 0;
    for (final m in percentMatches) {
      final val = int.tryParse(m.group(1) ?? '') ?? 0;
      if (val > maxPct && val <= 100) maxPct = val;
    }
    return maxPct;
  }
}

class _RunOutcome {
  final bool success;
  final String message;

  const _RunOutcome({required this.success, required this.message});
}
