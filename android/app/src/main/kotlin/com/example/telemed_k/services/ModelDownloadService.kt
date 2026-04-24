// Licensed under the Creative Commons Attribution 4.0 International License (CC-BY 4.0)
// You may obtain a copy of the License at https://creativecommons.org/licenses/by/4.0/
//
// TeleMed_K: Offline-first telemedicine app for seniors

package com.example.telemed_k.services

import android.app.DownloadManager
import android.content.Context
import android.net.Uri
import android.util.Log
import java.io.File

/**
 * Downloads the Gemma 4 E2B LiteRT-LM model using Android DownloadManager.
 *
 * Source: https://huggingface.co/litert-community/gemma-4-E2B-it-litert-lm/resolve/main/gemma-4-E2B-it.litertlm
 * Destination: context.filesDir/models/gemma-4-E2B-it.litertlm
 *
 * DownloadManager runs the transfer in a system-managed background service with
 * progress shown in the notification shade. The calling code should re-check
 * [isModelDownloaded] (or watch [getLocalModelPath]) after the notification
 * DOWNLOAD_COMPLETE broadcast fires before initialising the Engine.
 */
class ModelDownloadService(private val context: Context) {

    companion object {
        private const val TAG = "ModelDownloadService"

        private const val MODEL_URL =
            "https://huggingface.co/litert-community/gemma-4-E2B-it-litert-lm/resolve/main/gemma-4-E2B-it.litertlm"

        private const val MODEL_FILENAME = "gemma-4-E2B-it.litertlm"
        private const val MODEL_SUBDIR = "models"
    }

    /** Absolute path where the model will be (or already is) stored. */
    fun getLocalModelPath(): String =
        File(context.filesDir, "$MODEL_SUBDIR/$MODEL_FILENAME").absolutePath

    /** Returns true if the model file exists on disk and is non-empty. */
    fun isModelDownloaded(): Boolean {
        val file = File(getLocalModelPath())
        return file.exists() && file.length() > 0L
    }

    /**
     * Starts a DownloadManager transfer for the model weights.
     *
     * If the file already exists this is a no-op — returns the local path
     * immediately without enqueuing a download.
     *
     * @return The local path where the model will be saved. The file may not
     *         exist yet if a download was just enqueued; poll [isModelDownloaded]
     *         or wait for the ACTION_DOWNLOAD_COMPLETE broadcast.
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
            setTitle("VitalEase — Descărcare model AI")
            setDescription("Gemma 4 E2B (~2.6 GB) — necesar pentru triajul vocal local")
            // Show download progress in the notification shade; complete notification when done
            setNotificationVisibility(
                DownloadManager.Request.VISIBILITY_VISIBLE_NOTIFY_COMPLETED
            )
            // Write directly into app-private files dir (no external storage permission needed)
            setDestinationUri(Uri.fromFile(File(localPath)))
            // Only download over Wi-Fi — model is ~2.6 GB
            setAllowedNetworkTypes(DownloadManager.Request.NETWORK_WIFI)
            setAllowedOverRoaming(false)
        }

        val downloadId = manager.enqueue(request)
        Log.i(TAG, "Model download enqueued (id=$downloadId) → $localPath")

        return localPath
    }

    /**
     * Queries DownloadManager for the status of any pending model download.
     * Returns a [DownloadStatus] summary for display in the UI.
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
                DownloadManager.STATUS_RUNNING, DownloadManager.STATUS_PENDING ->
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
    /** No download has been started. */
    object NotStarted : DownloadStatus()

    /** Download is queued or actively transferring. */
    data class InProgress(val bytesDownloaded: Long, val totalBytes: Long) : DownloadStatus() {
        val progressFraction: Float
            get() = if (totalBytes > 0) bytesDownloaded.toFloat() / totalBytes else 0f
    }

    /** Download was paused (e.g. Wi-Fi dropped). */
    data class Paused(val bytesDownloaded: Long, val totalBytes: Long) : DownloadStatus()

    /** Download failed — re-enqueue to retry. */
    object Failed : DownloadStatus()

    /** File is on disk, ready to load into the Engine. */
    data class Complete(val localPath: String) : DownloadStatus()
}
