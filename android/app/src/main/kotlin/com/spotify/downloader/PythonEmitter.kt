package com.spotify.downloader

import android.os.Handler
import android.os.Looper
import io.flutter.plugin.common.EventChannel

object PythonEmitter {
    @Volatile
    var sink: EventChannel.EventSink? = null

    private val mainHandler = Handler(Looper.getMainLooper())

    @JvmStatic
    fun emit(payload: String) {
        val target = sink ?: return
        mainHandler.post { target.success(payload) }
    }
}
