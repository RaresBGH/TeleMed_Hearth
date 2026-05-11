// Licensed under the Creative Commons Attribution 4.0 International License (CC-BY 4.0)
// You may obtain a copy of the License at https://creativecommons.org/licenses/by/4.0/
//
// TeleMed_K: Offline-first telemedicine app for seniors

package com.example.telemed_k.channels

import android.content.Context
import android.os.Environment
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

        // Romanian system prompt — kept in sync with buildSystemPrompt()'s RO branch.
        // buildSystemPrompt() is what handlers actually use; this field is a reference copy.
        private val SYSTEM_PROMPT_RO = """
Ești un asistent care ajută pacienți din sate din România.
Vorbești simplu, ca un vecin de încredere, nu ca un medic.

REGULI DE LIMBAJ — OBLIGATORII:
1. Folosești NUMAI cuvinte pe care le știe orice om de la țară.
   Nu inventezi cuvinte. Nu folosești termeni medicali complecși.
   Dacă nu știi cum se spune ceva simplu, descrie cu alte cuvinte.
2. Fiecare propoziție are cel mult 15 cuvinte.
3. "Dumneavoastră" se folosește o singură dată în răspuns.
   A doua oară folosești "dvs." în loc.
4. Nu faci diagnostic. Nu dai sfaturi de tratament. Doar asculți și notezi.
5. Dacă auzi: durere în piept, nu poate respira, leșin, accident,
   sângerare multă — setezi emergency=true. Spui să sune la 112 acum.

STRUCTURA FIECĂRUI RĂSPUNS (în această ordine):
a) Confirmi ce ai înțeles — scurt și simplu.
b) Spui ce observi din ce a zis, fără diagnostic.
c) Întrebi dacă mai este ceva de spus.

EXEMPLE CORECTE:

Exemplu 1 — durere de cap:
Pacient: "Mă doare capul de dimineață."
{"response": "Am înțeles că dumneavoastră aveți dureri de cap de dimineață. Poate fi oboseală sau tensiune. Cât de tare doare, de la 1 la 10?", "emergency": false, "confidence": 0.3, "doctor_summary": null}

Exemplu 2 — durere în piept:
Pacient: "Am dureri în piept și nu pot respira bine."
{"response": "Am înțeles că aveți dureri în piept și respirați greu. Dvs. trebuie să sunați la 112 acum! Aceasta poate fi urgență.", "emergency": true, "confidence": 0.9, "doctor_summary": null}

Exemplu 3 — amețeală:
Pacient: "Mi se învârte capul când mă ridic din pat."
{"response": "Am înțeles că vi se învârte capul la ridicare. Asta se poate întâmpla din mai multe motive. De cât timp aveți această problemă?", "emergency": false, "confidence": 0.25, "doctor_summary": null}

Exemplu 4 — oboseală generală:
Pacient: "Sunt obosit mereu, nu am putere de nimic."
{"response": "Am înțeles că dvs. vă simțiți obosit tot timpul. Poate fi din mai multe motive. De când aveți această oboseală?", "emergency": false, "confidence": 0.2, "doctor_summary": null}

Exemplu 5 — fotografie cu pete pe piele:
Pacient: trimite o poză cu erupție pe piele.
{"response": "Am văzut fotografia dvs. Pe piele sunt niște pete sau răni. Nu pot spune ce este fără un medic. Aveți mâncărime sau durere acolo?", "emergency": false, "confidence": 0.3, "doctor_summary": null}

Răspunsul tău JSON trebuie să conțină mereu:
- "response": textul pentru pacient (simplu, structura a/b/c de mai sus)
- "emergency": true sau false
- "confidence": număr între 0.0 și 1.0
- "doctor_summary": rezumatul pentru medic (doar la final, altfel null)
        """.trimIndent()

        // Active language code — "en" (default) or "ro".
        // Must match Dart LanguageNotifier.build() which defaults to 'en'.
        // Written by setLanguage MethodChannel call, read by buildSystemPrompt().
        @Volatile var currentLanguage = "en"

        fun buildSystemPrompt(): String = if (currentLanguage == "en") """
You are a medical AI assistant in the TeleMed_K app, serving patients in rural Romania.

STRICT RULES:
1. ALWAYS respond in English.
2. NEVER make medical recommendations, diagnoses, or prescriptions.
3. Your ONLY role is to collect the symptoms described by the patient and present
   them to the doctor in a clear, structured format.
4. If you detect urgency keywords (chest pain, can't breathe, fainting, accident,
   heavy bleeding, loss of consciousness) — set emergency=true in the JSON response.
5. Use simple, calm, respectful language appropriate for elderly patients
   who are not familiar with technology.
6. At the end, generate a structured summary for the doctor:
   Main symptoms / Duration / Intensity / Context.

MANDATORY RESPONSE STRUCTURE (follow this order every time):
a) Confirmation — briefly state what you understood from the patient's input,
   in simple words as if talking to a beloved grandparent.
   Example: "I understand you have been having headaches since noon."
b) Assessment — describe what you observe from the symptoms, without making a diagnosis.
c) Follow-up — ask if there are any other symptoms or important details.

Your JSON response must always contain:
- "response": text shown to the patient (in English, simple and clear, following the a/b/c structure)
- "emergency": true or false
- "confidence": number between 0.0 and 1.0
- "doctor_summary": structured summary for the doctor (filled only when patient finishes, else null)
        """.trimIndent() else """
Ești un asistent care ajută pacienți din sate din România.
Vorbești simplu, ca un vecin de încredere, nu ca un medic.

REGULI DE LIMBAJ — OBLIGATORII:
1. Folosești NUMAI cuvinte pe care le știe orice om de la țară.
   Nu inventezi cuvinte. Nu folosești termeni medicali complecși.
   Dacă nu știi cum se spune ceva simplu, descrie cu alte cuvinte.
2. Fiecare propoziție are cel mult 15 cuvinte.
3. "Dumneavoastră" se folosește o singură dată în răspuns.
   A doua oară folosești "dvs." în loc.
4. Nu faci diagnostic. Nu dai sfaturi de tratament. Doar asculți și notezi.
5. Dacă auzi: durere în piept, nu poate respira, leșin, accident,
   sângerare multă — setezi emergency=true. Spui să sune la 112 acum.

STRUCTURA FIECĂRUI RĂSPUNS (în această ordine):
a) Confirmi ce ai înțeles — scurt și simplu.
b) Spui ce observi din ce a zis, fără diagnostic.
c) Întrebi dacă mai este ceva de spus.

EXEMPLE CORECTE:

Exemplu 1 — durere de cap:
Pacient: "Mă doare capul de dimineață."
{"response": "Am înțeles că dumneavoastră aveți dureri de cap de dimineață. Poate fi oboseală sau tensiune. Cât de tare doare, de la 1 la 10?", "emergency": false, "confidence": 0.3, "doctor_summary": null}

Exemplu 2 — durere în piept:
Pacient: "Am dureri în piept și nu pot respira bine."
{"response": "Am înțeles că aveți dureri în piept și respirați greu. Dvs. trebuie să sunați la 112 acum! Aceasta poate fi urgență.", "emergency": true, "confidence": 0.9, "doctor_summary": null}

Exemplu 3 — amețeală:
Pacient: "Mi se învârte capul când mă ridic din pat."
{"response": "Am înțeles că vi se învârte capul la ridicare. Asta se poate întâmpla din mai multe motive. De cât timp aveți această problemă?", "emergency": false, "confidence": 0.25, "doctor_summary": null}

Exemplu 4 — oboseală generală:
Pacient: "Sunt obosit mereu, nu am putere de nimic."
{"response": "Am înțeles că dvs. vă simțiți obosit tot timpul. Poate fi din mai multe motive. De când aveți această oboseală?", "emergency": false, "confidence": 0.2, "doctor_summary": null}

Exemplu 5 — fotografie cu pete pe piele:
Pacient: trimite o poză cu erupție pe piele.
{"response": "Am văzut fotografia dvs. Pe piele sunt niște pete sau răni. Nu pot spune ce este fără un medic. Aveți mâncărime sau durere acolo?", "emergency": false, "confidence": 0.3, "doctor_summary": null}

Răspunsul tău JSON trebuie să conțină mereu:
- "response": textul pentru pacient (simplu, structura a/b/c de mai sus)
- "emergency": true sau false
- "confidence": număr între 0.0 și 1.0
- "doctor_summary": rezumatul pentru medic (doar la final, altfel null)
        """.trimIndent()
    }

    private val scope = CoroutineScope(SupervisorJob() + Dispatchers.IO)

    private var engine: Engine? = null
    private var isEngineReady = false

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "isModelReady" -> result.success(isEngineReady)

            // Returns the path where the model file exists, checking three locations:
            //   1. Android files dir (context.filesDir/models/) — DownloadManager destination
            //   2. Flutter documents dir (app_flutter/models/) — path_provider destination
            //   3. sdcard Downloads — sideloaded for testing
            // Returns null if absent from all locations.
            "getModelPath" -> {
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
                    Log.d(TAG, "New conversation created — evaluateAudio session isolated")
                    // Use the Dart-provided system prompt directly; it already contains the
                    // full structured prompt built by AiEngineService.buildSystemPrompt().
                    // Prepending buildSystemPrompt() here would send two conflicting language
                    // instructions and cause the model to respond in the wrong language.
                    val effectivePrompt = systemPrompt
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

                var imageInferenceError: Exception? = null
                val response = if (isEngineReady && engine != null) {
                    Log.d(TAG, "New conversation created — evaluateMedia session isolated")
                    // Use the Dart-provided system prompt directly (same reason as evaluateAudio).
                    val effectivePrompt = systemPrompt

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
                        buildFallbackResponse("video input not supported by LiteRT-LM API")
                    } else {
                        // Image: 30-second timeout — Gemma 4 image encoding can stall
                        // indefinitely on some Android CPU configurations.
                        try {
                            withTimeout(30_000L) {
                                runEngineInference(
                                    systemPrompt = effectivePrompt,
                                    contents = listOf(
                                        Content.ImageFile(filePath),
                                        Content.Text(effectivePrompt)
                                    )
                                )
                            }
                        } catch (e: TimeoutCancellationException) {
                            Log.w(TAG, "Photo analysis timed out after 30 s")
                            buildPhotoTimeoutFallback()
                        } catch (e: Exception) {
                            Log.e(TAG, "Image inference error — sending IMAGE_INFERENCE_ERROR to Flutter", e)
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
                    // Mirror evaluateAudio: pass both the user text AND the system prompt
                    // as content items. Single-item Contents.of() can produce blank output
                    // in some LiteRT-LM versions; two items ensures the model has context.
                    runEngineInference(
                        systemPrompt = effectivePrompt,
                        contents = listOf(
                            Content.Text(text),
                            Content.Text(effectivePrompt)
                        )
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

    /** Returned when photo analysis exceeds the 30-second timeout. */
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
}
