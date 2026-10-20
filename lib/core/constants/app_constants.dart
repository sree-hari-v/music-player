/// Application-wide constants for Shadow Player.
class AppConstants {
  AppConstants._();

  static const String appName = 'Shadow Player';
  static const String appVersion = '1.0.0 (Phase 1)';

  // Storage keys for SharedPreferences
  static const String keyFolderUri = 'sp_folder_uri';
  static const String keyFolderName = 'sp_folder_name';
  static const String keyLastScannedTime = 'sp_last_scanned_time';

  // Storage keys for Last Played Song
  static const String keyLastPlayedTrackJson = 'sp_last_played_track_json';
  static const String keyLastPlayedPositionMs = 'sp_last_played_position_ms';
  static const String keyLastPlayedQueue = 'sp_last_played_queue';
  static const String keyLastPlayedQueueIndex = 'sp_last_played_queue_index';

  // Supported audio file extensions (lowercase with leading dot)
  static const Set<String> supportedAudioExtensions = {
    '.mp3',
    '.m4a',
    '.aac',
    '.flac',
    '.wav',
    '.ogg',
    '.opus',
    '.wma',
    '.aiff',
  };

  // Thumbnail size for SAF album art query
  static const int thumbnailWidth = 512;
  static const int thumbnailHeight = 512;
  static const int thumbnailQuality = 85;
}
