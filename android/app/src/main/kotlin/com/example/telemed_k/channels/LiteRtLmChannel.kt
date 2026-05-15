// Licensed under the Creative Commons Attribution 4.0 International License (CC-BY 4.0)
// You may obtain a copy of the License at https://creativecommons.org/licenses/by/4.0/
//
// TeleMed_K: Offline-first telemedicine app for seniors

package com.example.telemed_k.channels

import android.content.Context
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.os.Environment
import android.util.Log
import java.time.Instant
import com.google.ai.edge.litertlm.Backend
import com.google.ai.edge.litertlm.Content
import com.google.ai.edge.litertlm.Contents
import com.google.ai.edge.litertlm.ConversationConfig
import com.google.ai.edge.litertlm.SamplerConfig
import com.google.ai.edge.litertlm.Engine
import com.google.ai.edge.litertlm.EngineConfig
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import kotlinx.coroutines.cancel
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.async
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.TimeoutCancellationException
import kotlinx.coroutines.flow.catch
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext
import kotlinx.coroutines.withTimeout
import org.json.JSONObject
import java.io.File

/**
 * LiteRT-LM MethodChannel handler — Gemma 4 E2B on-device inference.
 *
 * Bridges Flutter ↔ com.google.ai.edge.litertlm:litertlm-android.
 * All inference runs on Dispatchers.IO — engine.initialize() blocks up to 10 s.
 *
 * Method contract (matches Dart AiEngineService exactly):
 *   evaluateAudio  — audio file path + system prompt → JSON string
 *   evaluateMedia  — image/video file path + system prompt → JSON string
 *   isModelReady   — returns Boolean
 *   loadModel      — takes 'modelPath' String, initialises Engine
 *   initializeModel — alias of loadModel (legacy Dart compat)
 *   dispose        — closes Engine, frees memory
 *   downloadWeights — no-op stub; actual download handled by ModelDownloadService
 */
class LiteRtLmChannel(private val context: Context) : MethodChannel.MethodCallHandler {

    companion object {
        const val CHANNEL_NAME = "com.telemed_k/litert_lm"
        private const val TAG = "LiteRtLmChannel"
        private const val CONFIDENCE_URGENT = 0.85
        private const val CONFIDENCE_BENIGN = 0.45

        private val EMERGENCY_KEYWORDS_RO = listOf(
            "durere", "piept", "respirat", "amețeală", "leșin",
            "infarct", "accident vascular", "stop cardiac", "paralizie",
            "sânger", "convulsii", "inconștient"
        )


        // Active language code — "en" (default) or "ro".
        // Written by the setLanguage MethodChannel call.
        // Dart passes its own system prompt via the systemPrompt argument.
        @Volatile var currentLanguage = "en"
    }

    private val scope = CoroutineScope(SupervisorJob() + Dispatchers.IO)

    private var engine: Engine? = null
    private var isEngineReady = false

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "isModelReady"   -> result.success(isEngineReady)

            // Returns true only when both the engine reference and ready flag are valid.
            // Dart uses this to detect Kotlin/Dart state divergence after an engine crash.
            "isEngineReady"  -> result.success(isEngineReady && engine != null)

            // Returns the path where the model file exists, checking three locations:
            //   1. Android files dir (context.filesDir/models/) — DownloadManager destination
            //   2. Flutter documents dir (app_flutter/models/) — path_provider destination
            //   3. sdcard Downloads — sideloaded for testing
            // Returns null if absent from all locations.
            "getModelPath" -> {
                // Model filename must match ai_engine_service.dart _modelFileName constant.
                // Keep in sync manually — no single source of truth at build time.
                val fileName = "gemma-4-E4B-it.litertlm"

                val filesPath   = context.filesDir.absolutePath + "/models/$fileName"
                val flutterPath = context.filesDir.parent + "/app_flutter/models/$fileName"
                val sdcardPath  = Environment.getExternalStoragePublicDirectory(
                    Environment.DIRECTORY_DOWNLOADS).absolutePath + "/$fileName"

                Log.d(TAG, "Checking filesPath:   $filesPath  exists=${File(filesPath).exists()}")
                Log.d(TAG, "Checking flutterPath: $flutterPath  exists=${File(flutterPath).exists()}")
                Log.d(TAG, "Checking sdcardPath:  $sdcardPath  canRead=${File(sdcardPath).canRead()}")

                val foundPath = when {
                    File(filesPath).exists()   -> filesPath
                    File(flutterPath).exists() -> flutterPath
                    File(sdcardPath).canRead() -> sdcardPath
                    else                       -> null
                }

                Log.d(TAG, "getModelPath returning: $foundPath")
                result.success(foundPath)
            }

