// Licensed under the Creative Commons Attribution 4.0 International License (CC-BY 4.0)
// You may obtain a copy of the License at https://creativecommons.org/licenses/by/4.0/
//
// TeleMed Hearth: Offline-first telemedicine app for seniors

package com.example.telemed_k.services

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.Service
import android.content.Context
import android.content.Intent
import android.os.IBinder
import android.util.Log
import androidx.core.app.NotificationCompat
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.cancel
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext
import okhttp3.OkHttpClient
import okhttp3.Request
import java.io.File
import java.io.FileOutputStream
import java.io.IOException
import java.util.concurrent.TimeUnit

/**
 * ForegroundService that keeps the OkHttp model download alive when the app
 * is sent to the background. Android will not kill a process with an active
 * foreground service regardless of memory pressure.
 *
 * Progress is shared via companion-object @Volatile fields so the
 * ModelDownloadService MethodChannel handler can read it from any thread.
 *
 * Resume logic: reads the current partial-file size, sends
 *   Range: bytes=N-  and opens the FileOutputStream in append mode.
 *
 * Failure policy: after 3 consecutive failures the partial file is deleted
 * and bytesDownloaded is reset to 0 so the next attempt starts clean.
 */
class ModelDownloadForegroundService : Service() {

    companion object {
        const val ACTION_START  = "com.example.telemed_k.ACTION_START_DOWNLOAD"
        const val ACTION_CANCEL = "com.example.telemed_k.ACTION_CANCEL_DOWNLOAD"

        private const val NOTIFICATION_ID = 7001
        private const val CHANNEL_ID     = "model_download_channel"
        private const val TAG            = "ModelDownloadFS"

        private const val MODEL_URL      = "https://telemed-b.duckdns.org/gemma-4-E4B-it.litertlm"
        private const val MODEL_FILENAME = "gemma-4-E4B-it.litertlm"
        private const val MODEL_SUBDIR   = "models"
        private const val CHUNK_BYTES    = 64 * 1024
        private const val MAX_FAILURES   = 3

        const val STATUS_NOT_STARTED = 0
        const val STATUS_RUNNING     = 2
        const val STATUS_SUCCESS     = 8
        const val STATUS_FAILED      = 16

        // Written by Service, read by ModelDownloadService MethodChannel handler.
        @Volatile var statusCode:          Int     = STATUS_NOT_STARTED
        @Volatile var bytesDownloaded:     Long    = 0L
        @Volatile var totalBytes:          Long    = -1L
        @Volatile var errorReason:         String? = null
        @Volatile var cancelRequested:     Boolean = false
        @Volatile var consecutiveFailures: Int     = 0

        fun getLocalModelPath(context: Context): String =
            File(context.filesDir, "$MODEL_SUBDIR/$MODEL_FILENAME").absolutePath

        fun isModelDownloaded(context: Context): Boolean {
            val f = File(getLocalModelPath(context))
            return f.exists() && f.length() > 0L
        }
    }

    private val scope = CoroutineScope(SupervisorJob() + Dispatchers.IO)

    private val client = OkHttpClient.Builder()
        .connectTimeout(30, TimeUnit.SECONDS)
        .readTimeout(300, TimeUnit.SECONDS)
        .followRedirects(true)
        .followSslRedirects(true)
        .build()

    // ──────────────────────────────────────────────────────────────────────────
    // Service lifecycle
    // ──────────────────────────────────────────────────────────────────────────

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onCreate() {
        super.onCreate()
        createNotificationChannel()
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        when (intent?.action) {
            ACTION_CANCEL -> {
                cancelRequested = true
                stopForegroundCompat()
                stopSelf()
                return START_NOT_STICKY
            }
            ACTION_START -> {
                if (isModelDownloaded(this)) {
                    statusCode = STATUS_SUCCESS
                    stopSelf()
                    return START_NOT_STICKY
                }
                if (statusCode == STATUS_RUNNING) return START_NOT_STICKY

                cancelRequested = false
                errorReason     = null
                statusCode      = STATUS_RUNNING
                bytesDownloaded = File(getLocalModelPath(this))
                    .takeIf { it.exists() }?.length() ?: 0L

                startForeground(NOTIFICATION_ID, buildNotification("Se descarcă...", 0, -1))
                scope.launch { downloadModel() }
            }
        }
        return START_STICKY
    }

