import 'dart:async';
import 'package:flutter/foundation.dart';
import '../models/download_task.dart';
import '../services/settings_service.dart';
import '../services/storage_service.dart';
import '../models/download_item.dart';
import '../core/constants.dart';
import '../core/queue_engine.dart';
import 'package:path_provider/path_provider.dart';

class QueueManager extends ChangeNotifier {
  final QueueEngine _queueEngine;
  final SettingsService _settingsService;
  final StorageService _storageService;

  final List<DownloadTask> _tasks = [];
  final List<String> _logs = [];
  StreamSubscription? _progressSub;

  QueueManager({
    required QueueEngine queueEngine,
    required SettingsService settingsService,
    required StorageService storageService,
  })  : _queueEngine = queueEngine,
        _settingsService = settingsService,
        _storageService = storageService {
    _progressSub = _queueEngine.events.listen(
      _handleProgress,
      onError: (Object error) {
        _appendLog('Stream error: $error');
      },
    );
  }

  List<DownloadTask> get tasks => List.unmodifiable(_tasks);
  List<String> get logs => List.unmodifiable(_logs);

  Future<String> enqueue(String url, {
    String quality = AppConstants.defaultQuality,
    bool skipExisting = true,
    bool embedArt = true,
    bool normalize = false,
  }) async {
    final outputDir = await _getOutputDirectory();
    final taskId = await _queueEngine.enqueue(
      url: url,
      outputDir: outputDir,
      quality: quality,
      skipExisting: skipExisting,
      embedArt: embedArt,
      normalize: normalize,
    );

    final task = DownloadTask(
      id: taskId,
      url: url,
      title: 'Queued',
      artist: '',
      progress: 0,
      status: DownloadTaskStatus.queued,
      message: 'Waiting',
    );

    _tasks.add(task);
    _appendLog('Queue: added task $taskId');
    notifyListeners();
    return taskId;
  }

  void pauseTask(String id) {
    _appendLog('Queue: pause task $id (unsupported)');
    _updateTask(id, status: DownloadTaskStatus.paused, message: 'Paused (unsupported)');
  }

  void resumeTask(String id) {
    _appendLog('Queue: resume task $id (unsupported)');
    _updateTask(id, status: DownloadTaskStatus.queued, message: 'Queued');
  }

  void cancelTask(String id) {
    _appendLog('Queue: cancel task $id (unsupported)');
    _updateTask(id, status: DownloadTaskStatus.cancelled, message: 'Cancelled');
  }

  void cancelAll() {
    _appendLog('Queue: cancel all (unsupported)');
    for (final task in _tasks) {
      _updateTask(task.id, status: DownloadTaskStatus.cancelled, message: 'Cancelled');
    }
  }

  void _handleProgress(Map<String, dynamic> event) async {
    var id = (event['id'] ?? '').toString();
    final status = (event['status'] ?? '').toString();
    final progress = (event['progress'] as num?)?.toInt() ?? 0;
    final message = (event['message'] ?? '').toString();
    final filePath = event['filePath'] as String?;
    _appendLog('Event: id=${id.isEmpty ? "-" : id} status=$status progress=$progress msg=$message');

    if (id.isEmpty) {
      final activeIndex = _tasks.indexWhere(
        (t) =>
            t.status == DownloadTaskStatus.queued ||
            t.status == DownloadTaskStatus.downloading ||
            t.status == DownloadTaskStatus.processing,
      );
      if (activeIndex != -1) {
        id = _tasks[activeIndex].id;
      }
    }

    DownloadTaskStatus nextStatus = DownloadTaskStatus.downloading;
    switch (status) {
      case 'completed':
        nextStatus = DownloadTaskStatus.completed;
        break;
      case 'error':
        nextStatus = DownloadTaskStatus.failed;
        break;
      case 'processing':
        nextStatus = DownloadTaskStatus.processing;
        break;
      case 'cancelled':
        nextStatus = DownloadTaskStatus.cancelled;
        break;
      case 'queued':
        nextStatus = DownloadTaskStatus.queued;
        break;
      default:
        nextStatus = DownloadTaskStatus.downloading;
    }

    _updateTask(
      id,
      progress: progress,
      status: nextStatus,
      message: message,
      filePath: filePath,
    );

    if (nextStatus == DownloadTaskStatus.completed) {
      await _saveToHistory(id, filePath ?? '');
    }
  }

  void _updateTask(
    String id, {
    int? progress,
    DownloadTaskStatus? status,
    String? message,
    String? filePath,
  }) {
    final index = _tasks.indexWhere((t) => t.id == id);
    if (index == -1) {
      _appendLog('Task not found for event id=$id');
      return;
    }
    final current = _tasks[index];
    _tasks[index] = current.copyWith(
      progress: progress ?? current.progress,
      status: status ?? current.status,
      message: message ?? current.message,
      filePath: filePath ?? current.filePath,
    );
    notifyListeners();
  }

  Future<void> _saveToHistory(String id, String filePath) async {
    try {
      final task = _tasks.firstWhere((t) => t.id == id);
      final item = DownloadItem(
        title: task.title,
        artist: task.artist,
        url: task.url,
        filePath: filePath,
        status: AppConstants.statusCompleted,
        type: AppConstants.modeSingle,
        createdAt: DateTime.now(),
      );
      await _storageService.insertDownload(item);
    } catch (_) {}
  }

  Future<String> _getOutputDirectory() async {
    final customDir = _settingsService.outputDirectory;
    if (customDir.isNotEmpty) return customDir;
    final dir = await getExternalStorageDirectory();
    return '${dir?.path ?? '/storage/emulated/0'}/SpotifyDownloader';
  }

  @override
  void dispose() {
    _progressSub?.cancel();
    super.dispose();
  }

  void _appendLog(String text) {
    final ts = DateTime.now().toIso8601String().substring(11, 19);
    _logs.add('[$ts] $text');
    if (_logs.length > 200) {
      _logs.removeRange(0, _logs.length - 200);
    }
    notifyListeners();
  }
}
