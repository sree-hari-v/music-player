import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme/app_colors.dart';
import '../../../providers/audio_player_provider.dart';
import '../../../providers/music_library_provider.dart';
import '../../../shared/widgets/empty_state.dart';
import '../../player/presentation/now_playing_screen.dart';
import '../../library/presentation/widgets/track_tile.dart';

/// Spotify-identical Search Screen with browse genre cards and live track playback.
class SearchScreen extends ConsumerStatefulWidget {
  const SearchScreen({super.key});

  @override
  ConsumerState<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends ConsumerState<SearchScreen> {
  final TextEditingController _controller = TextEditingController();

  final List<Map<String, dynamic>> _browseCategories = const [
    {'title': 'Lossless Audio', 'color': Color(0xFFB81D24)},
    {'title': 'Soundtracks', 'color': Color(0xFF8A101C)},
    {'title': 'Rock & Heavy', 'color': Color(0xFF631018)},
    {'title': 'Malayalam Hits', 'color': Color(0xFFE50914)},
    {'title': 'Tamil Anthems', 'color': Color(0xFF991B1B)},
    {'title': 'Acoustic & Indie', 'color': Color(0xFF7F1D1D)},
    {'title': 'Pop & Electronic', 'color': Color(0xFFDC2626)},
    {'title': 'Classical & Instrumental', 'color': Color(0xFF450A0A)},
  ];

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final searchResults = ref.watch(searchResultsProvider);
    final libraryState = ref.watch(musicLibraryProvider);
    final notifier = ref.read(musicLibraryProvider.notifier);
    final playbackNotifier = ref.read(audioPlaybackProvider.notifier);

    final query = libraryState.searchQuery.trim();

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Spotify Big Search Title
            const Padding(
              padding: EdgeInsets.fromLTRB(16, 16, 16, 12),
              child: Text(
                'Search',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 28,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.6,
                ),
              ),
            ),

            // Spotify Search Input Pill
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: TextField(
                controller: _controller,
                autofocus: false,
                style: const TextStyle(
                  color: Colors.black,
                  fontSize: 14.5,
                  fontWeight: FontWeight.w600,
                ),
                decoration: InputDecoration(
                  filled: true,
                  fillColor: Colors.white, // Spotify signature white search bar
                  hintText: 'What do you want to play?',
                  hintStyle: TextStyle(
                    color: Colors.grey.shade600,
                    fontSize: 14.5,
                    fontWeight: FontWeight.w500,
                  ),
                  prefixIcon: const Icon(
                    Icons.search_rounded,
                    size: 24,
                    color: Colors.black,
                  ),
                  suffixIcon: query.isNotEmpty
                      ? IconButton(
                          icon: const Icon(
                            Icons.clear_rounded,
                            size: 20,
                            color: Colors.black,
                          ),
                          onPressed: () {
                            _controller.clear();
                            notifier.setSearchQuery('');
                          },
                        )
                      : null,
                  contentPadding: const EdgeInsets.symmetric(vertical: 12),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide.none,
                  ),
                ),
                onChanged: (val) => notifier.setSearchQuery(val),
              ),
            ),

            const SizedBox(height: 16),

            // Content Area: Browse Cards or Search Results
            Expanded(
              child: query.isEmpty
                  ? _buildBrowseCategories(context, notifier)
                  : searchResults.isEmpty
                  ? EmptyState(
                      icon: Icons.search_off_rounded,
                      title: 'No Matching Songs',
                      message:
                          'No tracks matched "$query". Try searching by artist or album name.',
                    )
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16.0,
                            vertical: 8.0,
                          ),
                          child: Text(
                            '${searchResults.length} results found',
                            style: const TextStyle(
                              color: AppColors.textSecondary,
                              fontSize: 12.5,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        Expanded(
                          child: ListView.separated(
                            padding: const EdgeInsets.only(bottom: 20),
                            itemCount: searchResults.length,
                            separatorBuilder: (_, _) => const Divider(
                              height: 1,
                              color: Color(0x11FFFFFF),
                            ),
                            itemBuilder: (context, index) {
                              final track = searchResults[index];
                              return TrackTile(
                                track: track,
                                index: index + 1,
                                onTap: () {
                                  final allTracks = ref.read(sortedTracksProvider);
                                  playbackNotifier.playTrack(
                                    track,
                                    queue: allTracks.isNotEmpty ? allTracks : searchResults,
                                  );
                                  NowPlayingScreen.open(context);
                                },
                              );
                            },
                          ),
                        ),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBrowseCategories(
    BuildContext context,
    MusicLibraryNotifier notifier,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Search Offline Library',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                ),
              ),
              SizedBox(height: 2),
              Text(
                'Browse by format, tag, or genre',
                style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
              ),
            ],
          ),
        ),
        Expanded(
          child: GridView.builder(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 20),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              childAspectRatio: 1.7,
            ),
            itemCount: _browseCategories.length,
            itemBuilder: (context, index) {
              final cat = _browseCategories[index];
              final color = cat['color'] as Color;
              final title = cat['title'] as String;

              return InkWell(
                onTap: () {
                  if (title == 'Lossless Audio') {
                    _controller.text = 'flac';
                    notifier.setSearchQuery('flac');
                  }
                },
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: color,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Align(
                    alignment: Alignment.topLeft,
                    child: Text(
                      title,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.3,
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}
