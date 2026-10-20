import 'package:flutter/material.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme/app_colors.dart';
import '../../../data/services/notification_service.dart';
import '../../../providers/notification_provider.dart';
import '../../home/presentation/home_screen.dart';
import '../../library/presentation/library_screen.dart';
import '../../player/presentation/mini_player.dart';
import '../../search/presentation/search_screen.dart';

/// Root navigation container with Spotify bottom navigation bar and persistent mini-player.
class MainNavigation extends ConsumerStatefulWidget {
  const MainNavigation({super.key});

  @override
  ConsumerState<MainNavigation> createState() => _MainNavigationState();
}

class _MainNavigationState extends ConsumerState<MainNavigation> {
  int _currentIndex = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      // Step 1: Request POST_NOTIFICATIONS if not yet granted (Android 13+).
      await NotificationService.requestPermission();

      // Step 2: Request battery optimization whitelist directly from OxygenOS/Android.
      // Without this OxygenOS can kill the foreground service aggressively.
      final batteryIgnored = await NotificationService.isBatteryOptimizationIgnored();
      if (!batteryIgnored) {
        await NotificationService.requestBatteryOptimization();
      }

      if (mounted) {
        ref.read(notificationsEnabledProvider.notifier).checkStatus();
      }
    });
  }

  final List<Widget> _screens = const [
    HomeScreen(),
    SearchScreen(),
    LibraryScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: IndexedStack(index: _currentIndex, children: _screens),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: AppColors.background,
          border: const Border(
            top: BorderSide(color: Color(0x1AFFFFFF), width: 0.5),
          ),
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Colors.black.withValues(alpha: 0.85),
              AppColors.background,
            ],
          ),
        ),
        child: SafeArea(
          top: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Persistent Spotify Mini-Player docked right above the nav items
              const MiniPlayer(),

              // Spotify 3-tab Bottom Navigation Row
              SizedBox(
                height: 56,
                child: Row(
                  children: [
                    _buildSpotifyTab(
                      index: 0,
                      icon: Icons.home_filled,
                      unselectedIcon: Icons.home_outlined,
                      label: 'Home',
                    ),
                    _buildSpotifyTab(
                      index: 1,
                      icon: Icons.search_rounded,
                      unselectedIcon: Icons.search_rounded,
                      label: 'Search',
                    ),
                    _buildSpotifyTab(
                      index: 2,
                      icon: Icons.library_music_rounded,
                      unselectedIcon: Icons.library_music_outlined,
                      label: 'Your Library',
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSpotifyTab({
    required int index,
    required IconData icon,
    required IconData unselectedIcon,
    required String label,
  }) {
    final isSelected = _currentIndex == index;

    return Expanded(
      child: InkWell(
        onTap: () {
          setState(() {
            _currentIndex = index;
          });
        },
        splashColor: Colors.transparent,
        highlightColor: Colors.transparent,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              isSelected ? icon : unselectedIcon,
              size: 24,
              color: isSelected ? Colors.white : AppColors.textSecondary,
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                color: isSelected ? Colors.white : AppColors.textSecondary,
                fontSize: 11,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                letterSpacing: -0.2,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
