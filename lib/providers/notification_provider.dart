import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/services/notification_service.dart';

final notificationsEnabledProvider = StateNotifierProvider<NotificationNotifier, bool>((ref) {
  return NotificationNotifier();
});

class NotificationNotifier extends StateNotifier<bool> with WidgetsBindingObserver {
  NotificationNotifier() : super(true) {
    WidgetsBinding.instance.addObserver(this);
    checkStatus();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      checkStatus();
    }
  }

  Future<void> checkStatus() async {
    final enabled = await NotificationService.areNotificationsEnabled();
    if (!mounted) return;
    state = enabled;
  }

  Future<void> requestPermissionOrOpenSettings() async {
    final granted = await NotificationService.requestPermission();
    if (!granted) {
      await openSettings();
    } else {
      await checkStatus();
    }
  }

  Future<void> openSettings() async {
    await NotificationService.openNotificationSettings();
    await Future.delayed(const Duration(seconds: 1));
    if (!mounted) return;
    await checkStatus();
  }

  Future<void> openAppDetailsSettings() async {
    await NotificationService.openAppDetailsSettings();
    await Future.delayed(const Duration(seconds: 1));
    if (!mounted) return;
    await checkStatus();
  }

  Future<void> requestBatteryOptimization() async {
    await NotificationService.requestBatteryOptimization();
  }

  Future<void> sendTestNotification(BuildContext context) async {
    final messenger = ScaffoldMessenger.of(context);
    final ok = await NotificationService.sendTestNotification();
    if (!mounted) return;
    messenger.showSnackBar(
      SnackBar(
        backgroundColor: ok ? Colors.green.shade700 : Colors.red.shade700,
        content: Text(
          ok
              ? 'Test notification sent! Check your notification panel.'
              : 'Failed — notifications may be blocked. Check Settings > Notifications.',
          style: const TextStyle(color: Colors.white),
        ),
        duration: const Duration(seconds: 4),
      ),
    );
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }
}