            // Both names map to the same initialisation path
            "loadModel", "initializeModel" -> handleLoadModel(call, result)

            "evaluateAudio" -> handleEvaluateAudio(call, result)

            "evaluateMedia" -> handleEvaluateMedia(call, result)

            // DownloadManager-based download is handled by ModelDownloadService;
            // this channel only receives the notification that a download was requested.
            "downloadWeights" -> result.success(null)

            "dispose" -> handleDispose(result)

            "runInference" -> handleRunInference(call, result)

            "setLanguage" -> {
                val lang = call.argument<String>("lang") ?: "ro"
                currentLanguage = lang
                Log.i(TAG, "Language set to: $lang")
                result.success(null)
            }

            "appendDebugLog" -> {
                val line = call.argument<String>("line") ?: ""
                try {
                    java.io.File(context.getExternalFilesDir(null), "telemed-ai-debug.jsonl")
                        .appendText(line + "\n")
                } catch (_: Exception) {}
                result.success(null)
            }

            "readDebugLog" -> {
                val maxBytes = call.argument<Int>("maxBytes") ?: 50000
                try {
                    val f = java.io.File(context.getExternalFilesDir(null), "telemed-ai-debug.jsonl")
                    if (f.exists()) {
                        val bytes = f.readBytes()
                        val slice = if (bytes.size > maxBytes)
                            bytes.sliceArray(bytes.size - maxBytes until bytes.size)
                        else bytes
                        result.success(String(slice))
                    } else result.success(null)
                } catch (_: Exception) { result.success(null) }
            }

