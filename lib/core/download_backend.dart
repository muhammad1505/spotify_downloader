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
  final String stdout;
  final String stderr;

  const DownloadResult({
    required this.success,
    required this.message,
    this.stdout = '',
    this.stderr = '',
  });
}

abstract class DownloadBackend {
  Future<DownloadResult> runDownload(DownloadRequest request);
}

class TermuxDownloadBackend implements DownloadBackend {
  final CommandExecutor executor;
  final Future<String> Function() resolveDistro;

  TermuxDownloadBackend({required this.executor, required this.resolveDistro});

  @override
  Future<DownloadResult> runDownload(DownloadRequest request) async {
    final distro = await resolveDistro();
    final outputArg = request.outputDir.replaceAll('"', '\\"');
    final cmd =
        'proot-distro login $distro -- spotdl "${request.url}" --output "$outputArg"';
    final res = await executor.execute(cmd);
    if (res.isSuccess) {
      return DownloadResult(
        success: true,
        message: 'Download completed',
        stdout: res.stdout,
        stderr: res.stderr,
      );
    }
    final message = res.stderr.trim().isNotEmpty ? res.stderr.trim() : res.stdout.trim();
    return DownloadResult(
      success: false,
      message: message.isEmpty ? 'Download failed' : message,
      stdout: res.stdout,
      stderr: res.stderr,
    );
  }

  Future<TermuxCommandHandle> startDownload(DownloadRequest request) async {
    final distro = await resolveDistro();
    final outputArg = request.outputDir.replaceAll('"', '\\"');
    final cmd =
        'proot-distro login $distro -- spotdl "${request.url}" --output "$outputArg"';
    final termux = executor as AndroidTermuxExecutor;
    return termux.startCommand(cmd);
  }

  Future<TermuxCommandStatus> checkDownload(String id) async {
    final termux = executor as AndroidTermuxExecutor;
    return termux.checkCommand(id);
  }
}
