import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

typedef NotificationActionHandler = void Function(String action, dynamic extra);

class NotificationService {
  static const MethodChannel _channel = MethodChannel('com.sreehari.music/notifications');
  static NotificationActionHandler? _actionHandler;
  static bool _handlerInitialized = false;

  /// Registers the callback invoked when notification actions (play, pause, next, prev, seek, stop) occur.
  static void registerActionHandler(NotificationActionHandler handler) {
    _actionHandler = handler;
    if (!_handlerInitialized) {
      _handlerInitialized = true;
      _channel.setMethodCallHandler((call) async {
        if (call.method == 'onNotificationAction') {
          try {
            final args = call.arguments as Map?;
            final action = args?['action'] as String? ?? '';
            final extra = args?['position'];
            _actionHandler?.call(action, extra);
          } catch (e) {
            debugPrint('NotificationService: Error handling action: $e');
          }
        }
      });
    }
  }

  /// Displays or updates the active playback notification with track info, artwork, and controls.
  static Future<void> updateNotification({
    required String title,
    required String artist,
    String album = '',
    required bool isPlaying,
    int positionMs = 0,
    int durationMs = 0,
    String? artPath,
    Uint8List? artBytes,
    bool hasNext = true,
    bool hasPrev = true,
    bool isShuffle = false,
  }) async {
    try {
      await _channel.invokeMethod('updateNotification', {
        'title': title.isNotEmpty ? title : 'Shadow Music',
        'artist': artist.isNotEmpty ? artist : 'Unknown Artist',
        'album': album,
        'isPlaying': isPlaying,
        'positionMs': positionMs,
        'durationMs': durationMs,
        'artPath': artPath,
        'artBytes': artBytes,
        'hasNext': hasNext,
        'hasPrev': hasPrev,
        'isShuffle': isShuffle,
      });
    } catch (e) {
      debugPrint('NotificationService: Error updating notification: $e');
    }
  }

  /// Dismisses the playback notification and stops the background service.
  static Future<void> clearNotification() async {
    try {
      await _channel.invokeMethod('clearNotification');
    } catch (e) {
      debugPrint('NotificationService: Error clearing notification: $e');
    }
  }

  /// Checks whether app notifications are enabled in Android OS settings.
  static Future<bool> areNotificationsEnabled() async {
    try {
      final enabled = await _channel.invokeMethod<bool>('areNotificationsEnabled');
      return enabled ?? true;
    } catch (_) {
      return true;
    }
  }

  /// Requests POST_NOTIFICATIONS runtime permission on Android 13+.
  static Future<bool> requestPermission() async {
    try {
      final granted = await _channel.invokeMethod<bool>('requestPermission');
      return granted ?? true;
    } catch (_) {
      return true;
    }
  }

  /// Opens the device App Notification Settings page (vital for ColorOS / OxygenOS / MIUI).
  static Future<void> openNotificationSettings() async {
    try {
      await _channel.invokeMethod('openNotificationSettings');
    } catch (_) {}
  }

  /// Opens the App Info page (for unrestricted battery and background activity permissions).
  static Future<void> openAppDetailsSettings() async {
    try {
      await _channel.invokeMethod('openAppDetailsSettings');
    } catch (_) {}
  }

  /// Returns true when Shadow Player is already whitelisted from battery optimization.
  static Future<bool> isBatteryOptimizationIgnored() async {
    try {
      final ignored = await _channel.invokeMethod<bool>('isBatteryOptimizationIgnored');
      return ignored ?? true;
    } catch (_) {
      return true;
    }
  }

  /// Shows the system "Ignore battery optimizations?" dialog directly (Android 6+).
  static Future<bool> requestBatteryOptimization() async {
    try {
      final ok = await _channel.invokeMethod<bool>('requestBatteryOptimization');
      return ok ?? false;
    } catch (_) {
      return false;
    }
  }

  /// Posts a one-shot test notification on the playback channel to verify channel is active.
  static Future<bool> sendTestNotification() async {
    try {
      final ok = await _channel.invokeMethod<bool>('sendTestNotification');
      return ok ?? false;
    } catch (_) {
      return false;
    }
  }
}
