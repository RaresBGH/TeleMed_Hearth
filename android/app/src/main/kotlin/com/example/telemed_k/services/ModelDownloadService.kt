// Licensed under the Creative Commons Attribution 4.0 International License (CC-BY 4.0)
// You may obtain a copy of the License at https://creativecommons.org/licenses/by/4.0/
//
// TeleMed_K: Offline-first telemedicine app for seniors

package com.example.telemed_k.services

import android.content.Context
import android.util.Log
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext
import okhttp3.OkHttpClient
import okhttp3.Request
import java.io.File
import java.io.FileOutputStream
import java.io.IOException
import java.util.concurrent.TimeUnit

/**
 * Downloads the Gemma 4 E2B LiteRT-LM model via OkHttp with streaming writes,
 * resume-on-restart via HTTP Range header, and cancellation support.
 *
 * Source:      https://telemed-b.duckdns.org/gemma-4-E2B-it.litertlm
 * Destination: context.filesDir/models/gemma-4-E2B-it.litertlm
 *
 * MethodChannel contract (unchanged — Dart side requires no modifications):
 *   startDownload        — starts download in background; returns null immediately
 *   getDownloadProgress  — returns Map {status, bytesDownloaded, totalBytes} or null
 *                          status codes: 2=running  8=success  16=failed
 *   isModelDownloaded    — returns Boolean
 */
class ModelDownloadService(private val context: Context) : MethodChannel.MethodCallHandler {

    companion object {
        private const val TAG = "ModelDownloadService"

        private const val MODEL_URL      = "https://telemed-b.duckdns.org/gemma-4-E2B-it.litertlm"
        private const val MODEL_FILENAME = "gemma-4-E2B-it.litertlm"
        private const val MODEL_SUBDIR   = "models"

        private const val STATUS_NOT_STARTED = 0
        private const val STATUS_RUNNING     = 2
        private const val STATUS_SUCCESS     = 8
        private const val STATUS_FAILED      = 16

        private const val CHUNK_BYTES = 64 * 1024  // 64 KB per write
    }

    private val scope = CoroutineScope(SupervisorJob() + Dispatchers.IO)

    private val client = OkHttpClient.Builder()
        .connectTimeout(30, TimeUnit.SECONDS)
        // Read timeout applies per-chunk. 120 s of silence = stalled connection.
        .readTimeout(120, TimeUnit.SECONDS)
        .build()

    // In-memory progress state — written on IO thread, read from any thread.
    @Volatile private var statusCode:      Int     = STATUS_NOT_STARTED
    @Volatile private var bytesDownloaded: Long    = 0L
    @Volatile private var totalBytes:      Long    = -1L
    @Volatile private var errorReason:     String? = null
    @Volatile private var cancelRequested: Boolean = false

