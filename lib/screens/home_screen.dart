import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../core/theme.dart';
import '../core/constants.dart';
import '../services/download_service.dart';
import '../managers/queue_manager.dart';
import '../widgets/url_input.dart';
import '../widgets/download_options_card.dart';
import '../widgets/progress_card.dart';
import '../widgets/terminal_log.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with TickerProviderStateMixin {
  final TextEditingController _urlController = TextEditingController();
  bool _isUrlValid = false;
  bool _isChecking = false;
  String? _urlType;
  String _selectedMode = AppConstants.modeSingle;

  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );
    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.05).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
    _pulseController.repeat(reverse: true);
  }

  @override
  void dispose() {
    _urlController.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  Future<void> _onUrlChanged(String url) async {
    if (url.isEmpty) {
      setState(() {
        _isUrlValid = false;
        _isChecking = false;
        _urlType = null;
      });
      return;
    }

    setState(() => _isChecking = true);

    final service = context.read<DownloadService>();
    final result = await service.validateUrl(url);

    if (mounted) {
      setState(() {
        _isUrlValid = result['valid'] == true;
        _urlType = result['type'] as String?;
        _isChecking = false;

        // Auto-detect mode
        if (_urlType == 'playlist' || _urlType == 'album') {
          _selectedMode = AppConstants.modePlaylist;
        } else {
          _selectedMode = AppConstants.modeSingle;
        }
      });
    }
  }

  void _startDownload() {
    if (!_isUrlValid) return;

    HapticFeedback.mediumImpact();
    context.read<DownloadService>().clearLogs();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer2<DownloadService, QueueManager>(
      builder: (context, downloadService, queueManager, _) {
        return SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          physics: const BouncingScrollPhysics(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              const SizedBox(height: 8),
              Row(
                children: [
                  const Text(
                    '🎧',
                    style: TextStyle(fontSize: 28),
                  ),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Spotify Downloader',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.spotifyWhite,
                        ),
                      ),
                      Text(
                        'Full Offline Mode',
                        style: TextStyle(
                          fontSize: 12,
                          color: AppTheme.spotifyGreen.withAlpha(200),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // URL Input
              UrlInput(
                controller: _urlController,
                isValid: _isUrlValid,
                isChecking: _isChecking,
                urlType: _urlType,
                onChanged: _onUrlChanged,
              ),
              const SizedBox(height: 16),

              // Mode Selection
              Row(
                children: [
                  Expanded(
                    child: _buildModeButton(
                      '🎵  Single Track',
                      AppConstants.modeSingle,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _buildModeButton(
                      '📀  Playlist',
                      AppConstants.modePlaylist,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Download Options
              DownloadOptionsCard(
                options: downloadService.options,
                onChanged: (options) {
                  downloadService.updateOptions(options);
                },
              ),
              const SizedBox(height: 20),

              // Download Button
              if (!downloadService.isDownloading)
                SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: AnimatedBuilder(
                    animation: _pulseAnimation,
                    builder: (context, child) {
                      return Transform.scale(
                        scale: _isUrlValid ? _pulseAnimation.value : 1.0,
                        child: child,
                      );
                    },
                    child: ElevatedButton(
                      onPressed: _isUrlValid
                          ? () async {
                              _startDownload();
                              await queueManager.enqueue(
                                _urlController.text.trim(),
                                quality: downloadService.options.quality,
                                skipExisting: downloadService.options.skipExisting,
                                embedArt: downloadService.options.embedArt,
                                normalize: downloadService.options.normalizeAudio,
                              );
                            }
                          : null,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _isUrlValid
                            ? AppTheme.spotifyGreen
                            : AppTheme.spotifyGrey,
                        foregroundColor: Colors.white,
                        disabledBackgroundColor: AppTheme.spotifyGrey,
                        disabledForegroundColor: AppTheme.spotifySubtle,
                      ),
                      child: const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.download_rounded, size: 22),
                          SizedBox(width: 8),
                          Text(
                            'DOWNLOAD NOW',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 1.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

              if (queueManager.tasks.isNotEmpty) ...[
                const SizedBox(height: 16),
                const Text(
                  'Queue',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                AnimatedList(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  initialItemCount: queueManager.tasks.length,
                  itemBuilder: (context, index, animation) {
                    final task = queueManager.tasks[index];
                    return SizeTransition(
                      sizeFactor: animation,
                      child: Card(
                        child: ListTile(
                          title: Text(task.title),
                          subtitle: Text('${task.message} (${task.progress}%)'),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                icon: const Icon(Icons.pause_rounded),
                                onPressed: () => queueManager.pauseTask(task.id),
                              ),
                              IconButton(
                                icon: const Icon(Icons.close_rounded),
                                onPressed: () => queueManager.cancelTask(task.id),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ],

              // Progress Section
              if (downloadService.isDownloading ||
                  downloadService.currentStatus == AppConstants.statusCompleted ||
                  downloadService.currentStatus == AppConstants.statusError) ...[
                const SizedBox(height: 16),
                ProgressCard(
                  progress: downloadService.progress,
                  statusMessage: downloadService.statusMessage,
                  status: downloadService.currentStatus,
                  onCancel: downloadService.isDownloading
                      ? () => downloadService.cancelDownload()
                      : null,
                ),
              ],

              // Terminal Log
              if (downloadService.logs.isNotEmpty) ...[
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Console Output',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                        color: AppTheme.spotifySubtle,
                      ),
                    ),
                    TextButton.icon(
                      onPressed: () => downloadService.clearLogs(),
                      icon: const Icon(Icons.clear_all, size: 16),
                      label: const Text('Clear'),
                      style: TextButton.styleFrom(
                        foregroundColor: AppTheme.spotifySubtle,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                TerminalLog(logs: downloadService.logs),
              ],
              const SizedBox(height: 32),
            ],
          ),
        );
      },
    );
  }

  Widget _buildModeButton(String label, String mode) {
    final isSelected = _selectedMode == mode;
    return GestureDetector(
      onTap: () {
        setState(() => _selectedMode = mode);
        final service = context.read<DownloadService>();
        service.updateOptions(
          service.options.copyWith(mode: mode),
        );
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: isSelected
              ? AppTheme.spotifyGreen.withAlpha(30)
              : AppTheme.spotifyGrey,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isSelected ? AppTheme.spotifyGreen : Colors.transparent,
            width: 1.5,
          ),
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          style: TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 14,
            color: isSelected ? AppTheme.spotifyGreen : AppTheme.spotifySubtle,
          ),
        ),
      ),
    );
  }
}
