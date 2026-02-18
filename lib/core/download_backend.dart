import '../platform_bridge/command_executor.dart';

class DownloadRequest {
  final String id;
  final String url;
  final String outputDir;
  final String quality;
  final bool skipExisting;
  final bool embedArt;
  final bool normalize;

  const DownloadRequest({
    required this.id,
    required this.url,
    required this.outputDir,
    required this.quality,
    required this.skipExisting,
    required this.embedArt,
    required this.normalize,
  });
}

class DownloadResult {
  final bool success;
  final String message;

  const DownloadResult({required this.success, required this.message});
}

abstract class DownloadBackend {
  Future<DownloadResult> runDownload(DownloadRequest request);
}

class TermuxDownloadBackend implements DownloadBackend {
  final CommandExecutor executor;

  TermuxDownloadBackend({required this.executor});

  @override
  Future<DownloadResult> runDownload(DownloadRequest request) async {
    final outputArg = request.outputDir.replaceAll('"', '\\"');
    final cmd = 'spotdl "${request.url}" --output "$outputArg"';
    final res = await executor.execute(cmd);
    if (res.isSuccess) {
      return const DownloadResult(success: true, message: 'Download completed');
    }
    final message = res.stderr.trim().isNotEmpty ? res.stderr.trim() : res.stdout.trim();
    return DownloadResult(success: false, message: message.isEmpty ? 'Download failed' : message);
  }
}
