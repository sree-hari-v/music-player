import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Service for inspecting and controlling the physical device media volume
/// via native Android AudioManager with bi-directional synchronization.
class DeviceVolumeService {
  static const MethodChannel _methodChannel = MethodChannel(
    'com.sreehari.music/volume',
  );
  static const EventChannel _eventChannel = EventChannel(
    'com.sreehari.music/volume_events',
  );

  final StreamController<double> _volumeController =
      StreamController<double>.broadcast();

  StreamSubscription? _eventSubscription;
  double _lastKnownVolume = 0.7;

  DeviceVolumeService() {
    _init();
  }

  Stream<double> get volumeStream => _volumeController.stream;
  double get currentVolume => _lastKnownVolume;

  void _init() {
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
      try {
        _eventSubscription = _eventChannel
            .receiveBroadcastStream()
            .map<double>((dynamic event) {
              if (event is num) {
                return event.toDouble().clamp(0.0, 1.0);
              }
              return _lastKnownVolume;
            })
            .listen(
              (vol) {
                _lastKnownVolume = vol;
                _volumeController.add(vol);
              },
              onError: (dynamic error) {
                debugPrint('DeviceVolumeService: Event stream error: $error');
              },
            );

        // Fetch initial device volume
        getVolume()
            .then((vol) {
              _lastKnownVolume = vol;
              _volumeController.add(vol);
            })
            .catchError((dynamic e) {
              debugPrint(
                'DeviceVolumeService: Error getting initial volume: $e',
              );
            });
      } catch (e) {
        debugPrint('DeviceVolumeService: Platform channels not available: $e');
      }
    }
  }

  /// Fetches current hardware media stream volume (0.0 to 1.0).
  Future<double> getVolume() async {
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
      try {
        final result = await _methodChannel.invokeMethod<double>('getVolume');
        if (result != null) {
          _lastKnownVolume = result.clamp(0.0, 1.0);
          return _lastKnownVolume;
        }
      } on MissingPluginException {
        // Fallback for test and simulated environments
      } catch (e) {
        debugPrint('DeviceVolumeService: getVolume failed: $e');
      }
    }
    return _lastKnownVolume;
  }

  /// Sets hardware media stream volume (0.0 to 1.0).
  Future<void> setVolume(double volume) async {
    final clamped = volume.clamp(0.0, 1.0);
    _lastKnownVolume = clamped;
    _volumeController.add(clamped);

    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
      try {
        await _methodChannel.invokeMethod<void>('setVolume', {
          'volume': clamped,
        });
      } on MissingPluginException {
        // Fallback for test and simulated environments
      } catch (e) {
        debugPrint('DeviceVolumeService: setVolume failed: $e');
      }
    }
  }

  void dispose() {
    _eventSubscription?.cancel();
    _volumeController.close();
  }
}
