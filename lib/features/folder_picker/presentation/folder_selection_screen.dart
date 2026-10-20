import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme/app_colors.dart';
import '../../../providers/music_library_provider.dart';

/// Screen displayed when no folder is selected, providing step-by-step SAF guidance.
class FolderSelectionScreen extends ConsumerWidget {
  final bool isModal;

  const FolderSelectionScreen({super.key, this.isModal = false});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final libraryState = ref.watch(musicLibraryProvider);
    final notifier = ref.read(musicLibraryProvider.notifier);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: isModal
          ? AppBar(
              title: const Text('Select Music Directory'),
              leading: IconButton(
                icon: const Icon(Icons.close_rounded),
                onPressed: () => Navigator.of(context).pop(),
              ),
            )
          : null,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(
              horizontal: 26.0,
              vertical: 24.0,
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // Spotify Red Disc Hero Motif
                Container(
                  width: 100,
                  height: 100,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppColors.card,
                    border: Border.all(
                      color: AppColors.accent.withValues(alpha: 0.5),
                      width: 2,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.accent.withValues(alpha: 0.25),
                        blurRadius: 30,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: const Center(
                    child: Icon(
                      Icons.folder_open_rounded,
                      size: 44,
                      color: AppColors.accent,
                    ),
                  ),
                ),

                const SizedBox(height: 28),

                const Text(
                  'Shadow Player',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 26,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(height: 6),
                const Text(
                  'Premium Offline Music Experience',
                  style: TextStyle(
                    color: AppColors.accent,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.4,
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Select the folder where your audio files reside. Shadow Player indexes your local music and starts playing immediately.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 13.5,
                    height: 1.5,
                  ),
                ),

                const SizedBox(height: 32),

                // Primary CTA Button
                SizedBox(
                  width: double.infinity,
                  height: 54,
                  child: ElevatedButton.icon(
                    onPressed:
                        libraryState.status == MusicLibraryStatus.scanning
                        ? null
                        : () async {
                            await notifier.pickAndScanFolder();
                            if (isModal && context.mounted) {
                              Navigator.of(context).pop();
                            }
                          },
                    icon: libraryState.status == MusicLibraryStatus.scanning
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.5,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(Icons.folder_open_rounded, size: 22),
                    label: Text(
                      libraryState.status == MusicLibraryStatus.scanning
                          ? 'Indexing Folder...'
                          : 'Choose Music Folder',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.accent,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(28),
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 28),

                // Step-by-Step Guidance Box
                Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: AppColors.card,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Row(
                        children: [
                          Icon(
                            Icons.touch_app_rounded,
                            size: 18,
                            color: AppColors.accent,
                          ),
                          SizedBox(width: 8),
                          Text(
                            'Quick Folder Selection Guide',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 13.5,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      _buildStepRow('1', 'Tap "Choose Music Folder" above.'),
                      _buildStepRow(
                        '2',
                        'Navigate to your "Music" or audio folder in Android Files.',
                      ),
                      _buildStepRow(
                        '3',
                        'Tap "USE THIS FOLDER" and confirm "ALLOW".',
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 16),

                // Supported Formats Pill
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.card,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: AppColors.borderSubtle,
                      width: 0.5,
                    ),
                  ),
                  child: const Text(
                    'Supported: FLAC • MP3 • M4A • WAV • OGG • OPUS',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStepRow(String number, String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 18,
            height: 18,
            margin: const EdgeInsets.only(top: 2),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.accent.withValues(alpha: 0.2),
            ),
            child: Center(
              child: Text(
                number,
                style: const TextStyle(
                  color: AppColors.accent,
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 12.5,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
