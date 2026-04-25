// Licensed under the Creative Commons Attribution 4.0 International License (CC-BY 4.0)
// You may obtain a copy of the License at https://creativecommons.org/licenses/by/4.0/
//
// TeleMed_K: Offline-first telemedicine app for seniors

package com.example.telemed_k.services

import android.app.DownloadManager
import android.content.Context
import android.net.Uri
import android.util.Log
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext
import java.io.File

/**
 * Downloads the Gemma 4 E2B LiteRT-LM model using Android DownloadManager
 * and exposes download control + progress via the `com.telemed_k/model_download`
 * MethodChannel.
 *
 * Source: https://huggingface.co/litert-community/gemma-4-E2B-it-litert-lm/resolve/main/gemma-4-E2B-it.litertlm
 * Destination: context.filesDir/models/gemma-4-E2B-it.litertlm
 *
 * MethodChannel contract:
 *   startDownload        — enqueues the download (no-op if file already present)
 *   getDownloadProgress  — returns Map {status, bytesDownloaded, totalBytes}
 *                          status codes: 1=pending 2=running 4=paused 8=success 16=failed
 *                          returns null if no active download and file absent
 *   isModelDownloaded    — returns Boolean
 */
class ModelDownloadService(private val context: Context) : MethodChannel.MethodCallHandler {

    companion object {
        private const val TAG = "ModelDownloadService"

        private const val MODEL_URL =
            "http://192.168.0.37:8080/gemma-4-E2B-it.litertlm"

        private const val MODEL_FILENAME = "gemma-4-E2B-it.litertlm"
        private const val MODEL_SUBDIR = "models"
    }

    private val scope = CoroutineScope(SupervisorJob() + Dispatchers.IO)