    // ──────────────────────────────────────────────────────────────────────────
    // MethodChannel.MethodCallHandler
    // ──────────────────────────────────────────────────────────────────────────

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "startDownload"       -> handleStartDownload(result)
            "getDownloadProgress" -> handleGetDownloadProgress(result)
            "isModelDownloaded"   -> result.success(isModelDownloaded())
            else                  -> result.notImplemented()
        }
    }

    private fun handleStartDownload(result: MethodChannel.Result) {
        // Return to Dart immediately so it can begin polling getDownloadProgress.
        scope.launch(Dispatchers.Main) { result.success(null) }

        if (isModelDownloaded()) {
            statusCode = STATUS_SUCCESS
            return
        }

        // Idempotent — ignore if already running.
        if (statusCode == STATUS_RUNNING) return

        cancelRequested = false
        errorReason     = null
        statusCode      = STATUS_RUNNING
        // Seed bytesDownloaded from any partial file so the first progress
        // report is not 0 on a resumed download.
        bytesDownloaded = File(getLocalModelPath()).takeIf { it.exists() }?.length() ?: 0L

        scope.launch { downloadModel() }
    }

    private fun handleGetDownloadProgress(result: MethodChannel.Result) {
        scope.launch {
            try {
                val progressMap: Map<String, Any?>? = when (val s = queryDownloadStatus()) {
                    is DownloadStatus.NotStarted -> null
                    is DownloadStatus.Complete   -> mapOf(
                        "status"         to 8,
                        "bytesDownloaded" to 0L,
                        "totalBytes"     to 0L,
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
                Log.e(TAG, "Failed to read download progress", e)
                withContext(Dispatchers.Main) {
                    result.error("DOWNLOAD_QUERY_ERROR", e.message, null)
                }
            }
        }
    }

    // ──────────────────────────────────────────────────────────────────────────
    // File helpers
    // ──────────────────────────────────────────────────────────────────────────

    fun getLocalModelPath(): String =
        File(context.filesDir, "$MODEL_SUBDIR/$MODEL_FILENAME").absolutePath

    fun isModelDownloaded(): Boolean {
        val f = File(getLocalModelPath())
        return f.exists() && f.length() > 0L
    }

    fun queryDownloadStatus(): DownloadStatus {
        // Don't report Complete while a download coroutine is still running —
        // the file grows to non-zero before the last chunk is flushed.
        if (isModelDownloaded() && statusCode != STATUS_RUNNING) {
            return DownloadStatus.Complete(getLocalModelPath())
        }
        return when (statusCode) {
            STATUS_RUNNING -> DownloadStatus.InProgress(bytesDownloaded, totalBytes)
            STATUS_FAILED  -> DownloadStatus.Failed(errorReason ?: "Unknown error")
            STATUS_SUCCESS -> DownloadStatus.Complete(getLocalModelPath())
            else           -> DownloadStatus.NotStarted
        }
    }

    // ──────────────────────────────────────────────────────────────────────────
    // OkHttp streaming download
    // ──────────────────────────────────────────────────────────────────────────

    private suspend fun downloadModel() {
        val destFile = File(getLocalModelPath())
        val destDir  = destFile.parentFile
        if (destDir != null && !destDir.exists()) destDir.mkdirs()

        // Determine resume offset from any partial file already on disk.
        val resumeFrom = if (destFile.exists()) destFile.length() else 0L

        val request = Request.Builder()
            .url(MODEL_URL)
            .apply { if (resumeFrom > 0L) header("Range", "bytes=$resumeFrom-") }
            .build()

        Log.i(TAG, if (resumeFrom > 0L)
            "Resuming download from byte $resumeFrom"
        else
            "Starting fresh download → ${destFile.absolutePath}")

        try {
            client.newCall(request).execute().use { response ->

                when {
                    // 416 Range Not Satisfiable — server says the file is already complete.
                    response.code == 416 -> {
                        Log.i(TAG, "HTTP 416: file already complete ($resumeFrom bytes)")
                        statusCode = STATUS_SUCCESS
                        return
                    }
                    !response.isSuccessful -> {
                        throw IOException("HTTP ${response.code}: ${response.message}")
                    }
                }

                val isPartial     = response.code == 206
                val contentLength = response.header("Content-Length")?.toLongOrNull() ?: -1L

                if (!isPartial && resumeFrom > 0L) {
                    // Server ignored our Range header and returned 200 — start over.
                    Log.w(TAG, "Server returned 200 for Range request; restarting from 0")
                    destFile.delete()
                    bytesDownloaded = 0L
                }

                totalBytes = when {
                    isPartial && contentLength >= 0L -> resumeFrom + contentLength
                    contentLength >= 0L              -> contentLength
                    else                             -> -1L
                }

                val body = response.body
                    ?: throw IOException("Response body is null")

                // Append only when the server acknowledged our Range request (206).
                val appendMode = isPartial && resumeFrom > 0L

                FileOutputStream(destFile, appendMode).use { fos ->
                    val buffer = ByteArray(CHUNK_BYTES)
                    val inputStream = body.byteStream()
                    var n: Int
                    while (inputStream.read(buffer).also { n = it } != -1) {
                        if (cancelRequested) {
                            // Leave partial file intact — next startDownload will resume.
                            Log.i(TAG, "Download cancelled at $bytesDownloaded bytes — partial kept")
                            statusCode = STATUS_NOT_STARTED
                            return
                        }
                        fos.write(buffer, 0, n)
                        bytesDownloaded += n
                    }
                }
            }

            if (!isModelDownloaded()) throw IOException("File empty after download completed")

            Log.i(TAG, "Download complete — ${File(getLocalModelPath()).length()} bytes")
            statusCode = STATUS_SUCCESS

        } catch (e: Exception) {
            if (!cancelRequested) {
                Log.e(TAG, "Download failed — deleting partial file", e)
                if (destFile.exists()) destFile.delete()
                errorReason = e.message ?: "Unknown error"
                statusCode  = STATUS_FAILED
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

    data class Failed(val errorReason: String) : DownloadStatus()

    data class Complete(val localPath: String) : DownloadStatus()
}
