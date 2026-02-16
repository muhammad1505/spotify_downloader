import 'package:flutter/material.dart';
import '../core/theme.dart';
import '../core/constants.dart';

class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      physics: const BouncingScrollPhysics(),
      child: Column(
        children: [
          const SizedBox(height: 32),

          // App Icon
          Container(
            width: 100,
            height: 100,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  AppTheme.spotifyGreen,
                  AppTheme.spotifyGreenDark,
                ],
              ),
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: AppTheme.spotifyGreen.withAlpha(80),
                  blurRadius: 24,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: const Icon(
              Icons.music_note_rounded,
              size: 48,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 20),

          // App Name
          const Text(
            AppConstants.appName,
            style: TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'v${AppConstants.appVersion} (Build ${AppConstants.buildNumber})',
            style: TextStyle(
              color: AppTheme.spotifySubtle,
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            decoration: BoxDecoration(
              color: AppTheme.spotifyGreen.withAlpha(20),
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Text(
              'Full Offline Mode',
              style: TextStyle(
                color: AppTheme.spotifyGreen,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(height: 32),

          // Powered By
          const Align(
            alignment: Alignment.centerLeft,
            child: Padding(
              padding: EdgeInsets.only(left: 4, bottom: 8),
              child: Text(
                'POWERED BY',
                style: TextStyle(
                  color: AppTheme.spotifySubtle,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 2,
                ),
              ),
            ),
          ),
          _buildPoweredByCard(
            '💙',
            'Flutter',
            'UI Framework by Google',
            'Cross-platform native app development',
          ),
          _buildPoweredByCard(
            '🐍',
            'Chaquopy',
            'Python on Android',
            'Embedded Python runtime for Android apps',
          ),
          _buildPoweredByCard(
            '🎬',
            'yt-dlp',
            'Media Downloader',
            'Audio/video download backend',
          ),
          _buildPoweredByCard(
            '🔧',
            'FFmpeg',
            'Media Processing',
            'Audio conversion and processing',
          ),
          const SizedBox(height: 24),

          // Links
          Card(
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.code_rounded, color: AppTheme.spotifyGreen),
                  title: const Text(
                    'Source Code',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
                  ),
                  subtitle: Text(
                    'View on GitHub',
                    style: TextStyle(fontSize: 12, color: AppTheme.spotifySubtle),
                  ),
                  trailing: Icon(
                    Icons.open_in_new_rounded,
                    size: 18,
                    color: AppTheme.spotifySubtle.withAlpha(100),
                  ),
                  onTap: () {
                    // TODO: Open GitHub URL
                  },
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                Divider(
                  height: 1,
                  indent: 56,
                  color: AppTheme.spotifyLightGrey.withAlpha(80),
                ),
                ListTile(
                  leading: const Icon(Icons.description_rounded, color: AppTheme.spotifyGreen),
                  title: const Text(
                    'License',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
                  ),
                  subtitle: Text(
                    'MIT License',
                    style: TextStyle(fontSize: 12, color: AppTheme.spotifySubtle),
                  ),
                  trailing: Icon(
                    Icons.chevron_right_rounded,
                    size: 20,
                    color: AppTheme.spotifySubtle.withAlpha(100),
                  ),
                  onTap: () {
                    showLicensePage(
                      context: context,
                      applicationName: AppConstants.appName,
                      applicationVersion: AppConstants.appVersion,
                    );
                  },
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 32),

          // Footer
          Text(
            'Made with ❤️ for Music Lovers',
            style: TextStyle(
              color: AppTheme.spotifySubtle.withAlpha(120),
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _buildPoweredByCard(
    String emoji,
    String title,
    String subtitle,
    String description,
  ) {
    return Card(
      child: ListTile(
        leading: Text(emoji, style: const TextStyle(fontSize: 28)),
        title: Text(
          title,
          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              subtitle,
              style: const TextStyle(
                color: AppTheme.spotifyGreen,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
            Text(
              description,
              style: TextStyle(
                color: AppTheme.spotifySubtle.withAlpha(150),
                fontSize: 11,
              ),
            ),
          ],
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
    );
  }
}
