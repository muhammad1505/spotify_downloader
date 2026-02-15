package com.example.spotdl_downloader

import android.Manifest
import android.content.pm.PackageManager
import android.os.Build
import android.os.Bundle
import androidx.core.app.ActivityCompat
import androidx.core.content.ContextCompat
import com.chaquo.python.Python
import com.chaquo.python.android.AndroidPlatform
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel
import kotlinx.coroutines.*
import java.io.BufferedReader
import java.io.InputStreamReader

class MainActivity : FlutterActivity() {

    private val METHOD_CHANNEL = "com.spotdl/bridge"
    private val EVENT_CHANNEL = "com.spotdl/progress"

    private var downloadJob: Job? = null
    private var eventSink: EventChannel.EventSink? = null
    private val coroutineScope = CoroutineScope(Dispatchers.IO + SupervisorJob())

    companion object {
        private const val PERMISSION_REQUEST_CODE = 100
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)

        // Initialize Python
        if (!Python.isStarted()) {
            Python.start(AndroidPlatform(this))
        }

        // Request permissions
        requestRequiredPermissions()
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        // Method Channel
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, METHOD_CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "startDownload" -> {
                    val url = call.argument<String>("url") ?: ""
                    val outputDir = call.argument<String>("outputDir") ?: ""
                    val quality = call.argument<String>("quality") ?: "320"
                    val skipExisting = call.argument<Boolean>("skipExisting") ?: true
                    val embedArt = call.argument<Boolean>("embedArt") ?: true
                    val normalize = call.argument<Boolean>("normalize") ?: false

                    startDownload(url, outputDir, quality, skipExisting, embedArt, normalize)
                    result.success(true)
                }
                "cancelDownload" -> {
                    cancelDownload()
                    result.success(true)
                }
                "validateUrl" -> {
                    val url = call.argument<String>("url") ?: ""
                    val validationResult = validateUrl(url)
                    result.success(validationResult)
                }
                "getVersion" -> {
                    coroutineScope.launch {
                        val version = getSpotdlVersion()
                        withContext(Dispatchers.Main) {
                            result.success(version)
                        }
                    }
                }
                else -> result.notImplemented()
            }
        }

        // Event Channel for progress streaming
        EventChannel(flutterEngine.dartExecutor.binaryMessenger, EVENT_CHANNEL).setStreamHandler(
            object : EventChannel.StreamHandler {
                override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
                    eventSink = events
                    PythonEmitter.sink = events
                }

                override fun onCancel(arguments: Any?) {
                    eventSink = null
                    PythonEmitter.sink = null
                }
            }
        )
    }

    private fun startDownload(
        url: String,
        outputDir: String,
        quality: String,
        skipExisting: Boolean,
        embedArt: Boolean,
        normalize: Boolean
    ) {
        downloadJob?.cancel()

        downloadJob = coroutineScope.launch {
            try {
                val py = Python.getInstance()
                val module = py.getModule("spotdl_service")
                module.callAttr("set_event_sink", PythonEventSink())

                module.callAttr(
                    "start_download",
                    url,
                    outputDir,
                    quality,
                    skipExisting,
                    embedArt,
                    normalize
                )
            } catch (e: Exception) {
                withContext(Dispatchers.Main) {
                    eventSink?.success(
                        """{"status":"error","progress":0,"message":"${e.message?.replace("\"", "\\\"")}","type":"error"}"""
                    )
                }
            }
        }
    }

    private fun cancelDownload() {
        downloadJob?.cancel()
        downloadJob = null

        coroutineScope.launch {
            try {
                val py = Python.getInstance()
                val module = py.getModule("spotdl_service")
                val result = module.callAttr("cancel_download").toString()

                withContext(Dispatchers.Main) {
                    eventSink?.success(result)
                }
            } catch (e: Exception) {
                withContext(Dispatchers.Main) {
                    eventSink?.success(
                        """{"status":"error","progress":0,"message":"${e.message?.replace("\"", "\\\"")}","type":"error"}"""
                    )
                }
            }
        }
    }

    private fun validateUrl(url: String): String {
        return try {
            val py = Python.getInstance()
            val module = py.getModule("spotdl_service")
            module.callAttr("validate_url", url).toString()
        } catch (e: Exception) {
            """{"valid":false,"type":null,"url":"$url","message":"${e.message}"}"""
        }
    }

    private suspend fun getSpotdlVersion(): String {
        return try {
            val py = Python.getInstance()
            val module = py.getModule("spotdl_service")
            module.callAttr("get_version").toString()
        } catch (e: Exception) {
            """{"status":"error","message":"${e.message}","type":"error"}"""
        }
    }

    private fun requestRequiredPermissions() {
        val permissions = mutableListOf<String>()

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            // Android 13+
            if (ContextCompat.checkSelfPermission(this, Manifest.permission.POST_NOTIFICATIONS)
                != PackageManager.PERMISSION_GRANTED
            ) {
                permissions.add(Manifest.permission.POST_NOTIFICATIONS)
            }
            if (ContextCompat.checkSelfPermission(this, Manifest.permission.READ_MEDIA_AUDIO)
                != PackageManager.PERMISSION_GRANTED
            ) {
                permissions.add(Manifest.permission.READ_MEDIA_AUDIO)
            }
        } else {
            if (ContextCompat.checkSelfPermission(this, Manifest.permission.WRITE_EXTERNAL_STORAGE)
                != PackageManager.PERMISSION_GRANTED
            ) {
                permissions.add(Manifest.permission.WRITE_EXTERNAL_STORAGE)
            }
        }

        if (permissions.isNotEmpty()) {
            ActivityCompat.requestPermissions(this, permissions.toTypedArray(), PERMISSION_REQUEST_CODE)
        }
    }

    override fun onDestroy() {
        super.onDestroy()
        downloadJob?.cancel()
        coroutineScope.cancel()
    }
}
