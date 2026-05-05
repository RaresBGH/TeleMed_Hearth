// Licensed under the Creative Commons Attribution 4.0 International License (CC-BY 4.0)
// You may obtain a copy of the License at https://creativecommons.org/licenses/by/4.0/
//
// TeleMed_K: Offline-first telemedicine app for seniors

package com.example.telemed_k.channels

import android.content.Context
import android.graphics.BitmapFactory
import android.util.Log
import com.google.mlkit.vision.common.InputImage
import com.google.mlkit.vision.text.TextRecognition
import com.google.mlkit.vision.text.latin.TextRecognizerOptions
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.TimeoutCancellationException
import kotlinx.coroutines.launch
import kotlinx.coroutines.suspendCancellableCoroutine
import kotlinx.coroutines.withContext
import kotlinx.coroutines.withTimeout
import kotlin.coroutines.resume

/**
 * MethodChannel handler for on-device OCR using ML Kit Text Recognition.
 *
 * Method: extractTextFromImage(imagePath: String) → String
 *   Loads a bitmap from [imagePath], runs the ML Kit Latin text recogniser, and
 *   returns all extracted text as a single newline-delimited string.
 *   Returns "" on any failure — never crashes.
 */
class OcrChannel(private val context: Context) : MethodChannel.MethodCallHandler {

    private val scope = CoroutineScope(SupervisorJob() + Dispatchers.IO)
    private val recognizer = TextRecognition.getClient(TextRecognizerOptions.DEFAULT_OPTIONS)

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "extractTextFromImage" -> {
                val imagePath = call.argument<String>("imagePath") ?: ""
                scope.launch {
                    val text = extractText(imagePath)
                    withContext(Dispatchers.Main) { result.success(text) }
                }
            }
            else -> result.notImplemented()
        }
    }

    private suspend fun extractText(imagePath: String): String {
        if (imagePath.isEmpty()) return ""
        return try {
            withTimeout(15_000L) {
                val bitmap = BitmapFactory.decodeFile(imagePath) ?: return@withTimeout ""
                val image  = InputImage.fromBitmap(bitmap, 0)

                suspendCancellableCoroutine { cont ->
                    recognizer.process(image)
                        .addOnSuccessListener { visionText ->
                            Log.d("OcrChannel", "OCR complete — ${visionText.text.length} chars")
                            cont.resume(visionText.text)
                        }
                        .addOnFailureListener { e ->
                            Log.e("OcrChannel", "OCR failed", e)
                            cont.resume("")
                        }
                }
            }
        } catch (e: TimeoutCancellationException) {
            Log.w("OcrChannel", "ML Kit timed out after 15s")
            ""
        } catch (e: Exception) {
            Log.e("OcrChannel", "extractText error", e)
            ""
        }
    }
}
