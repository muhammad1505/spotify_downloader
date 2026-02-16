package com.spotify.downloader

import android.Manifest
import android.content.Intent
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
import java.util.UUID
import org.json.JSONArray
import org.json.JSONObject

class MainActivity : FlutterActivity() {

    private val METHOD_CHANNEL = "com.spotify.downloader/bridge"
    private val EVENT_CHANNEL = "com.spotify.downloader/progress"

    private var downloadJob: Job? = null
    private var eventSink: EventChannel.EventSink? = null
    private val coroutineScope = CoroutineScope(Dispatchers.IO + SupervisorJob())
    private val queue = ArrayDeque<QueueTask>()
    private val runningTasks = mutableMapOf<String, QueueTask>()
    private var maxConcurrent = 1

    companion object {
        private const val PERMISSION_REQUEST_CODE = 100
    }

    data class QueueTask(
        val id: String,
        val url: String,
        val outputDir: String,
        val quality: String,
        val skipExisting: Boolean,
        val embedArt: Boolean,
        val normalize: Boolean,
        var status: String = "queued"
    )

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
                "addToQueue" -> {
                    val url = call.argument<String>("url") ?: ""
                    val outputDir = call.argument<String>("outputDir") ?: ""
                    val quality = call.argument<String>("quality") ?: "320"
                    val skipExisting = call.argument<Boolean>("skipExisting") ?: true
                    val embedArt = call.argument<Boolean>("embedArt") ?: true
                    val normalize = call.argument<Boolean>("normalize") ?: false

                    val taskId = UUID.randomUUID().toString()
                    val task = QueueTask(
                        id = taskId,
                        url = url,
                        outputDir = outputDir,
                        quality = quality,
                        skipExisting = skipExisting,
                        embedArt = embedArt,
                        normalize = normalize
                    )
                    queue.add(task)
                    processQueue()
                    result.success(taskId)
                }
                "pauseTask" -> {
                    val id = call.argument<String>("id") ?: ""
                    pauseTask(id)
                    result.success(true)
                }
                "resumeTask" -> {
                    val id = call.argument<String>("id") ?: ""
                    resumeTask(id)
                    result.success(true)
                }
                "cancelTask" -> {
                    val id = call.argument<String>("id") ?: ""
                    cancelTask(id)
                    result.success(true)
                }
                "cancelAll" -> {
                    cancelAll()
                    result.success(true)
                }
                "getQueueStatus" -> {
                    result.success(getQueueStatus())
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
                        val version = getEngineVersion()
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

    private fun processQueue() {
        while (runningTasks.size < maxConcurrent && queue.isNotEmpty()) {
            val task = queue.removeFirst()
            task.status = "downloading"
            runningTasks[task.id] = task
            coroutineScope.launch {
                try {
                    withContext(Dispatchers.Main) {
                        eventSink?.success(
                            """{"id":"${task.id}","status":"downloading","progress":1,"message":"Starting download..."}"""
                        )
                    }
                    startForegroundDownload(task)
                    val py = Python.getInstance()
                    val module = py.getModule("downloader")
                    module.callAttr("set_event_sink", PythonEventSink())
                    module.callAttr(
                        "start_download",
                        task.id,
                        task.url,
                        task.outputDir,
                        task.quality,
                        task.skipExisting,
                        task.embedArt,
                        task.normalize
                    )
                } catch (e: Exception) {
                    withContext(Dispatchers.Main) {
                        eventSink?.success(
                            """{"id":"${task.id}","status":"error","progress":0,"message":"${e.message?.replace("\"", "\\\"")}" }"""
                        )
                    }
                } finally {
                    runningTasks.remove(task.id)
                    stopForegroundIfIdle()
                    processQueue()
                }
            }
        }
    }

    private fun pauseTask(id: String) {
        runningTasks[id]?.status = "paused"
        coroutineScope.launch {
            try {
                val py = Python.getInstance()
                val module = py.getModule("downloader")
                module.callAttr("cancel_task", id)
            } catch (_: Exception) {}
        }
        val task = runningTasks.remove(id)
        if (task != null) {
            task.status = "paused"
            queue.addFirst(task)
        }
    }

    private fun resumeTask(id: String) {
        val task = queue.find { it.id == id }
        if (task != null) {
            task.status = "queued"
            processQueue()
        }
    }

    private fun cancelTask(id: String) {
        coroutineScope.launch {
            try {
                val py = Python.getInstance()
                val module = py.getModule("downloader")
                module.callAttr("cancel_task", id)
            } catch (_: Exception) {}
        }
        runningTasks.remove(id)
        queue.removeIf { it.id == id }
        stopForegroundIfIdle()
    }

    private fun cancelAll() {
        coroutineScope.launch {
            try {
                val py = Python.getInstance()
                val module = py.getModule("downloader")
                module.callAttr("cancel_all")
            } catch (_: Exception) {}
        }
        runningTasks.clear()
        queue.clear()
        stopForegroundIfIdle()
    }

    private fun getQueueStatus(): String {
        val arr = JSONArray()
        for (task in runningTasks.values) {
            arr.put(JSONObject().apply {
                put("id", task.id)
                put("url", task.url)
                put("status", task.status)
            })
        }
        for (task in queue) {
            arr.put(JSONObject().apply {
                put("id", task.id)
                put("url", task.url)
                put("status", task.status)
            })
        }
        return arr.toString()
    }

    private fun startForegroundDownload(task: QueueTask) {
        val intent = Intent(this, DownloadForegroundService::class.java).apply {
            action = DownloadForegroundService.ACTION_START
            putExtra(DownloadForegroundService.EXTRA_TITLE, "Downloading...")
        }
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            startForegroundService(intent)
        } else {
            startService(intent)
        }
    }

    private fun stopForegroundIfIdle() {
        if (runningTasks.isEmpty()) {
            val intent = Intent(this, DownloadForegroundService::class.java).apply {
                action = DownloadForegroundService.ACTION_STOP
            }
            startService(intent)
        }
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
                val module = py.getModule("downloader_service")
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
                val module = py.getModule("downloader_service")
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
            val module = py.getModule("downloader_service")
            module.callAttr("validate_url", url).toString()
        } catch (e: Exception) {
            """{"valid":false,"type":null,"url":"$url","message":"${e.message}"}"""
        }
    }

    private suspend fun getEngineVersion(): String {
        return try {
            val py = Python.getInstance()
            val module = py.getModule("downloader_service")
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
