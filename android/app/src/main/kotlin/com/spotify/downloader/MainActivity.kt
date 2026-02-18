package com.spotify.downloader

import android.Manifest
import android.content.Intent
import android.content.pm.PackageManager
import android.os.Build
import android.os.Bundle
import android.os.Environment
import androidx.core.app.ActivityCompat
import androidx.core.content.ContextCompat
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import kotlinx.coroutines.*
import java.io.File
import java.util.UUID
import java.util.concurrent.TimeUnit

class MainActivity : FlutterActivity() {

    private val TERMUX_CHANNEL = "com.spotify.downloader/termux"
    private val coroutineScope = CoroutineScope(Dispatchers.IO + SupervisorJob())
    private val termuxCommands = mutableMapOf<String, TermuxCommandMeta>()

    companion object {
        private const val PERMISSION_REQUEST_CODE = 100
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        requestRequiredPermissions()
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        // Termux bridge channel
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, TERMUX_CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "isTermuxInstalled" -> {
                    result.success(isPackageInstalled("com.termux"))
                }
                "isTermuxTaskerInstalled" -> {
                    result.success(isPackageInstalled("com.termux.tasker"))
                }
                "startCommand" -> {
                    val command = call.argument<String>("command") ?: ""
                    val workDir = call.argument<String>("workDir")
                    val meta = startTermuxCommand(command, workDir)
                    result.success(mapOf(
                        "id" to meta.id,
                        "stdoutPath" to meta.stdoutPath,
                        "stderrPath" to meta.stderrPath,
                        "exitPath" to meta.exitPath,
                    ))
                }
                "checkCommand" -> {
                    val id = call.argument<String>("id") ?: ""
                    val status = checkTermuxCommand(id)
                    result.success(status)
                }
                "runCommand" -> {
                    val command = call.argument<String>("command") ?: ""
                    val workDir = call.argument<String>("workDir")
                    coroutineScope.launch {
                        val payload = runTermuxCommand(command, workDir)
                        withContext(Dispatchers.Main) { result.success(payload) }
                    }
                }
                else -> result.notImplemented()
            }
        }
    }

    data class TermuxCommandMeta(
        val id: String,
        val stdoutPath: String,
        val stderrPath: String,
        val exitPath: String,
    )

    private fun isPackageInstalled(pkg: String): Boolean {
        return try {
            packageManager.getPackageInfo(pkg, 0)
            true
        } catch (_: Exception) {
            false
        }
    }

    private suspend fun runTermuxCommand(command: String, workDir: String?): Map<String, Any> {
        if (!isPackageInstalled("com.termux")) {
            return mapOf(
                "exitCode" to 127,
                "stdout" to "",
                "stderr" to "Termux not installed",
            )
        }
        if (!isPackageInstalled("com.termux.tasker")) {
            return mapOf(
                "exitCode" to 127,
                "stdout" to "",
                "stderr" to "Termux:Tasker not installed",
            )
        }

        val meta = createTermuxCommandMeta()
        val stdoutFile = File(meta.stdoutPath)
        val stderrFile = File(meta.stderrPath)
        val exitFile = File(meta.exitPath)

        val intent = Intent("com.termux.tasker.RUN_COMMAND").apply {
            putExtra("com.termux.tasker.extra.COMMAND", "sh")
            putExtra("com.termux.tasker.extra.ARGUMENTS", arrayOf("-lc", "$command; echo \\$? > ${exitFile.absolutePath}"))
            if (!workDir.isNullOrBlank()) {
                putExtra("com.termux.tasker.extra.WORKDIR", workDir)
            }
            putExtra("com.termux.tasker.extra.STDOUT", stdoutFile.absolutePath)
            putExtra("com.termux.tasker.extra.STDERR", stderrFile.absolutePath)
            putExtra("com.termux.tasker.extra.BACKGROUND", true)
        }
        sendBroadcast(intent)

        val timeoutMs = TimeUnit.SECONDS.toMillis(30)
        val start = System.currentTimeMillis()
        while (!exitFile.exists()) {
            if (System.currentTimeMillis() - start > timeoutMs) {
                return mapOf(
                    "exitCode" to 124,
                    "stdout" to "",
                    "stderr" to "Command timeout. Termux:Tasker did not create exit file. " +
                        "Check: Allow external apps in Termux, run termux-setup-storage, open Termux:Tasker once. " +
                        "Paths: stdout=${stdoutFile.absolutePath}, stderr=${stderrFile.absolutePath}, exit=${exitFile.absolutePath}",
                )
            }
            delay(300)
        }

        val exitCode = try {
            exitFile.readText().trim().toInt()
        } catch (_: Exception) {
            1
        }
        val stdout = if (stdoutFile.exists()) stdoutFile.readText() else ""
        val stderr = if (stderrFile.exists()) stderrFile.readText() else ""
        return mapOf(
            "exitCode" to exitCode,
            "stdout" to stdout,
            "stderr" to stderr,
        )
    }

    private fun startTermuxCommand(command: String, workDir: String?): TermuxCommandMeta {
        val meta = createTermuxCommandMeta()
        val stdoutFile = File(meta.stdoutPath)
        val stderrFile = File(meta.stderrPath)
        val exitFile = File(meta.exitPath)

        val intent = Intent("com.termux.tasker.RUN_COMMAND").apply {
            putExtra("com.termux.tasker.extra.COMMAND", "sh")
            putExtra("com.termux.tasker.extra.ARGUMENTS", arrayOf("-lc", "$command; echo \\$? > ${exitFile.absolutePath}"))
            if (!workDir.isNullOrBlank()) {
                putExtra("com.termux.tasker.extra.WORKDIR", workDir)
            }
            putExtra("com.termux.tasker.extra.STDOUT", stdoutFile.absolutePath)
            putExtra("com.termux.tasker.extra.STDERR", stderrFile.absolutePath)
            putExtra("com.termux.tasker.extra.BACKGROUND", true)
        }
        sendBroadcast(intent)

        termuxCommands[meta.id] = meta
        return meta
    }

    private fun checkTermuxCommand(id: String): Map<String, Any?> {
        val meta = termuxCommands[id] ?: return mapOf("done" to true, "exitCode" to 1)
        val exitFile = File(meta.exitPath)
        if (!exitFile.exists()) {
            return mapOf("done" to false)
        }
        val exitCode = try {
            exitFile.readText().trim().toInt()
        } catch (_: Exception) {
            1
        }
        val stdout = File(meta.stdoutPath).takeIf { it.exists() }?.readText() ?: ""
        val stderr = File(meta.stderrPath).takeIf { it.exists() }?.readText() ?: ""
        return mapOf(
            "done" to true,
            "exitCode" to exitCode,
            "stdout" to stdout,
            "stderr" to stderr,
        )
    }

    private fun createTermuxCommandMeta(): TermuxCommandMeta {
        val baseDir = File(Environment.getExternalStorageDirectory(), "SpotifyDownloader/termux")
        baseDir.mkdirs()
        val id = UUID.randomUUID().toString()
        val stdoutFile = File(baseDir, "stdout_${id}.log")
        val stderrFile = File(baseDir, "stderr_${id}.log")
        val exitFile = File(baseDir, "exit_${id}.code")
        return TermuxCommandMeta(
            id = id,
            stdoutPath = stdoutFile.absolutePath,
            stderrPath = stderrFile.absolutePath,
            exitPath = exitFile.absolutePath,
        )
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
        coroutineScope.cancel()
    }
}
