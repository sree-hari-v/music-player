package com.sreehari.music

import android.app.NotificationChannel
import android.app.NotificationManager
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.database.ContentObserver
import android.media.AudioManager
import android.net.Uri
import android.os.Build
import android.os.Bundle
import android.os.Handler
import android.os.Looper
import android.os.PowerManager
import android.provider.Settings
import androidx.core.app.NotificationCompat
import androidx.core.content.ContextCompat
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val VOLUME_CHANNEL = "com.sreehari.music/volume"
    private val VOLUME_EVENTS_CHANNEL = "com.sreehari.music/volume_events"
    private val NOTIFICATIONS_CHANNEL = "com.sreehari.music/notifications"

    private var audioManager: AudioManager? = null
    private var volumeEventSink: EventChannel.EventSink? = null
    private var volumeReceiver: BroadcastReceiver? = null
    private var volumeObserver: ContentObserver? = null
    private var lastEmittedVolume: Double = -1.0
    private var pendingPermissionResult: MethodChannel.Result? = null

    companion object {
        const val PLAYBACK_CHANNEL_ID = MusicNotificationService.CHANNEL_ID
        var notificationsChannel: MethodChannel? = null

        fun sendActionToFlutter(action: String) {
            Handler(Looper.getMainLooper()).post {
                notificationsChannel?.invokeMethod("onNotificationAction", mapOf("action" to action))
            }
        }

        fun sendSeekActionToFlutter(positionMs: Long) {
            Handler(Looper.getMainLooper()).post {
                notificationsChannel?.invokeMethod(
                    "onNotificationAction",
                    mapOf("action" to "seek", "position" to positionMs)
                )
            }
        }
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        volumeControlStream = AudioManager.STREAM_MUSIC
        audioManager = getSystemService(Context.AUDIO_SERVICE) as? AudioManager

        deleteObsoleteChannels()

        // Auto-request POST_NOTIFICATIONS on Android 13+ at launch.
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            if (checkSelfPermission(android.Manifest.permission.POST_NOTIFICATIONS)
                != android.content.pm.PackageManager.PERMISSION_GRANTED) {
                requestPermissions(arrayOf(android.Manifest.permission.POST_NOTIFICATIONS), 101)
            }
        }
    }

    private fun deleteObsoleteChannels() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val nm = getSystemService(Context.NOTIFICATION_SERVICE) as? NotificationManager ?: return
            val obsoleteChannels = listOf(
                "com.sreehari.music.playback.v1",
                "com.sreehari.music.playback.v2",
                "com.sreehari.music.playback.v3",
                "com.sreehari.music.playback.v4",
                "com.sreehari.music.playback.v5",
                "com.sreehari.music.playback.v6",
                "com.sreehari.music.playback.v7"
            )
            for (id in obsoleteChannels) {
                try {
                    nm.deleteNotificationChannel(id)
                } catch (_: Exception) {}
            }
        }
    }

    override fun onRequestPermissionsResult(
        requestCode: Int,
        permissions: Array<out String>,
        grantResults: IntArray
    ) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        if (requestCode == 101) {
            val granted = grantResults.isNotEmpty() && grantResults[0] == android.content.pm.PackageManager.PERMISSION_GRANTED
            pendingPermissionResult?.success(granted)
            pendingPermissionResult = null
        }
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        val channel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, NOTIFICATIONS_CHANNEL)
        notificationsChannel = channel

        channel.setMethodCallHandler { call, result ->
            when (call.method) {
                "updateNotification" -> {
                    try {
                        val title = call.argument<String>("title") ?: "Shadow Music"
                        val artist = call.argument<String>("artist") ?: "Unknown Artist"
                        val album = call.argument<String>("album") ?: ""
                        val isPlaying = call.argument<Boolean>("isPlaying") ?: false
                        val positionMs = (call.argument<Number>("positionMs"))?.toLong() ?: 0L
                        val durationMs = (call.argument<Number>("durationMs"))?.toLong() ?: 0L
                        val artBytes = call.argument<ByteArray>("artBytes")
                        val artPath = call.argument<String>("artPath")
                        val hasNext = call.argument<Boolean>("hasNext") ?: true
                        val hasPrev = call.argument<Boolean>("hasPrev") ?: true
                        val isShuffle = call.argument<Boolean>("isShuffle") ?: false

                        val intent = Intent(this@MainActivity, MusicNotificationService::class.java).apply {
                            setAction(MusicNotificationService.ACTION_UPDATE)
                            putExtra(MusicNotificationService.EXTRA_TITLE, title)
                            putExtra(MusicNotificationService.EXTRA_ARTIST, artist)
                            putExtra(MusicNotificationService.EXTRA_ALBUM, album)
                            putExtra(MusicNotificationService.EXTRA_IS_PLAYING, isPlaying)
                            putExtra(MusicNotificationService.EXTRA_POSITION_MS, positionMs)
                            putExtra(MusicNotificationService.EXTRA_DURATION_MS, durationMs)
                            putExtra(MusicNotificationService.EXTRA_ART_BYTES, artBytes)
                            putExtra(MusicNotificationService.EXTRA_ART_PATH, artPath)
                            putExtra(MusicNotificationService.EXTRA_HAS_NEXT, hasNext)
                            putExtra(MusicNotificationService.EXTRA_HAS_PREV, hasPrev)
                            putExtra(MusicNotificationService.EXTRA_IS_SHUFFLE, isShuffle)
                        }
                        ContextCompat.startForegroundService(this@MainActivity, intent)
                        result.success(true)
                    } catch (e: Exception) {
                        result.error("UPDATE_ERROR", e.message, null)
                    }
                }
                "clearNotification" -> {
                    try {
                        val intent = Intent(this@MainActivity, MusicNotificationService::class.java).apply {
                            action = MusicNotificationService.ACTION_STOP
                        }
                        startService(intent)
                        result.success(true)
                    } catch (e: Exception) {
                        result.error("CLEAR_ERROR", e.message, null)
                    }
                }
                "requestPermission" -> {
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
                        val isGranted = checkSelfPermission(android.Manifest.permission.POST_NOTIFICATIONS) == android.content.pm.PackageManager.PERMISSION_GRANTED
                        if (isGranted) {
                            result.success(true)
                        } else {
                            pendingPermissionResult?.success(false)
                            pendingPermissionResult = result
                            requestPermissions(arrayOf(android.Manifest.permission.POST_NOTIFICATIONS), 101)
                        }
                    } else {
                        result.success(true)
                    }
                }
                "isBatteryOptimizationIgnored" -> {
                    val pm = getSystemService(Context.POWER_SERVICE) as? PowerManager
                    val ignored = pm?.isIgnoringBatteryOptimizations(packageName) ?: true
                    result.success(ignored)
                }
                "requestBatteryOptimization" -> {
                    try {
                        val pm = getSystemService(Context.POWER_SERVICE) as? PowerManager
                        if (pm != null && !pm.isIgnoringBatteryOptimizations(packageName)) {
                            val intent = Intent(
                                Settings.ACTION_REQUEST_IGNORE_BATTERY_OPTIMIZATIONS,
                                Uri.parse("package:$packageName")
                            ).apply { addFlags(Intent.FLAG_ACTIVITY_NEW_TASK) }
                            startActivity(intent)
                        }
                        result.success(true)
                    } catch (e: Exception) {
                        try {
                            val intent = Intent(Settings.ACTION_IGNORE_BATTERY_OPTIMIZATION_SETTINGS)
                                .apply { addFlags(Intent.FLAG_ACTIVITY_NEW_TASK) }
                            startActivity(intent)
                        } catch (_: Exception) {}
                        result.success(false)
                    }
                }
                "sendTestNotification" -> {
                    try {
                        val nm = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
                        val iconId = resources.getIdentifier("ic_notification", "drawable", packageName)
                        val builder = NotificationCompat.Builder(this, PLAYBACK_CHANNEL_ID)
                            .setSmallIcon(if (iconId != 0) iconId else android.R.drawable.ic_media_play)
                            .setContentTitle("Shadow Player")
                            .setContentText("Notification channel is active! ✓")
                            .setPriority(NotificationCompat.PRIORITY_DEFAULT)
                            .setAutoCancel(true)
                        nm.notify(9999, builder.build())
                        result.success(true)
                    } catch (e: Exception) {
                        result.error("ERROR", e.message, null)
                    }
                }
                "areNotificationsEnabled" -> {
                    val nm = getSystemService(Context.NOTIFICATION_SERVICE) as? NotificationManager
                    var isEnabled = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) {
                        nm?.areNotificationsEnabled() ?: true
                    } else {
                        true
                    }
                    if (isEnabled && Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
                        val hasRuntimePerm = checkSelfPermission(android.Manifest.permission.POST_NOTIFICATIONS) == android.content.pm.PackageManager.PERMISSION_GRANTED
                        if (!hasRuntimePerm) {
                            isEnabled = false
                        }
                    }
                    if (isEnabled && Build.VERSION.SDK_INT >= Build.VERSION_CODES.O && nm != null) {
                        val channel = nm.getNotificationChannel(PLAYBACK_CHANNEL_ID)
                        if (channel != null && channel.importance == NotificationManager.IMPORTANCE_NONE) {
                            isEnabled = false
                        }
                    }
                    result.success(isEnabled)
                }
                "openNotificationSettings" -> {
                    try {
                        val intent = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                            Intent(Settings.ACTION_APP_NOTIFICATION_SETTINGS).apply {
                                putExtra(Settings.EXTRA_APP_PACKAGE, packageName)
                                putExtra("android.provider.extra.APP_PACKAGE", packageName)
                                addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                            }
                        } else {
                            Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS).apply {
                                data = Uri.parse("package:$packageName")
                                addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                            }
                        }
                        startActivity(intent)
                        result.success(true)
                    } catch (e: Exception) {
                        try {
                            val fallbackIntent = Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS).apply {
                                data = Uri.parse("package:$packageName")
                                addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                            }
                            startActivity(fallbackIntent)
                            result.success(true)
                        } catch (e2: Exception) {
                            result.error("ERROR", e2.message, null)
                        }
                    }
                }
                "openAppDetailsSettings" -> {
                    try {
                        val intent = Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS).apply {
                            data = Uri.parse("package:$packageName")
                            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                        }
                        startActivity(intent)
                        result.success(true)
                    } catch (e: Exception) {
                        result.error("ERROR", e.message, null)
                    }
                }
                else -> result.notImplemented()
            }
        }

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, VOLUME_CHANNEL).setMethodCallHandler { call, result ->
            val am = audioManager ?: (getSystemService(Context.AUDIO_SERVICE) as? AudioManager)
            if (am == null) {
                result.error("UNAVAILABLE", "AudioManager unavailable", null)
                return@setMethodCallHandler
            }

            when (call.method) {
                "getVolume" -> {
                    val current = am.getStreamVolume(AudioManager.STREAM_MUSIC)
                    val max = am.getStreamMaxVolume(AudioManager.STREAM_MUSIC)
                    val vol = if (max > 0) current.toDouble() / max.toDouble() else 0.5
                    result.success(vol)
                }
                "setVolume" -> {
                    val volume = call.argument<Double>("volume") ?: 0.5
                    val max = am.getStreamMaxVolume(AudioManager.STREAM_MUSIC)
                    val targetVolume = (volume * max).toInt().coerceIn(0, max)
                    am.setStreamVolume(AudioManager.STREAM_MUSIC, targetVolume, 0)
                    lastEmittedVolume = if (max > 0) targetVolume.toDouble() / max.toDouble() else 0.5
                    result.success(null)
                }
                else -> result.notImplemented()
            }
        }

        EventChannel(flutterEngine.dartExecutor.binaryMessenger, VOLUME_EVENTS_CHANNEL).setStreamHandler(
            object : EventChannel.StreamHandler {
                override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
                    volumeEventSink = events
                    emitCurrentVolume(force = true)
                    registerVolumeWatcher()
                }

                override fun onCancel(arguments: Any?) {
                    unregisterVolumeWatcher()
                    volumeEventSink = null
                }
            }
        )
    }

    private fun emitCurrentVolume(force: Boolean = false) {
        val am = audioManager ?: (getSystemService(Context.AUDIO_SERVICE) as? AudioManager) ?: return
        val current = am.getStreamVolume(AudioManager.STREAM_MUSIC)
        val max = am.getStreamMaxVolume(AudioManager.STREAM_MUSIC)
        val vol = if (max > 0) current.toDouble() / max.toDouble() else 0.5
        if (force || Math.abs(vol - lastEmittedVolume) > 0.001) {
            lastEmittedVolume = vol
            Handler(Looper.getMainLooper()).post {
                volumeEventSink?.success(vol)
            }
        }
    }

    private fun registerVolumeWatcher() {
        if (volumeObserver == null) {
            volumeObserver = object : ContentObserver(Handler(Looper.getMainLooper())) {
                override fun onChange(selfChange: Boolean) {
                    super.onChange(selfChange)
                    emitCurrentVolume()
                }
            }
            try {
                contentResolver.registerContentObserver(
                    Settings.System.CONTENT_URI,
                    true,
                    volumeObserver!!
                )
            } catch (_: Exception) {}
        }

        if (volumeReceiver == null) {
            volumeReceiver = object : BroadcastReceiver() {
                override fun onReceive(context: Context?, intent: Intent?) {
                    if (intent?.action == "android.media.VOLUME_CHANGED_ACTION") {
                        emitCurrentVolume()
                    }
                }
            }
            val filter = IntentFilter("android.media.VOLUME_CHANGED_ACTION")
            try {
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
                    registerReceiver(volumeReceiver, filter, Context.RECEIVER_EXPORTED)
                } else {
                    registerReceiver(volumeReceiver, filter)
                }
            } catch (_: Exception) {}
        }
    }

    private fun unregisterVolumeWatcher() {
        volumeObserver?.let {
            try {
                contentResolver.unregisterContentObserver(it)
            } catch (_: Exception) {}
            volumeObserver = null
        }
        volumeReceiver?.let {
            try {
                unregisterReceiver(it)
            } catch (_: Exception) {}
            volumeReceiver = null
        }
    }

    override fun onDestroy() {
        unregisterVolumeWatcher()
        notificationsChannel = null
        super.onDestroy()
    }
}
