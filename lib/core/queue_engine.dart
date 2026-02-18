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
    final result = await backend.runDownload(request);
    _events.add({
      'id': request.id,
      'status': result.success ? 'completed' : 'error',
      'progress': result.success ? 100 : 0,
      'message': result.message,
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
}
