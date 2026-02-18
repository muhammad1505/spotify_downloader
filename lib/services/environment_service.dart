import 'dart:io';

import '../platform_bridge/command_executor.dart';

class EnvironmentService {
  final CommandExecutor executor;

  EnvironmentService({required this.executor});

  Future<bool> isTermuxInstalled() async {
    if (!Platform.isAndroid) return false;
    final result = await executor.execute('__termux_check__');
    return result.isSuccess && result.stdout.trim() == 'true';
  }

  Future<bool> isSpotdlAvailable() async {
    final result = await executor.execute('command -v spotdl');
    return result.isSuccess && result.stdout.trim().isNotEmpty;
  }

  Future<CommandResult> installSpotdl() async {
    if (Platform.isAndroid) {
      return executor.execute('pip install spotdl');
    }
    if (Platform.isWindows) {
      return executor.execute('python -m pip install spotdl');
    }
    return executor.execute('python3 -m pip install spotdl');
  }
}