    // ──────────────────────────────────────────────────────────────────────────
    // MethodChannel.MethodCallHandler
    // ──────────────────────────────────────────────────────────────────────────

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "startDownload" -> handleStartDownload(result)
            "getDownloadProgress" -> handleGetDownloadProgress(result)
            "isModelDownloaded" -> result.success(isModelDownloaded())
            else -> result.notImplemented()
        }
    }

    private fun handleStartDownload(result: MethodChannel.Result) {
        scope.launch {
            try {
                ensureModelDownloaded()
                withContext(Dispatchers.Main) { result.success(null) }
            } catch (e: Exception) {
                Log.e(TAG, "Failed to enqueue model download", e)
                withContext(Dispatchers.Main) {
                    result.error("DOWNLOAD_ERROR", e.message, null)
                }
            }
        }
    }

    private fun handleGetDownloadProgress(result: MethodChannel.Result) {
        scope.launch {
            try {
                val progressMap: Map<String, Any?>? = when (val status = queryDownloadStatus()) {
                    is DownloadStatus.NotStarted -> null
                    is DownloadStatus.Complete -> mapOf(
                        "status" to 8,
                        "bytesDownloaded" to 0L,
                        "totalBytes" to 0L,
                    )
                    is DownloadStatus.InProgress -> mapOf(
                        "status" to 2,
                        "bytesDownloaded" to status.bytesDownloaded,
                        "totalBytes" to status.totalBytes,
                    )
                    is DownloadStatus.Paused -> mapOf(
                        "status" to 4,
                        "bytesDownloaded" to status.bytesDownloaded,
                        "totalBytes" to status.totalBytes,
                    )
                    is DownloadStatus.Failed -> mapOf(
                        "status" to 16,
                        "bytesDownloaded" to 0L,
                        "totalBytes" to 0L,
                    )
                }
                withContext(Dispatchers.Main) { result.success(progressMap) }
            } catch (e: Exception) {
                Log.e(TAG, "Failed to query download progress", e)
                withContext(Dispatchers.Main) {
                    result.error("DOWNLOAD_QUERY_ERROR", e.message, null)
                }
            }
        }
    }

    // ──────────────────────────────────────────────────────────────────────────
    // File helpers
    // ──────────────────────────────────────────────────────────────────────────

    /** Absolute path where the model will be (or already is) stored. */
    fun getLocalModelPath(): String =
        File(context.filesDir, "$MODEL_SUBDIR/$MODEL_FILENAME").absolutePath

    /** Returns true if the model file exists on disk and is non-empty. */
    fun isModelDownloaded(): Boolean {
        val file = File(getLocalModelPath())
        return file.exists() && file.length() > 0L
    }

    // ──────────────────────────────────────────────────────────────────────────
    // DownloadManager operations
    // ──────────────────────────────────────────────────────────────────────────

    /**
     * Starts a DownloadManager transfer for the model weights.
     * If the file already exists this is a no-op — returns the local path
     * immediately without enqueuing a new download.
     *
     * @return The local path where the model will be saved.
     */
    fun ensureModelDownloaded(): String {
        val localPath = getLocalModelPath()

        if (isModelDownloaded()) {
            Log.i(TAG, "Model already present at $localPath — skipping download")
            return localPath
        }

        val destDir = File(context.filesDir, MODEL_SUBDIR)
        if (!destDir.exists()) destDir.mkdirs()

        val manager = context.getSystemService(Context.DOWNLOAD_SERVICE) as DownloadManager

        val request = DownloadManager.Request(Uri.parse(MODEL_URL)).apply {
            setTitle("TeleMed_K — Descărcare model AI")
            setDescription("Gemma 4 E2B (~3.6 GB) — necesar pentru triajul vocal local")
            setNotificationVisibility(
                DownloadManager.Request.VISIBILITY_VISIBLE_NOTIFY_COMPLETED
            )
            setDestinationUri(Uri.fromFile(File(localPath)))
            // Require WiFi — model is ~3.6 GB; mobile data would be destructive
            setAllowedNetworkTypes(DownloadManager.Request.NETWORK_WIFI)
            setAllowedOverRoaming(false)
        }

        val downloadId = manager.enqueue(request)
        Log.i(TAG, "Model download enqueued (id=$downloadId) → $localPath")

        return localPath
    }

    /**
     * Queries DownloadManager for the status of any pending model download.
     * Returns [DownloadStatus.Complete] immediately if the file already exists on disk.
     */
    fun queryDownloadStatus(): DownloadStatus {
        if (isModelDownloaded()) return DownloadStatus.Complete(getLocalModelPath())

        val manager = context.getSystemService(Context.DOWNLOAD_SERVICE) as DownloadManager
        val query = DownloadManager.Query().apply {
            setFilterByStatus(
                DownloadManager.STATUS_PENDING or
                DownloadManager.STATUS_RUNNING or
                DownloadManager.STATUS_PAUSED or
                DownloadManager.STATUS_FAILED
            )
        }

        manager.query(query).use { cursor ->
            if (!cursor.moveToFirst()) return DownloadStatus.NotStarted

            val statusCol = cursor.getColumnIndex(DownloadManager.COLUMN_STATUS)
            val bytesCol = cursor.getColumnIndex(DownloadManager.COLUMN_BYTES_DOWNLOADED_SO_FAR)
            val totalCol = cursor.getColumnIndex(DownloadManager.COLUMN_TOTAL_SIZE_BYTES)

            val status = if (statusCol >= 0) cursor.getInt(statusCol) else -1
            val downloaded = if (bytesCol >= 0) cursor.getLong(bytesCol) else 0L
            val total = if (totalCol >= 0) cursor.getLong(totalCol) else -1L

            return when (status) {
                DownloadManager.STATUS_RUNNING,
                DownloadManager.STATUS_PENDING ->
                    DownloadStatus.InProgress(downloaded, total)
                DownloadManager.STATUS_PAUSED ->
                    DownloadStatus.Paused(downloaded, total)
                DownloadManager.STATUS_FAILED ->
                    DownloadStatus.Failed
                else -> DownloadStatus.NotStarted
            }
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

    object Failed : DownloadStatus()

    data class Complete(val localPath: String) : DownloadStatus()
}
