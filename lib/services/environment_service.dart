import 'dart:io';

import '../platform_bridge/command_executor.dart';

class EnvironmentService {
  final CommandExecutor executor;
  static const List<String> _preferredDistros = ['ubuntu', 'debian', 'archlinux'];

  EnvironmentService({required this.executor});

  Future<bool> isTermuxInstalled() async {
    if (!Platform.isAndroid) return false;
    final result = await executor.execute('__termux_check__');
    return result.isSuccess && result.stdout.trim() == 'true';
  }

  Future<bool> isTermuxTaskerInstalled() async {
    if (!Platform.isAndroid) return false;
    if (executor is! AndroidTermuxExecutor) return false;
    return (executor as AndroidTermuxExecutor).isTaskerInstalled();
  }

  Future<bool> isSpotdlAvailable() async {
    if (Platform.isAndroid) {
      final distro = await resolveDistro();
      final result = await executor.execute(
        'proot-distro login $distro -- command -v spotdl',
      );
      return result.isSuccess && result.stdout.trim().isNotEmpty;
    }
    final result = await executor.execute('command -v spotdl');
    return result.isSuccess && result.stdout.trim().isNotEmpty;
  }

  Future<CommandResult> installSpotdl() async {
    if (Platform.isAndroid) {
      final distro = await resolveDistro();
      return executor.execute('proot-distro login $distro -- pip install spotdl');
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

  Future<String> resolveDistro() async {
    final result = await executor.execute('proot-distro list');
    if (!result.isSuccess) return _preferredDistros.first;
    for (final distro in _preferredDistros) {
      if (result.stdout.contains(distro)) return distro;
    }
    return _preferredDistros.first;
  }

  Future<CommandResult> installSpotdlWithFfmpeg() async {
    if (!Platform.isAndroid) {
      return CommandResult(exitCode: 1, stdout: '', stderr: 'Not Android');
    }
    final distro = await resolveDistro();
    final cmd = [
      'proot-distro login $distro -- apt update',
      'proot-distro login $distro -- apt install -y python3-pip ffmpeg',
      'proot-distro login $distro -- python3 -m pip install spotdl',
    ].join(' && ');
    return executor.execute(cmd);
  }

  Future<CommandResult> oneClickSetup() async {
    if (!Platform.isAndroid) {
      return CommandResult(exitCode: 1, stdout: '', stderr: 'Not Android');
    }
    final termuxOk = await isTermuxInstalled();
    if (!termuxOk) {
      return CommandResult(exitCode: 1, stdout: '', stderr: 'Install Termux first');
    }
    final taskerOk = await isTermuxTaskerInstalled();
    if (!taskerOk) {
      return CommandResult(exitCode: 1, stdout: '', stderr: 'Install Termux:Tasker first');
    }
    final proot = await installProotDistro();
    if (!proot.isSuccess) return proot;
    final distro = await resolveDistro();
    final distroRes = await installDistro(distro);
    if (!distroRes.isSuccess) return distroRes;
    return installSpotdlWithFfmpeg();
  }
}
