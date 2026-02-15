import 'package:flutter/foundation.dart';

enum DownloadTaskStatus {
  queued,
  downloading,
  processing,
  completed,
  failed,
  paused,
  cancelled,
}

@immutable
class DownloadTask {
  final String id;
  final String url;
  final String title;
  final String artist;
  final int progress;
  final DownloadTaskStatus status;
  final String message;
  final String? filePath;

  const DownloadTask({
    required this.id,
    required this.url,
    required this.title,
    required this.artist,
    required this.progress,
    required this.status,
    required this.message,
    this.filePath,
  });

  DownloadTask copyWith({
    String? title,
    String? artist,
    int? progress,
    DownloadTaskStatus? status,
    String? message,
    String? filePath,
  }) {
    return DownloadTask(
      id: id,
      url: url,
      title: title ?? this.title,
      artist: artist ?? this.artist,
      progress: progress ?? this.progress,
      status: status ?? this.status,
      message: message ?? this.message,
      filePath: filePath ?? this.filePath,
    );
  }
}
