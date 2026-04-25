// Licensed under the Creative Commons Attribution 4.0 International License (CC-BY 4.0)
// You may obtain a copy of the License at https://creativecommons.org/licenses/by/4.0/
//
// TeleMed_K: Offline-first telemedicine app for seniors

package com.example.telemed_k.channels

import android.content.Context
import android.util.Log
import com.google.ai.edge.litertlm.Backend
import com.google.ai.edge.litertlm.Content
import com.google.ai.edge.litertlm.Contents
import com.google.ai.edge.litertlm.ConversationConfig
import com.google.ai.edge.litertlm.Engine
import com.google.ai.edge.litertlm.EngineConfig
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.flow.catch
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext
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

        // Romanian medical triage system prompt — used as default when the
        // Dart caller does not supply a custom systemPrompt.
        private val SYSTEM_PROMPT_RO = """
Ești un asistent medical AI integrat în aplicația TeleMed_K,
dedicat pacienților din zonele rurale ale României.

REGULI STRICTE:
1. Răspunzi ÎNTOTDEAUNA în limba română, indiferent de limba în care ți se vorbește.
2. Nu faci NICIODATĂ recomandări medicale, diagnostice sau prescripții.
3. Rolul tău este EXCLUSIV să colectezi simptomele descrise de pacient și
   să le prezinți medicului într-un format clar și structurat.
4. Dacă detectezi cuvinte care indică urgență (durere în piept, nu pot respira,
   leșin, accident, sângerare abundentă, pierderea conștienței) —
   setezi câmpul emergency=true în răspunsul JSON.
5. Folosești un limbaj simplu, calm și respectuos, adecvat pentru persoane
   în vârstă care nu sunt familiarizate cu tehnologia.
6. La finalul colectării simptomelor, generezi un sumar structurat pentru medic
   în format: Simptome principale / Durată / Intensitate / Context.

Răspunsul tău JSON trebuie să conțină întotdeauna:
- "response": textul afișat pacientului (în română, simplu și clar)
- "emergency": true sau false
- "confidence": număr între 0.0 și 1.0
- "doctor_summary": sumarul pentru medic (completat doar când pacientul
   a terminat de descris simptomele, altfel null)
        """.trimIndent()
    }

    private val scope = CoroutineScope(SupervisorJob() + Dispatchers.IO)

    private var engine: Engine? = null
    private var isEngineReady = false

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "isModelReady" -> result.success(isEngineReady)

            // Returns the path where the model file exists, checking two locations:
            //   1. app-private filesDir/models/ (normal install path)
            //   2. /sdcard/Download/ (sideloaded for testing)
            // Returns null if the file is absent from both locations.
            "getModelPath" -> {
                val primaryPath = File(context.filesDir, "models/gemma-4-E2B-it.litertlm").absolutePath
                val sdcardPath  = "/sdcard/Download/gemma-4-E2B-it.litertlm"
                result.success(when {
                    File(primaryPath).exists() -> primaryPath
                    File(sdcardPath).exists()  -> sdcardPath
                    else                       -> null
                })
            }

            // Both names map to the same initialisation path
            "loadModel", "initializeModel" -> handleLoadModel(call, result)

            "evaluateAudio" -> handleEvaluateAudio(call, result)

            "evaluateMedia" -> handleEvaluateMedia(call, result)

            // DownloadManager-based download is handled by ModelDownloadService;
            // this channel only receives the notification that a download was requested.
            "downloadWeights" -> result.success(null)

            "dispose" -> handleDispose(result)

            else -> result.notImplemented()
        }
    }

    // ─────────────────────────────────────────────────────────────────────────
    // Engine lifecycle
    // ─────────────────────────────────────────────────────────────────────────

    private fun handleLoadModel(call: MethodCall, result: MethodChannel.Result) {
        // Dart sends 'modelPath' for both loadModel and initializeModel
        val modelPath = call.argument<String>("modelPath")
            ?: "${context.filesDir}/models/gemma-4-E2B-it.litertlm"

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
        scope.launch {
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
                    val effectivePrompt = systemPrompt.ifBlank { SYSTEM_PROMPT_RO }
                    // Content.AudioFile(path) — documented as supported alongside AudioBytes.
                    // Using AudioFile avoids loading ~MB of audio into JVM heap.
                    runEngineInference(
                        systemPrompt = effectivePrompt,
                        contents = listOf(
                            Content.AudioFile(filePath),
                            Content.Text(effectivePrompt)
                        )
                    )
                } else {
                    Log.w(TAG, "Engine not ready — keyword fallback for audio")
                    buildFallbackResponse()
                }

                withContext(Dispatchers.Main) { result.success(response) }

            } catch (e: Exception) {
                Log.e(TAG, "Audio evaluation error", e)
                // Degrade gracefully — caller handles JSON parse
                withContext(Dispatchers.Main) { result.success(buildFallbackResponse()) }
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

                val response = if (isEngineReady && engine != null) {
                    val effectivePrompt = systemPrompt.ifBlank { SYSTEM_PROMPT_RO }

                    val isVideo = filePath.endsWith(".mp4", ignoreCase = true) ||
                                  filePath.endsWith(".webm", ignoreCase = true) ||
                                  filePath.endsWith(".mov", ignoreCase = true)

                    if (isVideo) {
                        // ⚠ UNCERTAINTY: The LiteRT-LM docs (2026-04-24) document only
                        // Content.ImageFile, Content.ImageBytes, Content.AudioFile, Content.AudioBytes.
                        // There is NO Content.VideoFile or Content.VideoBytes in the documented API.
                        // Passing a video file path to Content.ImageFile will likely throw at the
                        // native layer. Falling back to keyword heuristic for video input until
                        // the upstream API documents video support.
                        Log.w(TAG, "Video input — Content.VideoFile not in LiteRT-LM API; using fallback")
                        buildFallbackResponse()
                    } else {
                        // Image: use Content.ImageFile(path) — documented explicitly in docs §5
                        runEngineInference(
                            systemPrompt = effectivePrompt,
                            contents = listOf(
                                Content.ImageFile(filePath),
                                Content.Text(effectivePrompt)
                            )
                        )
                    }
                } else {
                    Log.w(TAG, "Engine not ready — keyword fallback for media")
                    buildFallbackResponse()
                }

                withContext(Dispatchers.Main) { result.success(response) }

            } catch (e: Exception) {
                Log.e(TAG, "Media evaluation error", e)
                withContext(Dispatchers.Main) { result.success(buildFallbackResponse()) }
            }
        }
    }

    // ─────────────────────────────────────────────────────────────────────────
    // Core inference — calls the real LiteRT-LM Engine
    // ─────────────────────────────────────────────────────────────────────────

    private suspend fun runEngineInference(
        systemPrompt: String,
        contents: List<Content>
    ): String {
        val liveEngine = checkNotNull(engine) { "Engine is null inside runEngineInference" }

        val conversationConfig = ConversationConfig(
            systemInstruction = Contents.of(systemPrompt),
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
            Log.d(TAG, "Engine response: ${raw.take(120)}…")

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
                if (!obj.has("response")) obj.put("response", raw)
                return obj.toString()
            } catch (_: Exception) { /* fall through to prose path */ }
        }

        // Prose path — use keyword heuristic to set emergency flag
        val isUrgent = detectEmergencyKeywords(raw)
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

    /** Returned when engine is unavailable — app stays functional, no crash. */
    private fun buildFallbackResponse(): String = JSONObject().apply {
        put("emergency", false)
        put("confidence", 0.0)
        put("response",
            "Sistemul AI nu este disponibil momentan. Vă rugăm descrieți simptomele medicului.")
        put("fallback", true)
    }.toString()
}
