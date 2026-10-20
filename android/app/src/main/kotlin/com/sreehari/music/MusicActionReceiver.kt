package com.sreehari.music

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent

class MusicActionReceiver : BroadcastReceiver() {
    companion object {
        const val ACTION_PLAY = "com.sreehari.music.ACTION_PLAY"
        const val ACTION_PAUSE = "com.sreehari.music.ACTION_PAUSE"
        const val ACTION_PLAY_PAUSE = "com.sreehari.music.ACTION_PLAY_PAUSE"
        const val ACTION_PREV = "com.sreehari.music.ACTION_PREV"
        const val ACTION_NEXT = "com.sreehari.music.ACTION_NEXT"
        const val ACTION_SHUFFLE = "com.sreehari.music.ACTION_SHUFFLE"
        const val ACTION_STOP = "com.sreehari.music.ACTION_STOP"
    }

    override fun onReceive(context: Context, intent: Intent?) {
        val action = intent?.action ?: return
        when (action) {
            ACTION_PLAY_PAUSE -> MainActivity.sendActionToFlutter("playPause")
            ACTION_PLAY -> MainActivity.sendActionToFlutter("play")
            ACTION_PAUSE -> MainActivity.sendActionToFlutter("pause")
            ACTION_PREV -> MainActivity.sendActionToFlutter("prev")
            ACTION_NEXT -> MainActivity.sendActionToFlutter("next")
            ACTION_SHUFFLE -> MainActivity.sendActionToFlutter("shuffle")
            ACTION_STOP -> {
                try {
                    val stopIntent = Intent(context, MusicNotificationService::class.java).apply {
                        setAction(MusicNotificationService.ACTION_STOP)
                    }
                    context.startService(stopIntent)
                } catch (_: Exception) {}
                MainActivity.sendActionToFlutter("stop")
            }
        }
    }
}
