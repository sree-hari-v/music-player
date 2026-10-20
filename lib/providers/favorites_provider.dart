import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

class FavoritesNotifier extends StateNotifier<Set<String>> {
  static const String _prefKey = 'shadow_favorite_tracks';
  final SharedPreferences? _prefs;

  FavoritesNotifier([this._prefs]) : super({}) {
    _init();
  }

  Future<void> _init() async {
    final prefs = _prefs ?? await SharedPreferences.getInstance();
    final list = prefs.getStringList(_prefKey) ?? [];
    state = list.toSet();
  }

  Future<void> toggleFavorite(String trackId) async {
    final prefs = _prefs ?? await SharedPreferences.getInstance();
    final current = Set<String>.from(state);
    if (current.contains(trackId)) {
      current.remove(trackId);
    } else {
      current.add(trackId);
    }
    state = current;
    await prefs.setStringList(_prefKey, current.toList());
  }

  bool isFavorite(String trackId) => state.contains(trackId);
}

final favoritesProvider = StateNotifierProvider<FavoritesNotifier, Set<String>>(
  (ref) {
    return FavoritesNotifier();
  },
);
