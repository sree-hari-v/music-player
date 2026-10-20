import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme/app_colors.dart';
import '../../../core/utils/audio_file_utils.dart';
import '../../../data/models/local_track.dart';
import '../../../providers/audio_player_provider.dart';
import '../../../providers/music_library_provider.dart';
import '../../../shared/widgets/alphabet_fast_scroller.dart';
import '../../player/presentation/mini_player.dart';
import '../../player/presentation/now_playing_screen.dart';
import '../../library/presentation/widgets/track_tile.dart';

/// Spotify-style Playlist/Folder screen for "All Songs".
class AllSongsFolderScreen extends ConsumerStatefulWidget {
  const AllSongsFolderScreen({super.key});

  @override
  ConsumerState<AllSongsFolderScreen> createState() =>
      _AllSongsFolderScreenState();
}

class _AllSongsFolderScreenState extends ConsumerState<AllSongsFolderScreen> {
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  String _filter = '';

  @override
  void dispose() {
    _searchController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  String _getSortLabel(SortOption option) {
    switch (option) {
      case SortOption.title:
        return 'Title';
      case SortOption.artist:
        return 'Artist';
      case SortOption.album:
        return 'Album';
      case SortOption.duration:
        return 'Duration';
      case SortOption.dateAdded:
        return 'Date Added';
    }
  }

  @override
  Widget build(BuildContext context) {
    final libraryState = ref.watch(musicLibraryProvider);
    final allTracks = ref.watch(sortedTracksProvider);
    final playbackNotifier = ref.read(audioPlaybackProvider.notifier);

    final filteredTracks = _filter.isEmpty
        ? allTracks
        : allTracks
              .where(
                (t) =>
                    t.title.toLowerCase().contains(_filter) ||
                    t.artist.toLowerCase().contains(_filter) ||
                    t.album.toLowerCase().contains(_filter),
              )
              .toList();

    int totalDurationMs = 0;
    for (final t in allTracks) {
      totalDurationMs += t.duration?.inMilliseconds ?? 0;
    }
    final totalDuration = Duration(milliseconds: totalDurationMs);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: AlphabetFastScroller(
        scrollController: _scrollController,
        tracks: filteredTracks,
        itemHeight: 64.0,
        letterSelector: (track) {
          if (libraryState.sortOption == SortOption.artist) {
            return track.artist;
          } else if (libraryState.sortOption == SortOption.album) {
            return track.album;
          }
          return track.title;
        },
        child: CustomScrollView(
          controller: _scrollController,
          slivers: [
          // Collapsible Spotify Playlist Header
          SliverAppBar(
            expandedHeight: 260,
            pinned: true,
            backgroundColor: AppColors.background,
            leading: IconButton(
              icon: const Icon(
                Icons.arrow_back_ios_new_rounded,
                color: Colors.white,
              ),
              onPressed: () => Navigator.pop(context),
            ),
            flexibleSpace: FlexibleSpaceBar(
              background: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Color(0xFF450A12), // Deep crimson header glow
                      Color(0xFF200508),
                      Color(0xFF000000), // Pure OLED black
                    ],
                  ),
                ),
                child: SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 48, 20, 16),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        // Folder Artwork Card
                        Container(
                          width: 120,
                          height: 120,
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [Color(0xFFE50914), Color(0xFF8B0000)],
                            ),
                            borderRadius: BorderRadius.circular(8),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.8),
                                blurRadius: 16,
                                offset: const Offset(0, 8),
                              ),
                            ],
                          ),
                          child: const Center(
                            child: Icon(
                              Icons.folder_special_rounded,
                              size: 54,
                              color: Colors.white,
                            ),
                          ),
                        ),
                        const SizedBox(width: 16),
                        // Metadata
                        Expanded(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'OFFLINE FOLDER',
                                style: TextStyle(
                                  color: AppColors.textSecondary,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 1.2,
                                ),
                              ),
                              const SizedBox(height: 4),
                              const Text(
                                'All Songs',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 22,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                '${libraryState.folder?.name ?? "Local Storage"} • ${allTracks.length} tracks',
                                style: const TextStyle(
                                  color: Colors.white70,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                AudioFileUtils.formatDuration(totalDuration),
                                style: const TextStyle(
                                  color: AppColors.textSecondary,
                                  fontSize: 11,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),

          // Control Bar: Action Buttons & Filter
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Column(
                children: [
                  Row(
                    children: [
                      // Play All Button
                      GestureDetector(
                        onTap: () {
                          if (filteredTracks.isNotEmpty) {
                            playbackNotifier.playTrack(
                              filteredTracks.first,
                              queue: allTracks,
                            );
                            NowPlayingScreen.open(context);
                          }
                        },
                        child: Container(
                          width: 50,
                          height: 50,
                          decoration: const BoxDecoration(
                            color: AppColors.accent,
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: Color(0x66E50914),
                                blurRadius: 14,
                                offset: Offset(0, 4),
                              ),
                            ],
                          ),
                          child: const Icon(
                            Icons.play_arrow_rounded,
                            color: Colors.white,
                            size: 32,
                          ),
                        ),
                      ),
                      const SizedBox(width: 14),

                      // Shuffle Play Button
                      IconButton(
                        icon: const Icon(
                          Icons.shuffle_rounded,
                          color: AppColors.accent,
                          size: 28,
                        ),
                        onPressed: () {
                          if (filteredTracks.isNotEmpty) {
                            final shuffled = List<LocalTrack>.from(
                              allTracks,
                            )..shuffle();
                            playbackNotifier.playTrack(
                              shuffled.first,
                              queue: shuffled,
                            );
                            NowPlayingScreen.open(context);
                          }
                        },
                      ),
                      const Spacer(),

                      // Swipe hint badge
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.surfaceVariant,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: AppColors.borderSubtle,
                            width: 0.5,
                          ),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.swipe_right_rounded,
                              size: 14,
                              color: AppColors.accent,
                            ),
                            SizedBox(width: 4),
                            Text(
                              'Swipe to queue',
                              style: TextStyle(
                                color: AppColors.textSecondary,
                                fontSize: 10.5,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 10),

                  // Sort Option Selector Row
                  Row(
                    children: [
                      const Text(
                        'Sort by:',
                        style: TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 12.5,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(width: 8),
                      PopupMenuButton<SortOption>(
                        initialValue: libraryState.sortOption,
                        onSelected: (option) => ref
                            .read(musicLibraryProvider.notifier)
                            .setSortOption(option),
                        color: AppColors.card,
                        elevation: 8,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                          side: const BorderSide(
                            color: AppColors.border,
                            width: 1,
                          ),
                        ),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 5,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.surfaceVariant,
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(
                              color: AppColors.borderSubtle,
                              width: 0.5,
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                _getSortLabel(libraryState.sortOption),
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(width: 4),
                              const Icon(
                                Icons.arrow_drop_down_rounded,
                                color: Colors.white,
                                size: 18,
                              ),
                            ],
                          ),
                        ),
                        itemBuilder: (context) => const [
                          PopupMenuItem(
                            value: SortOption.title,
                            child: Text('Title'),
                          ),
                          PopupMenuItem(
                            value: SortOption.artist,
                            child: Text('Artist'),
                          ),
                          PopupMenuItem(
                            value: SortOption.album,
                            child: Text('Album'),
                          ),
                          PopupMenuItem(
                            value: SortOption.duration,
                            child: Text('Duration'),
                          ),
                          PopupMenuItem(
                            value: SortOption.dateAdded,
                            child: Text('Date Added'),
                          ),
                        ],
                      ),
                      const Spacer(),
                      IconButton(
                        icon: Icon(
                          libraryState.sortAscending
                              ? Icons.arrow_upward_rounded
                              : Icons.arrow_downward_rounded,
                          size: 18,
                          color: AppColors.accent,
                        ),
                        tooltip: libraryState.sortAscending
                            ? 'Ascending'
                            : 'Descending',
                        onPressed: () => ref
                            .read(musicLibraryProvider.notifier)
                            .toggleSortAscending(),
                      ),
                    ],
                  ),

                  const SizedBox(height: 8),

                  // Search / Filter inside folder
                  TextField(
                    controller: _searchController,
                    onChanged: (val) {
                      setState(() {
                        _filter = val.trim().toLowerCase();
                      });
                    },
                    style: const TextStyle(color: Colors.white, fontSize: 13),
                    decoration: InputDecoration(
                      hintText: 'Find in All Songs',
                      hintStyle: const TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 13,
                      ),
                      prefixIcon: const Icon(
                        Icons.search_rounded,
                        color: AppColors.textSecondary,
                        size: 20,
                      ),
                      suffixIcon: _filter.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear_rounded, size: 18),
                              onPressed: () {
                                _searchController.clear();
                                setState(() {
                                  _filter = '';
                                });
                              },
                            )
                          : null,
                      filled: true,
                      fillColor: AppColors.surfaceVariant,
                      contentPadding: const EdgeInsets.symmetric(vertical: 8),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide.none,
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: const BorderSide(
                          color: AppColors.borderSubtle,
                          width: 0.5,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // High-Performance Virtualized Track List with O(1) item extent
          SliverFixedExtentList(
            itemExtent: 64.0,
            delegate: SliverChildBuilderDelegate((context, index) {
              final track = filteredTracks[index];
              return TrackTile(
                track: track,
                index: index + 1,
                onTap: () {
                  playbackNotifier.playTrack(track, queue: allTracks);
                  NowPlayingScreen.open(context);
                },
              );
            }, childCount: filteredTracks.length),
          ),

          const SliverToBoxAdapter(child: SizedBox(height: 24)),
        ],
      ),
    ),
      bottomNavigationBar: const SafeArea(top: false, child: MiniPlayer()),
    );
  }
}
