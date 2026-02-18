import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../managers/queue_manager.dart';
import '../services/environment_service.dart';
import '../core/theme.dart';
import '../core/constants.dart';
import '../services/settings_service.dart';

class SettingsScreen extends StatefulWidget {
  final SettingsService settingsService;

  const SettingsScreen({super.key, required this.settingsService});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  SettingsService get _s => widget.settingsService;
  bool _checkingEnv = false;
  String _envStatus = '';

  Future<void> _checkTermux() async {
    final env = context.read<EnvironmentService>();
    setState(() => _checkingEnv = true);
    final ok = await env.isTermuxInstalled();
    setState(() => _checkingEnv = false);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(ok ? 'Termux detected' : 'Termux not installed')),
    );
  }

  Future<void> _checkSpotdl() async {
    final env = context.read<EnvironmentService>();
    setState(() => _checkingEnv = true);
    final ok = await env.isSpotdlAvailable();
    setState(() => _checkingEnv = false);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(ok ? 'spotdl ready' : 'spotdl not found')),
    );
  }

  Future<void> _installSpotdl() async {
    final env = context.read<EnvironmentService>();
    setState(() => _checkingEnv = true);
    final res = await env.installSpotdl();
    setState(() => _checkingEnv = false);
    if (!mounted) return;
    final message = res.isSuccess ? 'spotdl installed' : 'Install failed: ${res.stderr}';
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  Future<void> _checkProot() async {
    final env = context.read<EnvironmentService>();
    setState(() => _checkingEnv = true);
    final ok = await env.isProotDistroAvailable();
    setState(() => _checkingEnv = false);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(ok ? 'proot-distro ready' : 'proot-distro not found')),
    );
  }

  Future<void> _installProot() async {
    final env = context.read<EnvironmentService>();
    setState(() => _checkingEnv = true);
    final res = await env.installProotDistro();
    setState(() => _checkingEnv = false);
    if (!mounted) return;
    final message = res.isSuccess ? 'proot-distro installed' : 'Install failed: ${res.stderr}';
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  Future<void> _installDistro() async {
    final env = context.read<EnvironmentService>();
    const distro = 'ubuntu';
    setState(() => _checkingEnv = true);
    final res = await env.installDistro(distro);
    setState(() => _checkingEnv = false);
    if (!mounted) return;
    final message = res.isSuccess ? 'Distro $distro installed' : 'Install failed: ${res.stderr}';
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  Future<void> _installSpotdlWithFfmpeg() async {
    final env = context.read<EnvironmentService>();
    setState(() => _checkingEnv = true);
    final res = await env.installSpotdlWithFfmpeg();
    setState(() => _checkingEnv = false);
    if (!mounted) return;
    final message = res.isSuccess ? 'spotdl + ffmpeg installed' : 'Install failed: ${res.stderr}';
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  Future<void> _oneClickSetup() async {
    final env = context.read<EnvironmentService>();
    final logger = context.read<QueueManager>();
    setState(() => _checkingEnv = true);
    logger.appendExternalLog('Setup: starting environment configuration');
    final res = await env.oneClickSetup(
      onLog: (msg) => logger.appendExternalLog('Setup: $msg'),
    );
    setState(() => _checkingEnv = false);
    if (!mounted) return;
    final message = res.isSuccess
        ? (res.stdout.isNotEmpty ? res.stdout : 'Setup complete')
        : 'Setup failed: ${res.stderr}';
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  Future<void> _refreshEnvStatus() async {
    final env = context.read<EnvironmentService>();
    setState(() => _checkingEnv = true);
    final termux = await env.isTermuxInstalled();
    final tasker = await env.isTermuxTaskerInstalled();
    final proot = await env.isProotDistroAvailable();
    final distro = await env.resolveDistro();
    final spotdl = await env.isSpotdlAvailable();
    setState(() => _checkingEnv = false);
    _envStatus = [
      'Termux: ${termux ? "OK" : "MISSING"}',
      'Tasker: ${tasker ? "OK" : "MISSING"}',
      'proot-distro: ${proot ? "OK" : "MISSING"}',
      'Distro: $distro',
      'spotdl: ${spotdl ? "OK" : "MISSING"}',
    ].join(' | ');
    if (!mounted) return;
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      physics: const BouncingScrollPhysics(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.only(left: 4, top: 8, bottom: 16),
            child: Row(
              children: const [
                Text('⚙️', style: TextStyle(fontSize: 24)),
                SizedBox(width: 10),
                Text(
                  'Settings',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),

          // General Section
          _buildSectionHeader('General'),
          _buildDropdownTile(
            'Default Quality',
            Icons.high_quality_rounded,
            '${_s.defaultQuality} kbps',
            AppConstants.qualityOptions,
            _s.defaultQuality,
            (val) {
              setState(() => _s.defaultQuality = val);
            },
          ),
          _buildDropdownTile(
            'Default Mode',
            Icons.album_rounded,
            _s.defaultMode == AppConstants.modeSingle ? 'Single Track' : 'Playlist',
            [AppConstants.modeSingle, AppConstants.modePlaylist],
            _s.defaultMode,
            (val) {
              setState(() => _s.defaultMode = val);
            },
          ),
          _buildSwitchTile(
            'Auto clear logs',
            Icons.cleaning_services_rounded,
            'Clear terminal logs after each download',
            _s.autoClearLogs,
            (val) => setState(() => _s.autoClearLogs = val),
          ),
          _buildSwitchTile(
            'Auto open folder',
            Icons.folder_open_rounded,
            'Open output folder after download completes',
            _s.autoOpenFolder,
            (val) => setState(() => _s.autoOpenFolder = val),
          ),
          const SizedBox(height: 16),

          // Download Settings
          _buildSectionHeader('Download'),
          _buildTile(
            'Max concurrent downloads',
            Icons.speed_rounded,
            '${_s.maxConcurrent}',
            onTap: () {
              _showNumberPicker('Max Concurrent Downloads', _s.maxConcurrent, 1, 3, (val) {
                setState(() => _s.maxConcurrent = val);
              });
            },
          ),
          _buildSwitchTile(
            'Retry on failure',
            Icons.refresh_rounded,
            'Automatically retry failed downloads',
            _s.retryOnFailure,
            (val) => setState(() => _s.retryOnFailure = val),
          ),
          _buildSwitchTile(
            'Background download',
            Icons.play_circle_outline_rounded,
            'Continue downloads when app is minimized',
            _s.backgroundDownload,
            (val) => setState(() => _s.backgroundDownload = val),
          ),
          const SizedBox(height: 16),

          // Storage
          _buildSectionHeader('Storage'),
          _buildTile(
            'Output directory',
            Icons.folder_rounded,
            _s.outputDirectory.isEmpty
                ? '/storage/emulated/0/SpotifyDownloader'
                : _s.outputDirectory,
            onTap: () {
              // TODO: Implement directory picker
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Directory picker coming soon!')),
              );
            },
          ),
          _buildTile(
            'Clear cache',
            Icons.delete_sweep_rounded,
            'Free up storage space',
            onTap: () {
              _showConfirmDialog(
                'Clear Cache',
                'This will remove all cached data. Downloads will not be affected.',
                () {
                  HapticFeedback.lightImpact();
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Cache cleared')),
                  );
                },
              );
            },
          ),
          const SizedBox(height: 16),

          // Environment
          _buildSectionHeader('Environment'),
          _buildTile(
            'Refresh status',
            Icons.refresh_rounded,
            'Check Termux / Tasker / proot / distro / spotdl',
            onTap: _refreshEnvStatus,
          ),
          if (_envStatus.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(left: 8, bottom: 12),
              child: Text(
                _envStatus,
                style: TextStyle(fontSize: 12, color: AppTheme.spotifySubtle),
              ),
            ),
          if (_checkingEnv)
            const Padding(
              padding: EdgeInsets.only(left: 8, bottom: 12),
              child: Text('Checking environment...', style: TextStyle(fontSize: 12)),
            ),
          _buildTile(
            'Check Termux',
            Icons.terminal_rounded,
            'Detect Termux installation',
            onTap: _checkTermux,
          ),
          _buildTile(
            'Check spotdl',
            Icons.search_rounded,
            'Verify spotdl command availability',
            onTap: _checkSpotdl,
          ),
          _buildTile(
            'Install spotdl',
            Icons.download_rounded,
            'Run pip install spotdl (proot)',
            onTap: _installSpotdl,
          ),
          _buildTile(
            'Check proot-distro',
            Icons.terminal,
            'Verify proot-distro availability',
            onTap: _checkProot,
          ),
          _buildTile(
            'Install proot-distro',
            Icons.download_rounded,
            'pkg install -y proot-distro',
            onTap: _installProot,
          ),
          _buildTile(
            'Install Ubuntu (proot)',
            Icons.cloud_download_rounded,
            'proot-distro install ubuntu',
            onTap: _installDistro,
          ),
          _buildTile(
            'Install spotdl + ffmpeg',
            Icons.download_for_offline_rounded,
            'Install python3-pip, ffmpeg, spotdl inside proot',
            onTap: _installSpotdlWithFfmpeg,
          ),
          _buildTile(
            'One-click setup (Android)',
            Icons.auto_fix_high_rounded,
            'Install proot, distro, spotdl, ffmpeg',
            onTap: _oneClickSetup,
          ),
          const SizedBox(height: 16),

          // Developer
          _buildSectionHeader('Developer'),
          _buildSwitchTile(
            'Show debug logs',
            Icons.bug_report_rounded,
            'Display verbose debug information',
            _s.showDebugLogs,
            (val) => setState(() => _s.showDebugLogs = val),
          ),
          _buildTile(
            'Reset app state',
            Icons.restore_rounded,
            'Reset all settings to default',
            isDestructive: true,
            onTap: () {
              _showConfirmDialog(
                'Reset App',
                'This will reset all settings to their default values. Are you sure?',
                () async {
                  final messenger = ScaffoldMessenger.of(context);
                  await _s.resetAll();
                  HapticFeedback.heavyImpact();
                  if (mounted) {
                    setState(() {});
                    messenger.showSnackBar(
                      const SnackBar(content: Text('Settings have been reset')),
                    );
                  }
                },
              );
            },
          ),
          _buildInfoTile('Version', AppConstants.appVersion),
          _buildInfoTile('Build number', '${AppConstants.buildNumber}'),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 8, top: 4),
      child: Text(
        title.toUpperCase(),
        style: const TextStyle(
          color: AppTheme.spotifyGreen,
          fontSize: 12,
          fontWeight: FontWeight.w700,
          letterSpacing: 1.5,
        ),
      ),
    );
  }

  Widget _buildSwitchTile(
    String title,
    IconData icon,
    String subtitle,
    bool value,
    ValueChanged<bool> onChanged,
  ) {
    return Card(
      child: SwitchListTile(
        title: Text(title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
        subtitle: Text(
          subtitle,
          style: TextStyle(fontSize: 12, color: AppTheme.spotifySubtle),
        ),
        secondary: Icon(icon, color: AppTheme.spotifyGreen, size: 22),
        value: value,
        onChanged: onChanged,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      ),
    );
  }

  Widget _buildTile(
    String title,
    IconData icon,
    String subtitle, {
    VoidCallback? onTap,
    bool isDestructive = false,
  }) {
    return Card(
      child: ListTile(
        leading: Icon(
          icon,
          color: isDestructive ? AppTheme.logError : AppTheme.spotifyGreen,
          size: 22,
        ),
        title: Text(
          title,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: isDestructive ? AppTheme.logError : null,
          ),
        ),
        subtitle: Text(
          subtitle,
          style: TextStyle(fontSize: 12, color: AppTheme.spotifySubtle),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        trailing: Icon(
          Icons.chevron_right_rounded,
          color: AppTheme.spotifySubtle.withAlpha(100),
        ),
        onTap: onTap,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      ),
    );
  }

  Widget _buildDropdownTile(
    String title,
    IconData icon,
    String current,
    List<String> options,
    String value,
    ValueChanged<String> onChanged,
  ) {
    return Card(
      child: ListTile(
        leading: Icon(icon, color: AppTheme.spotifyGreen, size: 22),
        title: Text(title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
        trailing: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: AppTheme.spotifyGreen.withAlpha(30),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            current,
            style: const TextStyle(
              color: AppTheme.spotifyGreen,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        onTap: () {
          showModalBottomSheet(
            context: context,
            backgroundColor: AppTheme.spotifyDarkGrey,
            shape: const RoundedRectangleBorder(
              borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
            ),
            builder: (ctx) {
              return Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: AppTheme.spotifyLightGrey,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),
                    ...options.map((opt) {
                      final isSelected = opt == value;
                      String label = opt;
                      if (opt == AppConstants.modeSingle) label = 'Single Track';
                      if (opt == AppConstants.modePlaylist) label = 'Playlist';
                      if (['128', '192', '320'].contains(opt)) label = '$opt kbps';

                      return ListTile(
                        title: Text(label),
                        trailing: isSelected
                            ? const Icon(Icons.check_rounded, color: AppTheme.spotifyGreen)
                            : null,
                        onTap: () {
                          onChanged(opt);
                          Navigator.pop(ctx);
                        },
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      );
                    }),
                    const SizedBox(height: 16),
                  ],
                ),
              );
            },
          );
        },
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      ),
    );
  }

  Widget _buildInfoTile(String title, String value) {
    return Card(
      child: ListTile(
        title: Text(title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
        trailing: Text(
          value,
          style: TextStyle(
            color: AppTheme.spotifySubtle,
            fontSize: 13,
          ),
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      ),
    );
  }

  void _showNumberPicker(
    String title,
    int current,
    int min,
    int max,
    ValueChanged<int> onChanged,
  ) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.spotifyDarkGrey,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppTheme.spotifyLightGrey,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 16),
              Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),
              ...List.generate(max - min + 1, (i) {
                final val = min + i;
                final isSelected = val == current;
                return ListTile(
                  title: Text('$val'),
                  trailing: isSelected
                      ? const Icon(Icons.check_rounded, color: AppTheme.spotifyGreen)
                      : null,
                  onTap: () {
                    onChanged(val);
                    Navigator.pop(ctx);
                  },
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                );
              }),
              const SizedBox(height: 16),
            ],
          ),
        );
      },
    );
  }

  void _showConfirmDialog(String title, String message, VoidCallback onConfirm) {
    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          backgroundColor: AppTheme.spotifyDarkGrey,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Text(title),
          content: Text(message, style: TextStyle(color: AppTheme.spotifySubtle)),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel', style: TextStyle(color: AppTheme.spotifySubtle)),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(ctx);
                onConfirm();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.logError,
              ),
              child: const Text('Confirm'),
            ),
          ],
        );
      },
    );
  }
}
