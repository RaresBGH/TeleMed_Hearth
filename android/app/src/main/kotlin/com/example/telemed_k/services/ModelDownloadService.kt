// Licensed under the Creative Commons Attribution 4.0 International License (CC-BY 4.0)
// You may obtain a copy of the License at https://creativecommons.org/licenses/by/4.0/
//
// TeleMed Hearth: Offline-first telemedicine app for seniors

package com.example.telemed_k.services

import android.content.Context
import android.content.Intent
import android.os.Build
import android.util.Log
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext

/**
 * MethodChannel handler for the `com.telemed_k/model_download` channel.
 *
 * Delegates the actual download to [ModelDownloadForegroundService] so the
 * transfer survives app backgrounding. All progress state lives in the
 * ForegroundService companion object.
 *
 * MethodChannel contract (Dart side unchanged):
 *   startDownload        — fires ForegroundService intent; returns null immediately
 *   getDownloadProgress  — reads companion-object state; returns progress Map or null
 *   isModelDownloaded    — returns Boolean
 */
class ModelDownloadService(private val context: Context) : MethodChannel.MethodCallHandler {

    companion object {
        private const val TAG = "ModelDownloadService"
    }

    private val scope = CoroutineScope(SupervisorJob() + Dispatchers.IO)

    // ──────────────────────────────────────────────────────────────────────────
    // MethodChannel.MethodCallHandler
    // ──────────────────────────────────────────────────────────────────────────

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "startDownload"       -> handleStartDownload(result)
            "getDownloadProgress" -> handleGetDownloadProgress(result)
            "isModelDownloaded"   ->
                result.success(ModelDownloadForegroundService.isModelDownloaded(context))
            else                  -> result.notImplemented()
        }
    }

    private fun handleStartDownload(result: MethodChannel.Result) {
        // Return to Dart immediately so polling can begin.
        scope.launch(Dispatchers.Main) { result.success(null) }

        if (ModelDownloadForegroundService.isModelDownloaded(context)) {
            ModelDownloadForegroundService.statusCode =
                ModelDownloadForegroundService.STATUS_SUCCESS
            return
        }

        if (ModelDownloadForegroundService.statusCode ==
                ModelDownloadForegroundService.STATUS_RUNNING) return

        val intent = Intent(context, ModelDownloadForegroundService::class.java).apply {
            action = ModelDownloadForegroundService.ACTION_START
        }
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            context.startForegroundService(intent)
        } else {
            context.startService(intent)
        }
    }

    private fun handleGetDownloadProgress(result: MethodChannel.Result) {
        scope.launch {
            try {
                val progressMap: Map<String, Any?>? =
                    when (val s = queryDownloadStatus()) {
                        is DownloadStatus.NotStarted -> null
                        is DownloadStatus.Complete   -> mapOf(
                            "status"          to 8,
                            "bytesDownloaded" to 0L,
                            "totalBytes"      to 0L,
                        )
                        is DownloadStatus.InProgress -> mapOf(
                            "status"          to 2,
                            "bytesDownloaded" to s.bytesDownloaded,
                            "totalBytes"      to s.totalBytes,
                        )
                        is DownloadStatus.Paused     -> mapOf(
                            "status"          to 4,
                            "bytesDownloaded" to s.bytesDownloaded,
                            "totalBytes"      to s.totalBytes,
                        )
                        is DownloadStatus.Failed     -> mapOf(
                            "status"          to 16,
                            "bytesDownloaded" to 0L,
                            "totalBytes"      to 0L,
                            "errorReason"     to s.errorReason,
                        )
                    }
                withContext(Dispatchers.Main) { result.success(progressMap) }
            } catch (e: Exception) {
                Log.e(TAG, "Progress query error", e)
                withContext(Dispatchers.Main) {
                    result.error("DOWNLOAD_QUERY_ERROR", e.message, null)
                }
            }
        }
    }

    // ──────────────────────────────────────────────────────────────────────────
    // Status helpers (reads from ForegroundService companion object)
    // ──────────────────────────────────────────────────────────────────────────

    private fun queryDownloadStatus(): DownloadStatus {
        val sc = ModelDownloadForegroundService.statusCode
        if (ModelDownloadForegroundService.isModelDownloaded(context) &&
                sc != ModelDownloadForegroundService.STATUS_RUNNING) {
            return DownloadStatus.Complete(
                ModelDownloadForegroundService.getLocalModelPath(context))
        }
        return when (sc) {
            ModelDownloadForegroundService.STATUS_RUNNING ->
                DownloadStatus.InProgress(
                    ModelDownloadForegroundService.bytesDownloaded,
                    ModelDownloadForegroundService.totalBytes
                )
            ModelDownloadForegroundService.STATUS_FAILED ->
                DownloadStatus.Failed(
                    ModelDownloadForegroundService.errorReason ?: "Unknown error")
            ModelDownloadForegroundService.STATUS_SUCCESS ->
                DownloadStatus.Complete(
                    ModelDownloadForegroundService.getLocalModelPath(context))
            else -> DownloadStatus.NotStarted
        }
    }
}

/** Represents the current state of the model download. */
sealed class DownloadStatus {
    object NotStarted : DownloadStatus()

    data class InProgress(val bytesDownloaded: Long, val totalBytes: Long) : DownloadStatus() {
        val progressFraction: Float
            get() = if (totalBytes > 0) bytesDownloaded.toFloat() / totalBytes else 0f
    }

    data class Paused(val bytesDownloaded: Long, val totalBytes: Long) : DownloadStatus()

    data class Failed(val errorReason: String) : DownloadStatus()

    data class Complete(val localPath: String) : DownloadStatus()
}
