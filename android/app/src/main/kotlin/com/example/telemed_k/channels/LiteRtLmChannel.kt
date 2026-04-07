// Licensed under the Creative Commons Attribution 4.0 International License (CC-BY 4.0)
// You may obtain a copy of the License at https://creativecommons.org/licenses/by/4.0/
//
// TeleMed_K: Offline-first telemedicine app for seniors
// Native Kotlin Bridge — LiteRT-LM MethodChannel Handler (Gemma 4 E2B)

package com.example.telemed_k.channels

import android.content.Context
import android.net.ConnectivityManager
import android.net.NetworkCapabilities
import android.util.Log
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext

import java.io.File
import java.io.FileOutputStream
import java.net.URL

/**
 * Native handler for the `com.telemed_k/litert_lm` MethodChannel.
 *
 * Bridges Flutter ↔ Google LiteRT-LM for on-device Gemma 4 E2B inference.
 * The model runs entirely locally on the device's TPU/NPU/GPU — no cloud calls.
 *
 * Methods handled:
 *   - downloadWeights   — Downloads the ~2.58 GB 4-bit quantized GGUF model over Wi-Fi
 *   - initializeModel   — Loads the model into the LiteRT-LM runtime memory space
 *   - evaluateAudio     — Feeds raw audio + RAG system prompt for medical triage
 *   - evaluateMedia      — Feeds image/video (up to 60s) + RAG system prompt for visual triage
 */
