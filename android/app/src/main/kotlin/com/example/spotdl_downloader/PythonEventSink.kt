package com.example.spotdl_downloader

import android.os.Handler
import android.os.Looper

class PythonEventSink {
    private val mainHandler = Handler(Looper.getMainLooper())

    fun emit(payload: String) {
        mainHandler.post {
            PythonEmitter.sink?.success(payload)
        }
    }
}