    override fun onDestroy() {
        scope.cancel()
        super.onDestroy()
    }

    @Suppress("DEPRECATION")
    private fun stopForegroundCompat() = stopForeground(true)

    // ──────────────────────────────────────────────────────────────────────────
    // Notification helpers
    // ──────────────────────────────────────────────────────────────────────────

    private fun createNotificationChannel() {
        val channel = NotificationChannel(
            CHANNEL_ID,
            "Descărcare model AI",
            NotificationManager.IMPORTANCE_LOW
        ).apply {
            description = "Progresul descărcării modelului Gemma 4"
            setShowBadge(false)
        }
        (getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager)
            .createNotificationChannel(channel)
    }

    private fun buildNotification(text: String, max: Int, current: Int): Notification =
        NotificationCompat.Builder(this, CHANNEL_ID)
            .setSmallIcon(android.R.drawable.stat_sys_download)
            .setContentTitle("TeleMed Hearth — Descărcare model AI")
            .setContentText(text)
            .setOngoing(true)
            .setPriority(NotificationCompat.PRIORITY_LOW)
            .setOnlyAlertOnce(true)
            .apply {
                if (max > 0) setProgress(max, current, false)
                else         setProgress(0, 0, true)
            }
            .build()

    private fun updateNotification(percent: Int) {
        val dl   = bytesDownloaded / (1024 * 1024)
        val tt   = totalBytes      / (1024 * 1024)
        val text = "Se descarcă modelul AI — $percent% ($dl MB / $tt MB)"
        (getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager)
            .notify(NOTIFICATION_ID, buildNotification(text, 100, percent))
    }

    // Used when the server omits Content-Length — shows MB written, no percentage.
    private fun updateNotificationBytesOnly(mb: Long) {
        val text = "Se descarcă modelul AI — $mb MB..."
        (getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager)
            .notify(NOTIFICATION_ID, buildNotification(text, 0, -1))
    }

    // ──────────────────────────────────────────────────────────────────────────
    // OkHttp streaming download with resume + failure policy
    // ──────────────────────────────────────────────────────────────────────────