class LiteRtLmChannel(
    private val context: Context
) : MethodChannel.MethodCallHandler {

    companion object {
        private const val TAG = "LiteRtLmChannel"
        private const val DOWNLOAD_BUFFER_SIZE = 8192
    }

    private val scope = CoroutineScope(SupervisorJob() + Dispatchers.IO)

    // LiteRT-LM inference session — initialized lazily after model weights are loaded.
    // In a production build this would be:
    //   private var inferenceSession: com.google.ai.edge.litertlm.LiteRtLmSession? = null
    // For the initial bridge wiring we use a typed placeholder that compiles against the SDK.
    private var modelPath: String? = null
    private var isModelLoaded = false

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "downloadWeights" -> handleDownloadWeights(call, result)
            "initializeModel" -> handleInitializeModel(call, result)
            "evaluateAudio" -> handleEvaluateAudio(call, result)
            "evaluateMedia" -> handleEvaluateMedia(call, result)
            else -> result.notImplemented()
        }
    }

    // ──────────────────────────────────────────────────────────────────────────
    // downloadWeights
    // ──────────────────────────────────────────────────────────────────────────
    private fun handleDownloadWeights(call: MethodCall, result: MethodChannel.Result) {
        scope.launch {
            try {
                val destinationPath = call.argument<String>("destinationPath")
                    ?: return@launch result.error("INVALID_ARG", "Missing 'destinationPath'", null)
                val modelUrl = call.argument<String>("modelUrl")
                    ?: return@launch result.error("INVALID_ARG", "Missing 'modelUrl'", null)
                val requireWiFi = call.argument<Boolean>("requireWiFi") ?: true

                // Check if model already exists locally (skip redundant download)
                val destFile = File(destinationPath)
                if (destFile.exists() && destFile.length() > 0) {
                    Log.i(TAG, "Model weights already exist at $destinationPath, skipping download")
                    result.success(null)
                    return@launch
                }

                // Enforce Wi-Fi requirement for the ~2.58 GB download
                if (requireWiFi && !isWiFiConnected()) {
                    result.error(
                        "NO_WIFI",
                        "Wi-Fi connection required for model download. Please connect to Wi-Fi and try again.",
                        null
                    )
                    return@launch
                }

                // Ensure parent directories exist
                destFile.parentFile?.mkdirs()

                // Stream download to avoid OOM on low-RAM elderly devices
                withContext(Dispatchers.IO) {
                    val url = URL(modelUrl)
                    val connection = url.openConnection()
                    connection.connectTimeout = 30_000
                    connection.readTimeout = 60_000

                    connection.getInputStream().use { input ->
                        FileOutputStream(destFile).use { output ->
                            val buffer = ByteArray(DOWNLOAD_BUFFER_SIZE)
                            var bytesRead: Int
                            var totalBytesRead = 0L

                            while (input.read(buffer).also { bytesRead = it } != -1) {
                                output.write(buffer, 0, bytesRead)
                                totalBytesRead += bytesRead

                                // Log progress every 50MB
                                if (totalBytesRead % (50 * 1024 * 1024) < DOWNLOAD_BUFFER_SIZE) {
                                    Log.d(TAG, "Download progress: ${totalBytesRead / (1024 * 1024)} MB")
                                }
                            }
                            output.flush()
                        }
                    }
                }

                Log.i(TAG, "Model weights downloaded to $destinationPath")
                result.success(null)
            } catch (e: Exception) {
                Log.e(TAG, "Failed to download model weights", e)
                result.error("DOWNLOAD_ERROR", "Weight download failed", null)
            }
        }
    }

    // ──────────────────────────────────────────────────────────────────────────
    // initializeModel
    // ──────────────────────────────────────────────────────────────────────────
    private fun handleInitializeModel(call: MethodCall, result: MethodChannel.Result) {
        scope.launch {
            try {
                val path = call.argument<String>("modelPath")
                    ?: return@launch result.error("INVALID_ARG", "Missing 'modelPath'", null)

                val modelFile = File(path)
                if (!modelFile.exists()) {
                    result.error(
                        "MODEL_NOT_FOUND",
                        "Model file not found at $path. Call downloadWeights first.",
                        null
                    )
                    return@launch
                }

                // Initialize LiteRT-LM inference session with the local GGUF weights.
                // Production implementation:
                //   inferenceSession = LiteRtLm.createSession(
                //       LiteRtLmConfig.Builder()
                //           .setModelPath(path)
                //           .setBackend(LiteRtLmBackend.GPU_OR_CPU)
                //           .setMaxTokens(8192)
                //           .build()
                //   )
                //
                // Bridge stub — validates file and marks ready:
                modelPath = path
                isModelLoaded = true

                Log.i(TAG, "LiteRT-LM model initialized from $path (${modelFile.length() / (1024 * 1024)} MB)")
                result.success(null)
            } catch (e: Exception) {
                Log.e(TAG, "Failed to initialize LiteRT-LM model", e)
                result.error("MODEL_INIT_ERROR", "Model initialization failed", null)
            }
        }
    }

    // ──────────────────────────────────────────────────────────────────────────
    // evaluateAudio
    // ──────────────────────────────────────────────────────────────────────────
    private fun handleEvaluateAudio(call: MethodCall, result: MethodChannel.Result) {
        scope.launch {
            try {
                ensureModelLoaded()

                val audioPath = call.argument<String>("audioPath")
                    ?: return@launch result.error("INVALID_ARG", "Missing 'audioPath'", null)
                val systemPrompt = call.argument<String>("systemPrompt") ?: ""
                val constraintFormat = call.argument<String>("constraintFormat") ?: "json"

                val audioFile = File(audioPath)
                if (!audioFile.exists()) {
                    result.error("FILE_NOT_FOUND", "Audio file not found at $audioPath", null)
                    return@launch
                }

                // Production implementation:
                //   val audioBytes = audioFile.readBytes()
                //   val response = inferenceSession!!.generateContent(
                //       LiteRtLmRequest.Builder()
                //           .setSystemInstruction(systemPrompt)
                //           .addAudioPart(audioBytes, "audio/wav")
                //           .setResponseMimeType("application/json")
                //           .build()
                //   )
                //   result.success(response.text)
                //
                // Bridge stub — returns a safe placeholder JSON that won't trigger emergency:
                val placeholderResponse = buildPlaceholderTriageResponse(
                    inputType = "audio",
                    filePath = audioPath
                )
                Log.i(TAG, "evaluateAudio processed: $audioPath")
                result.success(placeholderResponse)
            } catch (e: Exception) {
                Log.e(TAG, "Failed to evaluate audio", e)
                result.error("INFERENCE_ERROR", "Audio evaluation failed", null)
            }
        }
    }

    // ──────────────────────────────────────────────────────────────────────────
    // evaluateMedia
    // ──────────────────────────────────────────────────────────────────────────
    private fun handleEvaluateMedia(call: MethodCall, result: MethodChannel.Result) {
        scope.launch {
            try {
                ensureModelLoaded()

                val mediaPath = call.argument<String>("mediaPath")
                    ?: return@launch result.error("INVALID_ARG", "Missing 'mediaPath'", null)
                val systemPrompt = call.argument<String>("systemPrompt") ?: ""
                val constraintFormat = call.argument<String>("constraintFormat") ?: "json"
                val maxDurationSeconds = call.argument<Int>("maxDurationSeconds") ?: 60

                val mediaFile = File(mediaPath)
                if (!mediaFile.exists()) {
                    result.error("FILE_NOT_FOUND", "Media file not found at $mediaPath", null)
                    return@launch
                }

                // Determine MIME type from extension
                val mimeType = when {
                    mediaPath.endsWith(".jpg", true) || mediaPath.endsWith(".jpeg", true) -> "image/jpeg"
                    mediaPath.endsWith(".png", true) -> "image/png"
                    mediaPath.endsWith(".mp4", true) -> "video/mp4"
                    mediaPath.endsWith(".webm", true) -> "video/webm"
                    else -> "application/octet-stream"
                }

                // Production implementation:
                //   val mediaBytes = mediaFile.readBytes()
                //   val requestBuilder = LiteRtLmRequest.Builder()
                //       .setSystemInstruction(systemPrompt)
                //       .setResponseMimeType("application/json")
                //
                //   if (mimeType.startsWith("image/")) {
                //       requestBuilder.addImagePart(mediaBytes, mimeType)
                //   } else {
                //       requestBuilder.addVideoPart(mediaBytes, mimeType, maxDurationSeconds)
                //   }
                //
                //   val response = inferenceSession!!.generateContent(requestBuilder.build())
                //   result.success(response.text)
                //
                // Bridge stub — returns a safe placeholder JSON:
                val placeholderResponse = buildPlaceholderTriageResponse(
                    inputType = if (mimeType.startsWith("image/")) "image" else "video",
                    filePath = mediaPath
                )
                Log.i(TAG, "evaluateMedia processed: $mediaPath (type=$mimeType)")
                result.success(placeholderResponse)
            } catch (e: Exception) {
                Log.e(TAG, "Failed to evaluate media", e)
                result.error("INFERENCE_ERROR", "Media evaluation failed", null)
            }
        }
    }

    // ──────────────────────────────────────────────────────────────────────────
    // Helpers
    // ──────────────────────────────────────────────────────────────────────────

    private fun ensureModelLoaded() {
        if (!isModelLoaded) {
            throw IllegalStateException("LiteRT-LM model not loaded. Call initializeModel first.")
        }
    }

    private fun isWiFiConnected(): Boolean {
        val connectivityManager = context.getSystemService(Context.CONNECTIVITY_SERVICE) as ConnectivityManager
        val network = connectivityManager.activeNetwork ?: return false
        val capabilities = connectivityManager.getNetworkCapabilities(network) ?: return false
        return capabilities.hasTransport(NetworkCapabilities.TRANSPORT_WIFI)
    }

    /**
     * Builds a safe placeholder JSON triage response for the bridge stub phase.
     * This response does NOT trigger the emergency flag (confidence = 0.0).
     * Once the LiteRT-LM SDK is fully wired, this function is replaced by real inference.
     */
    private fun buildPlaceholderTriageResponse(inputType: String, filePath: String): String {
        return """
            {
                "resourceType": "Observation",
                "status": "preliminary",
                "code": {
                    "coding": [{
                        "system": "http://loinc.org",
                        "code": "75325-1",
                        "display": "Symptom assessment"
                    }],
                    "text": "AI triage assessment (bridge stub)"
                },
                "valueString": "Bridge stub: $inputType input received from $filePath. Awaiting full LiteRT-LM inference wiring.",
                "emergency": false,
                "confidence": 0.0,
                "inputModality": "$inputType",
                "processingEngine": "LiteRT-LM/Gemma4-E2B-4bit (stub)"
            }
        """.trimIndent()
    }
}
