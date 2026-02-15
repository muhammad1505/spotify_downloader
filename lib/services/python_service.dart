import 'dart:async';
import 'dart:convert';
import 'package:flutter/services.dart';
import '../core/constants.dart';

class PythonService {
  static const MethodChannel _methodChannel =
      MethodChannel(AppConstants.methodChannel);
  static const EventChannel _eventChannel =
      EventChannel(AppConstants.eventChannel);

  Stream<Map<String, dynamic>> get progressStream {
    return _eventChannel.receiveBroadcastStream().map((event) {
      try {
        return json.decode(event as String) as Map<String, dynamic>;
      } catch (e) {
        return {
          'id': 'unknown',
          'status': 'error',
          'progress': 0,
          'message': event.toString(),
        };
      }
    });
  }

  Future<String> addToQueue({
    required String url,
    required String outputDir,
    required String quality,
    required bool skipExisting,
    required bool embedArt,
    required bool normalize,
  }) async {
    final result = await _methodChannel.invokeMethod('addToQueue', {
      'url': url,
      'outputDir': outputDir,
      'quality': quality,
      'skipExisting': skipExisting,
      'embedArt': embedArt,
      'normalize': normalize,
    });
    return result as String;
  }

  Future<void> pauseTask(String id) async {
    await _methodChannel.invokeMethod('pauseTask', {'id': id});
  }

  Future<void> resumeTask(String id) async {
    await _methodChannel.invokeMethod('resumeTask', {'id': id});
  }

  Future<void> cancelTask(String id) async {
    await _methodChannel.invokeMethod('cancelTask', {'id': id});
  }

  Future<void> cancelAll() async {
    await _methodChannel.invokeMethod('cancelAll');
  }

  Future<List<dynamic>> getQueueStatus() async {
    final result = await _methodChannel.invokeMethod('getQueueStatus');
    return json.decode(result as String) as List<dynamic>;
  }
}
