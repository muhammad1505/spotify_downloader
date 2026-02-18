import 'dart:io';
import 'package:flutter/services.dart';

/// Platform-agnostic command execution interface.
abstract class CommandExecutor {
  Future<CommandResult> execute(String command, {String? workingDir});
}

class CommandResult {
  final int exitCode;
  final String stdout;
  final String stderr;

  const CommandResult({
    required this.exitCode,
    required this.stdout,
    required this.stderr,
  });

  bool get isSuccess => exitCode == 0;
}

/// Returns the appropriate executor for the current platform.
CommandExecutor resolveExecutor() {
  if (Platform.isAndroid) return AndroidTermuxExecutor();
  if (Platform.isWindows) return WindowsShellExecutor();
  if (Platform.isLinux) return LinuxShellExecutor();
  if (Platform.isMacOS) return MacShellExecutor();
  throw UnsupportedError('Unsupported platform');
}

class AndroidTermuxExecutor implements CommandExecutor {
  static const MethodChannel _channel = MethodChannel('com.spotify.downloader/termux');

  @override
  Future<CommandResult> execute(String command, {String? workingDir}) async {
    if (command == '__termux_check__') {
      final installed = await _channel.invokeMethod<bool>('isTermuxInstalled') ?? false;
      return CommandResult(exitCode: installed ? 0 : 1, stdout: installed.toString(), stderr: '');
    }

    final result = await _channel.invokeMethod<Map>('runCommand', {
      'command': command,
      'workDir': workingDir,
    });

    final map = result?.cast<String, dynamic>() ?? const {};
    return CommandResult(
      exitCode: (map['exitCode'] as num?)?.toInt() ?? 1,
      stdout: (map['stdout'] as String?) ?? '',
      stderr: (map['stderr'] as String?) ?? '',
    );
  }

  Future<TermuxCommandHandle> startCommand(String command, {String? workingDir}) async {
    final result = await _channel.invokeMethod<Map>('startCommand', {
      'command': command,
      'workDir': workingDir,
    });
    final map = result?.cast<String, dynamic>() ?? const {};
    return TermuxCommandHandle(
      id: (map['id'] as String?) ?? '',
      stdoutPath: (map['stdoutPath'] as String?) ?? '',
      stderrPath: (map['stderrPath'] as String?) ?? '',
      exitPath: (map['exitPath'] as String?) ?? '',
    );
  }

  Future<TermuxCommandStatus> checkCommand(String id) async {
    final result = await _channel.invokeMethod<Map>('checkCommand', {
      'id': id,
    });
    final map = result?.cast<String, dynamic>() ?? const {};
    return TermuxCommandStatus(
      done: map['done'] == true,
      exitCode: (map['exitCode'] as num?)?.toInt(),
      stdout: (map['stdout'] as String?) ?? '',
      stderr: (map['stderr'] as String?) ?? '',
    );
  }

  Future<bool> isTaskerInstalled() async {
    final installed = await _channel.invokeMethod<bool>('isTermuxTaskerInstalled') ?? false;
    return installed;
  }
}

class TermuxCommandHandle {
  final String id;
  final String stdoutPath;
  final String stderrPath;
  final String exitPath;

  const TermuxCommandHandle({
    required this.id,
    required this.stdoutPath,
    required this.stderrPath,
    required this.exitPath,
  });
}

class TermuxCommandStatus {
  final bool done;
  final int? exitCode;
  final String stdout;
  final String stderr;

  const TermuxCommandStatus({
    required this.done,
    required this.exitCode,
    required this.stdout,
    required this.stderr,
  });
}

class WindowsShellExecutor implements CommandExecutor {
  @override
  Future<CommandResult> execute(String command, {String? workingDir}) async {
    final result = await Process.run(
      'powershell',
      ['-NoProfile', '-Command', command],
      workingDirectory: workingDir,
    );
    return CommandResult(
      exitCode: result.exitCode,
      stdout: result.stdout?.toString() ?? '',
      stderr: result.stderr?.toString() ?? '',
    );
  }
}

class LinuxShellExecutor implements CommandExecutor {
  @override
  Future<CommandResult> execute(String command, {String? workingDir}) async {
    final result = await Process.run(
      'bash',
      ['-lc', command],
      workingDirectory: workingDir,
    );
    return CommandResult(
      exitCode: result.exitCode,
      stdout: result.stdout?.toString() ?? '',
      stderr: result.stderr?.toString() ?? '',
    );
  }
}

class MacShellExecutor implements CommandExecutor {
  @override
  Future<CommandResult> execute(String command, {String? workingDir}) async {
    final result = await Process.run(
      'zsh',
      ['-lc', command],
      workingDirectory: workingDir,
    );
    return CommandResult(
      exitCode: result.exitCode,
      stdout: result.stdout?.toString() ?? '',
      stderr: result.stderr?.toString() ?? '',
    );
  }
}