    private suspend fun downloadModel() {
        val destFile = File(getLocalModelPath(this))
        val destDir  = destFile.parentFile
        if (destDir != null && !destDir.exists()) destDir.mkdirs()

        // Read partial-file size for resume.
        val resumeFrom = if (destFile.exists()) destFile.length() else 0L

        val request = Request.Builder()
            .url(MODEL_URL)
            .addHeader("Accept", "*/*")
            .addHeader("User-Agent", "TeleMed-K/1.0 OkHttp")
            .apply { if (resumeFrom > 0L) header("Range", "bytes=$resumeFrom-") }
            .build()

        Log.i(TAG, if (resumeFrom > 0L) "Resuming from $resumeFrom bytes" else "Fresh download")

        try {
            client.newCall(request).execute().use { response ->
                Log.i(TAG, "HTTP response code: ${response.code}")
                Log.i(TAG, "Content-Length: ${response.header("Content-Length") ?: "not set"}")
                Log.i(TAG, "Content-Type: ${response.header("Content-Type") ?: "not set"}")
                Log.i(TAG, "Location: ${response.header("Location") ?: "not set"}")

                when {
                    response.code == 416 -> {
                        Log.i(TAG, "HTTP 416 — already complete at $resumeFrom bytes")
                        consecutiveFailures = 0
                        statusCode = STATUS_SUCCESS
                        withContext(Dispatchers.Main) { stopForegroundCompat(); stopSelf() }
                        return
                    }
                    !response.isSuccessful ->
                        throw IOException("HTTP ${response.code}: ${response.message}")
                }

                val isPartial     = response.code == 206
                val contentLength = response.header("Content-Length")?.toLongOrNull() ?: -1L

                if (!isPartial && resumeFrom > 0L) {
                    // Server ignored Range — restart from zero.
                    Log.w(TAG, "Server returned 200 for Range request; restarting")
                    destFile.delete()
                    bytesDownloaded = 0L
                }

                totalBytes = when {
                    isPartial && contentLength >= 0L -> resumeFrom + contentLength
                    contentLength >= 0L              -> contentLength
                    else                             -> -1L
                }

                // Append only when server acknowledged the Range request (206).
                val appendMode = isPartial && resumeFrom > 0L

                // Track bytes written in this session (distinct from cumulative bytesDownloaded).
                var bytesWritten = 0L

                val body = response.body
                    ?: throw IOException("Response body is null (Content-Length=${response.header("Content-Length")})")

                FileOutputStream(destFile, appendMode).use { fos ->
                    val buffer      = ByteArray(CHUNK_BYTES)
                    val inputStream = body.byteStream()
                    var n: Int
                    var lastPct     = -1
                    var lastMb      = -1L

                    while (inputStream.read(buffer).also { n = it } != -1) {
                        if (cancelRequested) {
                            Log.i(TAG, "Cancelled at $bytesDownloaded — partial kept for resume")
                            statusCode = STATUS_NOT_STARTED
                            withContext(Dispatchers.Main) { stopForegroundCompat(); stopSelf() }
                            return
                        }
                        fos.write(buffer, 0, n)
                        bytesDownloaded += n
                        bytesWritten    += n

                        if (totalBytes > 0L) {
                            // Content-Length known — report percentage.
                            val pct = ((bytesDownloaded.toFloat() / totalBytes) * 100).toInt()
                            if (pct != lastPct) {
                                lastPct = pct
                                withContext(Dispatchers.Main) { updateNotification(pct) }
                            }
                        } else {
                            // No Content-Length — report bytes written, no percentage.
                            val mb = bytesDownloaded / (1024 * 1024)
                            if (mb != lastMb) {
                                lastMb = mb
                                withContext(Dispatchers.Main) { updateNotificationBytesOnly(mb) }
                            }
                        }
                    }

                    fos.flush()
                }

                Log.i(TAG, "Stream ended — bytesWritten=$bytesWritten, file=${destFile.length()} bytes")

                if (bytesWritten == 0L) throw IOException("No data received from server")
            }

            Log.i(TAG, "Download complete — ${destFile.length()} bytes")
            consecutiveFailures = 0
            // STATUS_SUCCESS is terminal — never reset to NOT_STARTED.
            statusCode = STATUS_SUCCESS
            withContext(Dispatchers.Main) { stopForegroundCompat(); stopSelf() }

        } catch (e: Exception) {
            if (!cancelRequested) {
                consecutiveFailures++
                Log.e(TAG, "Download failed (consecutive=$consecutiveFailures)", e)

                if (consecutiveFailures >= MAX_FAILURES) {
                    Log.w(TAG, "3 consecutive failures — clearing partial file and resetting")
                    if (destFile.exists()) destFile.delete()
                    bytesDownloaded     = 0L
                    totalBytes          = -1L
                    consecutiveFailures = 0
                    errorReason = "Descărcarea a fost resetată. Încercați din nou."
                } else {
                    if (destFile.exists()) destFile.delete()
                    errorReason = e.message ?: "Unknown error"
                }
                statusCode = STATUS_FAILED
                withContext(Dispatchers.Main) { stopForegroundCompat(); stopSelf() }
            }
        }
    }
}