            else -> result.notImplemented()
        }
    }

    // ─────────────────────────────────────────────────────────────────────────
    // Engine lifecycle
    // ─────────────────────────────────────────────────────────────────────────

    private fun handleLoadModel(call: MethodCall, result: MethodChannel.Result) {
        // Dart sends 'modelPath' for both loadModel and initializeModel
        val modelPath = call.argument<String>("modelPath")
            ?: "${context.filesDir}/models/gemma-4-E4B-it.litertlm"

        scope.launch {
            try {
                // Tear down any prior engine before re-initialising
                engine?.close()
                engine = null
                isEngineReady = false

                val modelFile = File(modelPath)
                if (!modelFile.exists()) {
                    withContext(Dispatchers.Main) {
                        result.error(
                            "MODEL_NOT_FOUND",
                            "Model not found at $modelPath — call downloadWeights first.",
                            null
                        )
                    }
                    return@launch
                }

                // engine.initialize() may block up to 10 s — always run on IO
                val cfg = EngineConfig(
                    modelPath = modelPath,
                    backend = Backend.CPU(),
                    // Enable vision and audio backends for Gemma 4 multimodal support.
                    // Using CPU for both; GPU would require libvndksupport.so / libOpenCL.so
                    // declared in the manifest (not added yet — see docs §2).
                    visionBackend = Backend.CPU(),
                    audioBackend = Backend.CPU(),
                )
                val newEngine = Engine(cfg)
                newEngine.initialize()

                engine = newEngine
                isEngineReady = true
                Log.i(TAG, "Engine ready — model: $modelPath (${modelFile.length() / (1024 * 1024)} MB)")
                withContext(Dispatchers.Main) { result.success(null) }

            } catch (e: Exception) {
                Log.e(TAG, "Engine init failed", e)
                withContext(Dispatchers.Main) {
                    result.error("ENGINE_INIT_ERROR", e.message, null)
                }
            }
        }
    }

    private fun handleDispose(result: MethodChannel.Result) {
        scope.cancel() // cancel all in-flight inference coroutines
        // Use a fresh scope for the engine cleanup so it runs even after scope is cancelled.
        CoroutineScope(SupervisorJob() + Dispatchers.IO).launch {
            try {
                engine?.close()
                engine = null
                isEngineReady = false
                Log.i(TAG, "Engine disposed")
            } catch (e: Exception) {
                Log.w(TAG, "Dispose error (non-fatal)", e)
            } finally {
                withContext(Dispatchers.Main) { result.success(null) }
            }
        }
    }

    // ─────────────────────────────────────────────────────────────────────────
    // Audio evaluation
    // ─────────────────────────────────────────────────────────────────────────

    private fun handleEvaluateAudio(call: MethodCall, result: MethodChannel.Result) {
        // Dart sends key 'audioPath'; spec also allows 'filePath' — accept both
        val filePath = call.argument<String>("audioPath")
            ?: call.argument<String>("filePath")
        val systemPrompt = call.argument<String>("systemPrompt") ?: ""
        val conversationContext = call.argument<String>("text") ?: ""

        if (filePath == null) {
            result.error("INVALID_ARG", "Missing key 'audioPath' or 'filePath'", null)
            return
        }

        scope.launch {
            try {
                val audioFile = File(filePath)
                if (!audioFile.exists()) {
                    withContext(Dispatchers.Main) {
                        result.error("FILE_NOT_FOUND", "Audio file not found: $filePath", null)
                    }
                    return@launch
                }

                val response = if (isEngineReady && engine != null) {
                    Log.d(TAG, "New conversation created — evaluateAudio session isolated")
                    // Use the Dart-provided system prompt directly; it already contains the
                    // full structured prompt built by AiEngineService.buildSystemPrompt().
                    // Prepending buildSystemPrompt() here would send two conflicting language
                    // instructions and cause the model to respond in the wrong language.
                    val effectivePrompt = systemPrompt
                    // Content.AudioFile(path) — documented as supported alongside AudioBytes.
                    // Using AudioFile avoids loading ~MB of audio into JVM heap.
                    // Pass conversation history as second content item if available;
                    // otherwise send audio alone (system prompt is the instruction).
                    val audioContents = if (conversationContext.isNotEmpty()) {
                        listOf(Content.AudioFile(filePath), Content.Text(conversationContext))
                    } else {
                        listOf(Content.AudioFile(filePath))
                    }
                    runEngineInference(
                        systemPrompt = effectivePrompt,
                        contents = audioContents,
                        method = "audio"
                    )
                } else {
                    Log.w(TAG, "Engine not ready — keyword fallback for audio")
                    buildFallbackResponse("engine not initialized — audio")
                }

                withContext(Dispatchers.Main) { result.success(response) }

            } catch (e: Exception) {
                Log.e(TAG, "Audio evaluation error", e)
                withContext(Dispatchers.Main) { result.success(buildFallbackResponse("exception during audio: ${e.message}")) }
            }
        }
    }

    // ─────────────────────────────────────────────────────────────────────────
    // Media evaluation (image / video)
    // ─────────────────────────────────────────────────────────────────────────

    private fun handleEvaluateMedia(call: MethodCall, result: MethodChannel.Result) {
        // Dart sends key 'mediaPath'; spec also allows 'filePath' — accept both
        val filePath = call.argument<String>("mediaPath")
            ?: call.argument<String>("filePath")
        val systemPrompt = call.argument<String>("systemPrompt") ?: ""
        val conversationContext = call.argument<String>("text") ?: ""

        if (filePath == null) {
            result.error("INVALID_ARG", "Missing key 'mediaPath' or 'filePath'", null)
            return
        }

        scope.launch {
            try {
                val mediaFile = File(filePath)
                if (!mediaFile.exists()) {
                    withContext(Dispatchers.Main) {
                        result.error("FILE_NOT_FOUND", "Media file not found: $filePath", null)
                    }
                    return@launch
                }

                // Pre-compute video flag here so it can be used both for validation
                // and inside the response expression below without re-evaluation.
                val isVideo = filePath.endsWith(".mp4", ignoreCase = true) ||
                              filePath.endsWith(".webm", ignoreCase = true) ||
                              filePath.endsWith(".mov", ignoreCase = true)

                // Validate image file before passing its path to the native LiteRT-LM
                // layer. The native layer SIGSEGVs on corrupt, empty, or non-JPEG inputs.
                if (!isVideo) {
                    val ext = filePath.substringAfterLast('.', "").lowercase()
                    if (mediaFile.length() <= 0L || !mediaFile.canRead() ||
                        (ext != "jpg" && ext != "jpeg")) {
                        Log.e(TAG, "IMAGE_INVALID — file=$filePath ext=$ext " +
                            "size=${mediaFile.length()} canRead=${mediaFile.canRead()}")
                        withContext(Dispatchers.Main) {
                            result.error("IMAGE_INVALID",
                                "Image file invalid or unreadable: $filePath", null)
                        }
                        return@launch
                    }
                }

                var imageInferenceError: Exception? = null
                val response = if (isEngineReady && engine != null) {
                    Log.d(TAG, "New conversation created — evaluateMedia session isolated")
                    // Use the Dart-provided system prompt directly (same reason as evaluateAudio).
                    val effectivePrompt = systemPrompt

                    if (isVideo) {
                        // ⚠ UNCERTAINTY: The LiteRT-LM docs (2026-04-24) document only
                        // Content.ImageFile, Content.ImageBytes, Content.AudioFile, Content.AudioBytes.
                        // There is NO Content.VideoFile or Content.VideoBytes in the documented API.
                        // Passing a video file path to Content.ImageFile will likely throw at the
                        // native layer. Falling back to keyword heuristic for video input until
                        // the upstream API documents video support.
                        Log.w(TAG, "Video input — Content.VideoFile not in LiteRT-LM API; using fallback")
                        buildFallbackResponse("video input not supported by LiteRT-LM API")
                    } else {
                        // Image: 60-second timeout using scope.async so the native JNI call
                        // runs as an independent Job under scope — NOT as a child of the
                        // timeout scope. withTimeout(60_000L) only cancels the await(); it
                        // never cancels the native sendMessageAsync() call itself. The
                        // abandoned native call completes silently on the IO thread pool.
                        // Preprocess: resize to max 1024px to avoid OOM / token-budget
                        // overflow on high-resolution camera output (Pixel 9 Pro = 50MP).
                        val inferPath = preprocessImageForInference(filePath)
                        // Pass conversation history as second content item if available;
                        // otherwise send image alone (system prompt is the instruction).
                        val imageContents = if (conversationContext.isNotEmpty()) {
                            listOf(Content.ImageFile(inferPath), Content.Text(conversationContext))
                        } else {
                            listOf(Content.ImageFile(inferPath))
                        }
                        val inferenceDeferred = scope.async(Dispatchers.IO) {
                            runEngineInference(
                                systemPrompt = effectivePrompt,
                                contents = imageContents,
                                method = "media"
                            )
                        }
                        try {
                            withTimeout(60_000L) {
                                inferenceDeferred.await()
                            }
                        } catch (e: TimeoutCancellationException) {
                            Log.w(TAG, "Photo analysis timed out — result will be discarded when native call completes")
                            inferenceDeferred.invokeOnCompletion { }
                            buildPhotoTimeoutFallback()
                        } catch (e: Exception) {
                            Log.e(TAG, "Image inference error", e)
                            imageInferenceError = e
                            null
                        }
                    }
                } else {
                    Log.w(TAG, "Engine not ready — keyword fallback for media")
                    buildFallbackResponse("engine not initialized — media")
                }

                val imgErr = imageInferenceError
                if (imgErr != null) {
                    withContext(Dispatchers.Main) {
                        result.error("IMAGE_INFERENCE_ERROR", imgErr.message ?: imgErr.toString(), null)
                    }
                    return@launch
                }
                withContext(Dispatchers.Main) { result.success(response!!) }

            } catch (e: Exception) {
                Log.e(TAG, "Media evaluation error", e)
                withContext(Dispatchers.Main) { result.success(buildFallbackResponse("exception during media: ${e.message}")) }
            }
        }
    }

    // ─────────────────────────────────────────────────────────────────────────
    // Text inference
    // ─────────────────────────────────────────────────────────────────────────

    private fun handleRunInference(call: MethodCall, result: MethodChannel.Result) {
        val text = call.argument<String>("text") ?: ""
        val systemPrompt = call.argument<String>("systemPrompt") ?: ""

        scope.launch {
            try {
                val response = if (isEngineReady && engine != null) {
                    Log.d(TAG, "New conversation created — handleRunInference session isolated")
                    // Use the Dart-provided system prompt directly (same reason as evaluateAudio).
                    val effectivePrompt = systemPrompt
                    // effectivePrompt is already set as systemInstruction in ConversationConfig
                    // inside runEngineInference(). Pass only the user turn as content.
                    runEngineInference(
                        systemPrompt = effectivePrompt,
                        contents = listOf(Content.Text(text)),
                        method = "text"
                    )
                } else {
                    Log.w(TAG, "Engine not ready — keyword fallback for text")
                    buildFallbackResponse("engine not initialized — text")
                }
                withContext(Dispatchers.Main) { result.success(response) }
            } catch (e: Exception) {
                Log.e(TAG, "Text inference error", e)
                withContext(Dispatchers.Main) { result.success(buildFallbackResponse("exception during text: ${e.message}")) }
            }
        }
    }

    // ─────────────────────────────────────────────────────────────────────────
    // Core inference — calls the real LiteRT-LM Engine
    // ─────────────────────────────────────────────────────────────────────────

    private suspend fun runEngineInference(
        systemPrompt: String,
        contents: List<Content>,
        method: String = "text"
    ): String {
        val startMs = System.currentTimeMillis()
        val inputLen = contents.sumOf { it.toString().length }
        val liveEngine = checkNotNull(engine) { "Engine is null inside runEngineInference" }

        // Sampling parameters: low temperature for instruction-following discipline
        // (JSON output, 5-question limit, response length). topK=40 is the standard
        // Gemma default; the API requires it as a positional arg (no library default).
        // seed omitted — defaults to 0 (random, no fixed seed needed for demo).
        val samplerConfig = SamplerConfig(
            topK = 40,
            topP = 0.9,
            temperature = 0.3,
        )
        Log.d(TAG, "Sampling config: temperature=0.3 topP=0.9 topK=40")
        val conversationConfig = ConversationConfig(
            systemInstruction = Contents.of(systemPrompt),
            samplerConfig = samplerConfig,
        )

        return liveEngine.createConversation(conversationConfig).use { conversation ->
            val sb = StringBuilder()

            // sendMessageAsync returns Flow<Message>; each emission is a streaming token.
            // Accumulate all tokens into a single string, then parse.
            conversation.sendMessageAsync(Contents.of(*contents.toTypedArray()))
                .catch { e -> Log.e(TAG, "Inference stream error", e) }
                .collect { message ->
                    // Message has no .text property — toString() delegates to
                    // contents.toString() which joins all Content.Text tokens.
                    sb.append(message.toString())
                }

            val raw = sb.toString().trim()
            val elapsedMs = System.currentTimeMillis() - startMs
            Log.d(TAG, "Engine response: ${raw.take(120)}…")

            // Part B: append one JSONL line to on-device debug log.
            appendDebugLogEntry(method, inputLen, systemPrompt.length, raw.length, elapsedMs, null)

            coerceToJsonSchema(raw)
        }
    }

    // ─────────────────────────────────────────────────────────────────────────
    // Response normalisation
    // ─────────────────────────────────────────────────────────────────────────

    /**
     * If the model returned valid JSON with the expected keys, pass it through.
     * If it returned prose (e.g. the model ignored the JSON instruction), detect
     * emergency keywords and wrap into the schema.
     */
    private fun coerceToJsonSchema(raw: String): String {
        // Try to extract a JSON object from the response (model may prefix/suffix prose)
        val jsonStart = raw.indexOf('{')
        val jsonEnd = raw.lastIndexOf('}')
        if (jsonStart != -1 && jsonEnd > jsonStart) {
            val candidate = raw.substring(jsonStart, jsonEnd + 1)
            try {
                val obj = JSONObject(candidate)
                // Ensure required keys are present; fill missing ones
                if (!obj.has("emergency")) obj.put("emergency", false)
                if (!obj.has("confidence")) obj.put("confidence", CONFIDENCE_BENIGN)
                if (!obj.has("response")) {
                    // Extract prose that the model wrote OUTSIDE the JSON block.
                    // Passing raw directly would put the full JSON-blob string into
                    // the response field; _cleanText() on the Dart side would then
                    // try to re-parse it as JSON, find no human-readable key, and
                    // discard the content — triggering the "Răspuns primit" fallback.
                    val proseBefore = raw.take(jsonStart).trim()
                    val proseAfter  = raw.drop(jsonEnd + 1).trim()
                    val outsideProse = listOf(proseBefore, proseAfter)
                        .filter { it.isNotEmpty() }.joinToString(" ")
                    if (outsideProse.isNotEmpty()) {
                        Log.d(TAG, "coerceToJsonSchema: response field absent — using prose outside JSON block")
                    } else {
                        Log.d(TAG, "coerceToJsonSchema: response field absent and no outside prose — response will be empty")
                    }
                    obj.put("response", outsideProse)
                }
                return obj.toString()
            } catch (_: Exception) { /* fall through to prose path */ }
        }

        // Prose path — model returned conversational text with no JSON wrapper.
        // Pass it through directly; this is expected behaviour for the a/b/c acknowledgment prompt.
        // Filter the empty-list artifact "[]" / "[ ]" that LiteRT-LM emits on some turns;
        // treat it as blank so the ifBlank branch returns the Romanian placeholder below.
        @Suppress("NAME_SHADOWING")
        val raw = if (raw.trim() == "[]" || raw.trim() == "[ ]") "" else raw
        val isUrgent = detectEmergencyKeywords(raw)
        if (raw.isBlank()) {
            Log.d(TAG, "coerceToJsonSchema: model returned blank response — using placeholder")
        } else {
            Log.d(TAG, "coerceToJsonSchema: prose path — passing model text as response (${raw.length} chars)")
        }
        return JSONObject().apply {
            put("emergency", isUrgent)
            put("confidence", if (isUrgent) CONFIDENCE_URGENT else CONFIDENCE_BENIGN)
            put("response", raw.ifBlank { "Răspuns indisponibil." })
        }.toString()
    }

    private fun detectEmergencyKeywords(text: String): Boolean {
        val lower = text.lowercase()
        return EMERGENCY_KEYWORDS_RO.any { lower.contains(it) }
    }

    /** Returned when photo analysis exceeds the 60-second timeout. */
    private fun buildPhotoTimeoutFallback(): String = JSONObject().apply {
        put("emergency", false)
        put("confidence", 0.0)
        put("response",
            "Nu am putut analiza fotografia. Vă rugăm descrieți simptomele prin voce sau text.")
        put("fallback", true)
    }.toString()

    /** Returned when engine is unavailable — app stays functional, no crash. */
    private fun buildFallbackResponse(reason: String = "unspecified"): String {
        Log.d(TAG, "Fallback response returned — $reason")
        return JSONObject().apply {
            put("emergency", false)
            put("confidence", 0.0)
            put("response",
                "Sistemul AI nu este disponibil momentan. Vă rugăm descrieți simptomele medicului.")
            put("fallback", true)
        }.toString()
    }

    /** Appends one JSONL line to the on-device debug log. Silent on failure. */
    private fun appendDebugLogEntry(
        method: String, inputLen: Int, sysPromptLen: Int,
        rawOutputLen: Int, elapsedMs: Long, error: String?
    ) {
        try {
            val ts = Instant.now().toString()
            val errorJson = if (error != null) "\"${error.replace("\"", "\\\"")}\"" else "null"
            val line = """{"ts":"$ts","method":"$method","inputLen":$inputLen,"sysPromptLen":$sysPromptLen,"samplingApplied":{"temperature":0.3,"topP":0.9,"topK":40},"rawOutputLen":$rawOutputLen,"elapsedMs":$elapsedMs,"error":$errorJson}"""
            java.io.File(context.getExternalFilesDir(null), "telemed-ai-debug.jsonl")
                .appendText(line + "\n")
        } catch (_: Exception) {
            // Diagnostic write failure must not affect inference.
        }
    }

    /**
     * Resizes a JPEG image so its longest side is at most MAX_INFER_DIM pixels,
     * then saves the result to the app cache directory.
     *
     * High-resolution camera images (Pixel 9 Pro = 50MP) exceed the LiteRT-LM
     * vision encoder's effective token budget and cause IMAGE_INFERENCE_ERROR.
     * Constraining to 1024px largest side keeps the payload manageable.
     *
     * Returns the path of the processed file (may equal [sourcePath] if the
     * image is already within bounds or if decoding fails).
     */
    private fun preprocessImageForInference(sourcePath: String): String {
        val MAX_DIM = 1024
        try {
            // Decode bounds first (no pixel allocation).
            val bounds = BitmapFactory.Options().apply { inJustDecodeBounds = true }
            BitmapFactory.decodeFile(sourcePath, bounds)
            val origW = bounds.outWidth
            val origH = bounds.outHeight

            // Log actual image dimensions — always-on for diagnosis; remove post-hackathon.
            val sourceFile = File(sourcePath)
            Log.d(TAG, "Image for inference: ${sourceFile.length() / 1024}KB ${origW}x${origH} path=$sourcePath")

            if (origW <= 0 || origH <= 0) {
                Log.w(TAG, "preprocessImageForInference: invalid bounds ($origW x $origH) — using original")
                return sourcePath
            }

            if (origW <= MAX_DIM && origH <= MAX_DIM) {
                // Already within limits — pass original path directly.
                Log.d(TAG, "Image within ${MAX_DIM}px limit — no resize needed")
                return sourcePath
            }

            // Use inSampleSize for a fast first-pass decode before fine-scaling.
            val longestSide = maxOf(origW, origH)
            val sampleSize = maxOf(1, Integer.highestOneBit(longestSide / MAX_DIM))
            val decodeOpts = BitmapFactory.Options().apply { inSampleSize = sampleSize }
            val raw = BitmapFactory.decodeFile(sourcePath, decodeOpts)
                ?: run {
                    Log.w(TAG, "preprocessImageForInference: BitmapFactory.decodeFile returned null — using original")
                    return sourcePath
                }

            // Fine-scale to exact MAX_DIM on the longest side.
            val scale = MAX_DIM.toFloat() / maxOf(raw.width, raw.height).toFloat()
            val targetW = (raw.width * scale).toInt().coerceAtLeast(1)
            val targetH = (raw.height * scale).toInt().coerceAtLeast(1)
            val scaled = Bitmap.createScaledBitmap(raw, targetW, targetH, true)
            raw.recycle()

            Log.d(TAG, "Image resized: ${origW}x${origH} → ${scaled.width}x${scaled.height}")

            // Save resized image to app cache dir as JPEG.
            val destFile = File(context.cacheDir, "telemed_infer_${System.currentTimeMillis()}.jpg")
            destFile.outputStream().use { fos ->
                scaled.compress(Bitmap.CompressFormat.JPEG, 85, fos)
            }
            scaled.recycle()

            Log.d(TAG, "Preprocessed image saved: ${destFile.length() / 1024}KB → ${destFile.absolutePath}")
            return destFile.absolutePath

        } catch (e: Exception) {
            Log.e(TAG, "preprocessImageForInference error — using original path", e)
            return sourcePath
        }
    }
}
