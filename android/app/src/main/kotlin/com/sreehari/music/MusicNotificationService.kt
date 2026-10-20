package com.sreehari.music

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Context
import android.content.Intent
import android.content.pm.ServiceInfo
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.os.Build
import android.os.IBinder
import android.support.v4.media.MediaMetadataCompat
import android.support.v4.media.session.MediaSessionCompat
import android.support.v4.media.session.PlaybackStateCompat
import androidx.core.app.NotificationCompat
import androidx.media.app.NotificationCompat.MediaStyle
import java.io.File

class MusicNotificationService : Service() {
    private var mediaSession: MediaSessionCompat? = null

    companion object {
        const val NOTIFICATION_ID = 2001
        const val CHANNEL_ID = "com.sreehari.music.playback.v8"
        const val CHANNEL_NAME = "Shadow Music Playback"

        const val ACTION_UPDATE = "com.sreehari.music.service.ACTION_UPDATE"
        const val ACTION_STOP = "com.sreehari.music.service.ACTION_STOP"

        const val EXTRA_TITLE = "extra_title"
        const val EXTRA_ARTIST = "extra_artist"
        const val EXTRA_ALBUM = "extra_album"
        const val EXTRA_IS_PLAYING = "extra_is_playing"
        const val EXTRA_POSITION_MS = "extra_position_ms"
        const val EXTRA_DURATION_MS = "extra_duration_ms"
        const val EXTRA_ART_BYTES = "extra_art_bytes"
        const val EXTRA_ART_PATH = "extra_art_path"
        const val EXTRA_HAS_NEXT = "extra_has_next"
        const val EXTRA_HAS_PREV = "extra_has_prev"
        const val EXTRA_IS_SHUFFLE = "extra_is_shuffle"

        private var lastArtBytes: ByteArray? = null
        private var lastArtPath: String? = null
        private var lastCachedBitmap: Bitmap? = null
    }

    override fun onCreate() {
        super.onCreate()
        createNotificationChannel()
        initMediaSession()
    }

