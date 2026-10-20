import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme/app_colors.dart';
import '../../../core/constants/app_constants.dart';
import '../../../providers/music_library_provider.dart';
import '../../../providers/notification_provider.dart';
import '../../player/presentation/mini_player.dart';

/// Settings screen for managing SAF folder permissions, library sync, and storage status.
class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(musicLibraryProvider);
    final notifier = ref.read(musicLibraryProvider.notifier);
    final notificationsEnabled = ref.watch(notificationsEnabledProvider);
    final folder = state.folder;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Settings'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
        children: [
          _buildSectionHeader('Storage & Access'),
          const SizedBox(height: 8),

          Container(
            decoration: BoxDecoration(
              color: AppColors.card,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppColors.border),
            ),
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(
                    Icons.folder_outlined,
                    color: AppColors.accent,
                  ),
                  title: const Text(
                    'Selected Music Folder',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  subtitle: Text(
                    folder?.name ?? 'No folder selected',
                    style: const TextStyle(color: AppColors.textSecondary),
                  ),
                  trailing: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: (folder?.hasValidPermission ?? false)
                          ? const Color(0xFF1B3820)
                          : const Color(0xFF3B1518),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      (folder?.hasValidPermission ?? false)
                          ? 'Active'
                          : 'Expired',
                      style: TextStyle(
                        color: (folder?.hasValidPermission ?? false)
                            ? const Color(0xFF4ADE80)
                            : AppColors.accent,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
                const Divider(color: Color(0x1AFFFFFF)),
                ListTile(
                  leading: const Icon(
                    Icons.folder_open_rounded,
                    color: Colors.white,
                  ),
                  title: const Text(
                    'Change Music Folder',
                    style: TextStyle(color: Colors.white),
                  ),
                  subtitle: const Text(
                    'Select a new folder via Android system file picker',
                    style: TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 12,
                    ),
                  ),
                  onTap: () => notifier.pickAndScanFolder(),
                ),
                const Divider(color: Color(0x1AFFFFFF)),
                ListTile(
                  leading: const Icon(
                    Icons.refresh_rounded,
                    color: Colors.white,
                  ),
                  title: const Text(
                    'Sync Folder in Background',
                    style: TextStyle(color: Colors.white),
                  ),
                  subtitle: const Text(
                    'Check for new songs without interrupting playback',
                    style: TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 12,
                    ),
                  ),
                  onTap: () {
                    notifier.rescan();
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Syncing library in background...'),
                      ),
                    );
                  },
                ),
                if (folder != null) ...[
                  const Divider(color: Color(0x1AFFFFFF)),
                  ListTile(
                    leading: const Icon(
                      Icons.delete_outline_rounded,
                      color: AppColors.accent,
                    ),
                    title: const Text(
                      'Clear Folder Access',
                      style: TextStyle(color: AppColors.accent),
                    ),
                    subtitle: const Text(
                      'Release persisted permission and clear local cache',
                      style: TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 12,
                      ),
                    ),
                    onTap: () => _showClearConfirmation(context, notifier),
                  ),
                ],
              ],
            ),
          ),

          const SizedBox(height: 24),

          _buildSectionHeader('Library Overview'),
          const SizedBox(height: 8),

          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.card,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppColors.border),
            ),
            child: Column(
              children: [
                _buildStatRow('Indexed Tracks', '${state.tracks.length}'),
                const Divider(color: Color(0x1AFFFFFF)),
                _buildStatRow(
                  'Supported Formats',
                  AppConstants.supportedAudioExtensions
                      .join(', ')
                      .toUpperCase(),
                ),
                const Divider(color: Color(0x1AFFFFFF)),
                _buildStatRow('Offline Mode', 'Active (Zero Network Used)'),
              ],
            ),
          ),

          const SizedBox(height: 24),

          _buildSectionHeader('Notifications & Lock Screen Controls'),
          const SizedBox(height: 8),

          Container(
            decoration: BoxDecoration(
              color: AppColors.card,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppColors.border),
            ),
            child: Column(
              children: [
                ListTile(
                  leading: Icon(
                    notificationsEnabled
                        ? Icons.notifications_active_outlined
                        : Icons.notifications_off_outlined,
                    color: notificationsEnabled ? AppColors.accent : Colors.amber,
                  ),
                  title: const Text(
                    'Playback Notification Settings',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  subtitle: Text(
                    notificationsEnabled
                        ? 'Native MediaSession active (v8) with lock screen controls'
                        : 'Notifications disabled or blocked. Tap to enable in system settings',
                    style: TextStyle(
                      color: notificationsEnabled
                          ? AppColors.textSecondary
                          : Colors.amber,
                      fontSize: 12,
                    ),
                  ),
                  trailing: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: notificationsEnabled
                          ? const Color(0xFF1B3820)
                          : const Color(0xFF3B1518),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      notificationsEnabled ? 'Active' : 'Disabled',
                      style: TextStyle(
                        color: notificationsEnabled
                            ? const Color(0xFF4ADE80)
                            : AppColors.accent,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  onTap: () => ref
                      .read(notificationsEnabledProvider.notifier)
                      .openSettings(),
                ),
                const Divider(color: AppColors.border, height: 1),
                ListTile(
                  leading: const Icon(
                    Icons.battery_charging_full_rounded,
                    color: AppColors.accent,
                  ),
                  title: const Text(
                    'Battery Optimization',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  subtitle: const Text(
                    'Tap to whitelist Shadow Player — required for lock screen controls on OxygenOS',
                    style: TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 12,
                    ),
                  ),
                  trailing: const Icon(
                    Icons.arrow_forward_ios_rounded,
                    size: 16,
                    color: AppColors.textSecondary,
                  ),
                  onTap: () async {
                    await ref
                        .read(notificationsEnabledProvider.notifier)
                        .requestBatteryOptimization();
                  },
                ),
                const Divider(color: AppColors.border, height: 1),
                ListTile(
                  leading: const Icon(
                    Icons.science_outlined,
                    color: AppColors.accent,
                  ),
                  title: const Text(
                    'Test Notification',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  subtitle: const Text(
                    'Sends a test notification to verify the notification channel is working',
                    style: TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 12,
                    ),
                  ),
                  trailing: const Icon(
                    Icons.arrow_forward_ios_rounded,
                    size: 16,
                    color: AppColors.textSecondary,
                  ),
                  onTap: () async {
                    await ref
                        .read(notificationsEnabledProvider.notifier)
                        .sendTestNotification(context);
                  },
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          _buildSectionHeader('About Shadow Player'),
          const SizedBox(height: 8),

          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.card,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppColors.border),
            ),
            child: const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Shadow Player',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  'Offline Audio Engine • Spotify Edition',
                  style: TextStyle(
                    color: AppColors.accent,
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                SizedBox(height: 8),
                Text(
                  'Private, offline audio playback with instant cached startup and background folder discovery.',
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 12.5,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 32),
        ],
      ),
      bottomNavigationBar: const SafeArea(top: false, child: MiniPlayer()),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Text(
      title,
      style: const TextStyle(
        color: Colors.white,
        fontSize: 15,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.2,
      ),
    );
  }

  Widget _buildStatRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 13,
            ),
          ),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w600,
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }

  void _showClearConfirmation(
    BuildContext context,
    MusicLibraryNotifier notifier,
  ) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.card,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: AppColors.border, width: 1),
        ),
        title: const Text(
          'Clear Folder Access?',
          style: TextStyle(color: Colors.white),
        ),
        content: const Text(
          'This will release the persisted Android folder permission and clear the local cache. No audio files on your storage will be altered or deleted.',
          style: TextStyle(color: AppColors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel', style: TextStyle(color: Colors.white)),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              notifier.clearFolder();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.accent,
              foregroundColor: Colors.white,
            ),
            child: const Text('Clear Access'),
          ),
        ],
      ),
    );
  }
}
