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
    if (Platform.isAndroid) {
      final result = await executor.execute(
        'proot-distro login ubuntu -- command -v spotdl',
      );
      return result.isSuccess && result.stdout.trim().isNotEmpty;
    }
    final result = await executor.execute('command -v spotdl');
    return result.isSuccess && result.stdout.trim().isNotEmpty;
  }

  Future<CommandResult> installSpotdl() async {
    if (Platform.isAndroid) {
      return executor.execute('proot-distro login ubuntu -- pip install spotdl');
    }
    if (Platform.isWindows) {
      return executor.execute('python -m pip install spotdl');
    }
    return executor.execute('python3 -m pip install spotdl');
  }

  Future<bool> isProotDistroAvailable() async {
    final result = await executor.execute('command -v proot-distro');
    return result.isSuccess && result.stdout.trim().isNotEmpty;
  }

  Future<bool> hasDistro(String name) async {
    final result = await executor.execute('proot-distro list');
    return result.isSuccess && result.stdout.contains(name);
  }

  Future<CommandResult> installProotDistro() async {
    if (!Platform.isAndroid) {
      return CommandResult(exitCode: 1, stdout: '', stderr: 'Not Android');
    }
    return executor.execute('pkg install -y proot-distro');
  }

  Future<CommandResult> installDistro(String name) async {
    return executor.execute('proot-distro install $name');
  }
}