    private fun createNotificationChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val nm = getSystemService(Context.NOTIFICATION_SERVICE) as? NotificationManager ?: return
            val channel = NotificationChannel(
                CHANNEL_ID,
                CHANNEL_NAME,
                NotificationManager.IMPORTANCE_DEFAULT
            ).apply {
                description = "Shadow Music interactive media playback controls"
                setShowBadge(true)
                lockscreenVisibility = Notification.VISIBILITY_PUBLIC
                setSound(null, null)
                enableVibration(false)
            }
            nm.createNotificationChannel(channel)
        }
    }

    private fun initMediaSession() {
        try {
            mediaSession = MediaSessionCompat(this, "ShadowPlayerMediaSession").apply {
                setCallback(object : MediaSessionCompat.Callback() {
                    override fun onPlay() {
                        MainActivity.sendActionToFlutter("play")
                    }

                    override fun onPause() {
                        MainActivity.sendActionToFlutter("pause")
                    }

                    override fun onSkipToNext() {
                        MainActivity.sendActionToFlutter("next")
                    }

                    override fun onSkipToPrevious() {
                        MainActivity.sendActionToFlutter("prev")
                    }

                    override fun onSeekTo(pos: Long) {
                        MainActivity.sendSeekActionToFlutter(pos)
                    }

                    override fun onSetShuffleMode(shuffleMode: Int) {
                        MainActivity.sendActionToFlutter("shuffle")
                    }

                    override fun onStop() {
                        MainActivity.sendActionToFlutter("stop")
                    }
                })
                isActive = true
            }
        } catch (_: Exception) {}
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        val action = intent?.action ?: return START_NOT_STICKY

        when (action) {
            ACTION_UPDATE -> {
                val title = intent.getStringExtra(EXTRA_TITLE) ?: "Shadow Music"
                val artist = intent.getStringExtra(EXTRA_ARTIST) ?: "Unknown Artist"
                val album = intent.getStringExtra(EXTRA_ALBUM) ?: ""
                val isPlaying = intent.getBooleanExtra(EXTRA_IS_PLAYING, false)
                val positionMs = intent.getLongExtra(EXTRA_POSITION_MS, 0L)
                val durationMs = intent.getLongExtra(EXTRA_DURATION_MS, 0L)
                val artBytes = intent.getByteArrayExtra(EXTRA_ART_BYTES)
                val artPath = intent.getStringExtra(EXTRA_ART_PATH)
                val hasNext = intent.getBooleanExtra(EXTRA_HAS_NEXT, true)
                val hasPrev = intent.getBooleanExtra(EXTRA_HAS_PREV, true)
                val isShuffle = intent.getBooleanExtra(EXTRA_IS_SHUFFLE, false)

                updatePlayback(
                    title = title,
                    artist = artist,
                    album = album,
                    isPlaying = isPlaying,
                    positionMs = positionMs,
                    durationMs = durationMs,
                    artBytes = artBytes,
                    artPath = artPath,
                    hasNext = hasNext,
                    hasPrev = hasPrev,
                    isShuffle = isShuffle
                )
            }
            ACTION_STOP -> {
                try {
                    lastCachedBitmap = null
                    lastArtPath = null
                    lastArtBytes = null
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) {
                        stopForeground(STOP_FOREGROUND_REMOVE)
                    } else {
                        @Suppress("DEPRECATION")
                        stopForeground(true)
                    }
                    val nm = getSystemService(Context.NOTIFICATION_SERVICE) as? NotificationManager
                    nm?.cancel(NOTIFICATION_ID)
                } catch (_: Exception) {}
                stopSelf()
            }
        }

        return START_NOT_STICKY
    }

    private fun decodeScaledBitmap(artBytes: ByteArray?, artPath: String?): Bitmap? {
        val cleanPath = when {
            artPath == null -> null
            artPath.startsWith("file://") -> artPath.substring(7)
            else -> artPath
        }

        val hasPath = !cleanPath.isNullOrBlank() && File(cleanPath).exists() && File(cleanPath).length() > 0
        val hasBytes = artBytes != null && artBytes.isNotEmpty()

        if (!hasPath && !hasBytes) {
            lastArtBytes = null
            lastArtPath = null
            lastCachedBitmap = null
            return null
        }

        // Return cached bitmap if path matches
        if (hasPath && cleanPath == lastArtPath && lastCachedBitmap != null && !lastCachedBitmap!!.isRecycled) {
            return lastCachedBitmap
        }

        // Return cached bitmap if bytes match
        if (hasBytes && artBytes.contentEquals(lastArtBytes) && lastCachedBitmap != null && !lastCachedBitmap!!.isRecycled) {
            return lastCachedBitmap
        }

        val maxDimension = 512

        // 1. Try decoding from file path first
        if (hasPath && cleanPath != null) {
            try {
                val boundsOptions = BitmapFactory.Options().apply { inJustDecodeBounds = true }
                BitmapFactory.decodeFile(cleanPath, boundsOptions)

                var inSampleSize = 1
                while (boundsOptions.outHeight / inSampleSize > maxDimension || boundsOptions.outWidth / inSampleSize > maxDimension) {
                    inSampleSize *= 2
                }

                val decodeOptions = BitmapFactory.Options().apply {
                    this.inSampleSize = inSampleSize
                    inPreferredConfig = Bitmap.Config.ARGB_8888
                }
                val decoded = BitmapFactory.decodeFile(cleanPath, decodeOptions)
                if (decoded != null) {
                    lastArtPath = cleanPath
                    lastArtBytes = null
                    lastCachedBitmap = decoded
                    return decoded
                }
            } catch (_: Exception) {}
        }

        // 2. Fallback to decoding from byte array
        if (hasBytes && artBytes != null) {
            try {
                val boundsOptions = BitmapFactory.Options().apply { inJustDecodeBounds = true }
                BitmapFactory.decodeByteArray(artBytes, 0, artBytes.size, boundsOptions)

                var inSampleSize = 1
                while (boundsOptions.outHeight / inSampleSize > maxDimension || boundsOptions.outWidth / inSampleSize > maxDimension) {
                    inSampleSize *= 2
                }

                val decodeOptions = BitmapFactory.Options().apply {
                    this.inSampleSize = inSampleSize
                    inPreferredConfig = Bitmap.Config.ARGB_8888
                }
                val decoded = BitmapFactory.decodeByteArray(artBytes, 0, artBytes.size, decodeOptions)
                if (decoded != null) {
                    lastArtBytes = artBytes
                    lastArtPath = null
                    lastCachedBitmap = decoded
                    return decoded
                }
            } catch (_: Exception) {}
        }

        return null
    }

    private fun updatePlayback(
        title: String,
        artist: String,
        album: String,
        isPlaying: Boolean,
        positionMs: Long,
        durationMs: Long,
        artBytes: ByteArray?,
        artPath: String?,
        hasNext: Boolean,
        hasPrev: Boolean,
        isShuffle: Boolean = false
    ) {
        val bitmap = decodeScaledBitmap(artBytes, artPath)

        // 1. Update MediaSessionCompat state and metadata
        mediaSession?.let { session ->
            val metadataBuilder = MediaMetadataCompat.Builder()
                .putString(MediaMetadataCompat.METADATA_KEY_TITLE, title)
                .putString(MediaMetadataCompat.METADATA_KEY_ARTIST, artist)
                .putString(MediaMetadataCompat.METADATA_KEY_ALBUM, album)
                .putLong(MediaMetadataCompat.METADATA_KEY_DURATION, if (durationMs > 0) durationMs else -1L)

            if (bitmap != null) {
                metadataBuilder.putBitmap(MediaMetadataCompat.METADATA_KEY_ART, bitmap)
                metadataBuilder.putBitmap(MediaMetadataCompat.METADATA_KEY_ALBUM_ART, bitmap)
                metadataBuilder.putBitmap(MediaMetadataCompat.METADATA_KEY_DISPLAY_ICON, bitmap)
            }
            session.setMetadata(metadataBuilder.build())

            val playbackState = if (isPlaying) PlaybackStateCompat.STATE_PLAYING else PlaybackStateCompat.STATE_PAUSED
            var actions = PlaybackStateCompat.ACTION_PLAY or
                    PlaybackStateCompat.ACTION_PAUSE or
                    PlaybackStateCompat.ACTION_PLAY_PAUSE or
                    PlaybackStateCompat.ACTION_SET_SHUFFLE_MODE or
                    PlaybackStateCompat.ACTION_STOP
            if (durationMs > 0) {
                actions = actions or PlaybackStateCompat.ACTION_SEEK_TO
            }
            if (hasNext) actions = actions or PlaybackStateCompat.ACTION_SKIP_TO_NEXT
            if (hasPrev) actions = actions or PlaybackStateCompat.ACTION_SKIP_TO_PREVIOUS

            val stateBuilder = PlaybackStateCompat.Builder()
                .setActions(actions)
                .setState(playbackState, positionMs, if (isPlaying) 1.0f else 0.0f)

            session.setPlaybackState(stateBuilder.build())
            session.isActive = true
        }

        // 2. Build Notification with MediaStyle
        val contentIntent = Intent(this, MainActivity::class.java).apply {
            flags = Intent.FLAG_ACTIVITY_SINGLE_TOP or Intent.FLAG_ACTIVITY_CLEAR_TOP
        }
        val contentPendingIntent = PendingIntent.getActivity(
            this,
            0,
            contentIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )

        val shuffleIntent = Intent(this, MusicActionReceiver::class.java).apply { setAction(MusicActionReceiver.ACTION_SHUFFLE) }
        val shufflePending = PendingIntent.getBroadcast(
            this,
            5,
            shuffleIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )

        val prevIntent = Intent(this, MusicActionReceiver::class.java).apply { setAction(MusicActionReceiver.ACTION_PREV) }
        val prevPending = PendingIntent.getBroadcast(
            this,
            1,
            prevIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )

        val playPauseIntent = Intent(this, MusicActionReceiver::class.java).apply { setAction(MusicActionReceiver.ACTION_PLAY_PAUSE) }
        val playPausePending = PendingIntent.getBroadcast(
            this,
            2,
            playPauseIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )

        val nextIntent = Intent(this, MusicActionReceiver::class.java).apply { setAction(MusicActionReceiver.ACTION_NEXT) }
        val nextPending = PendingIntent.getBroadcast(
            this,
            3,
            nextIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )

        val stopIntent = Intent(this, MusicActionReceiver::class.java).apply { setAction(MusicActionReceiver.ACTION_STOP) }
        val stopPending = PendingIntent.getBroadcast(
            this,
            4,
            stopIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )

        val iconId = resources.getIdentifier("ic_notification", "drawable", packageName)
        val smallIcon = if (iconId != 0) iconId else android.R.drawable.ic_media_play

        val shuffleIconId = resources.getIdentifier(
            if (isShuffle) "ic_notification_shuffle_on" else "ic_notification_shuffle",
            "drawable",
            packageName
        )
        val shuffleIcon = if (shuffleIconId != 0) shuffleIconId else android.R.drawable.ic_media_rew

        val playPauseIcon = if (isPlaying) android.R.drawable.ic_media_pause else android.R.drawable.ic_media_play
        val playPauseTitle = if (isPlaying) "Pause" else "Play"

        // Compact view shows the 3 core playback controls centered: Previous, Play/Pause, Next
        val mediaStyle = MediaStyle()
            .setShowActionsInCompactView(1, 2, 3)
        mediaSession?.let { mediaStyle.setMediaSession(it.sessionToken) }

        // 5 Symmetrical actions:
        // [0: Shuffle] [1: Previous] [2: Play/Pause CENTER] [3: Next] [4: Close]
        val notification = NotificationCompat.Builder(this, CHANNEL_ID)
            .setSmallIcon(smallIcon)
            .setContentTitle(title)
            .setContentText(artist)
            .apply {
                if (album.isNotBlank()) setSubText(album)
                if (bitmap != null) setLargeIcon(bitmap)
            }
            .setContentIntent(contentPendingIntent)
            .setDeleteIntent(stopPending)
            .setStyle(mediaStyle)
            .setVisibility(NotificationCompat.VISIBILITY_PUBLIC)
            .setPriority(NotificationCompat.PRIORITY_DEFAULT)
            .setOngoing(isPlaying)
            .setAutoCancel(false)
            .addAction(shuffleIcon, if (isShuffle) "Shuffle On" else "Shuffle Off", shufflePending)
            .addAction(android.R.drawable.ic_media_previous, "Previous", prevPending)
            .addAction(playPauseIcon, playPauseTitle, playPausePending)
            .addAction(android.R.drawable.ic_media_next, "Next", nextPending)
            .addAction(android.R.drawable.ic_menu_close_clear_cancel, "Close", stopPending)
            .build()

        // 3. Keep service in foreground while active
        try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.UPSIDE_DOWN_CAKE) {
                startForeground(NOTIFICATION_ID, notification, ServiceInfo.FOREGROUND_SERVICE_TYPE_MEDIA_PLAYBACK)
            } else if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                startForeground(NOTIFICATION_ID, notification, ServiceInfo.FOREGROUND_SERVICE_TYPE_MEDIA_PLAYBACK)
            } else {
                startForeground(NOTIFICATION_ID, notification)
            }
        } catch (_: Exception) {
            val nm = getSystemService(Context.NOTIFICATION_SERVICE) as? NotificationManager
            nm?.notify(NOTIFICATION_ID, notification)
        }
    }

    override fun onDestroy() {
        try {
            mediaSession?.isActive = false
            mediaSession?.release()
            mediaSession = null
            lastCachedBitmap = null
            lastArtPath = null
            lastArtBytes = null
        } catch (_: Exception) {}
        super.onDestroy()
    }

    override fun onBind(intent: Intent?): IBinder? = null
}
