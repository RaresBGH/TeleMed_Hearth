// Licensed under the Creative Commons Attribution 4.0 International License (CC-BY 4.0)
// You may obtain a copy of the License at https://creativecommons.org/licenses/by/4.0/
//
// TeleMed Hearth: Offline-first telemedicine app for seniors
// Phase 7.10 — Native Kotlin Bridge: FHIR Engine + LiteRT-LM + Telemedicine MethodChannels

package com.example.telemed_k

import android.os.Bundle
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

import com.example.telemed_k.channels.AudioTranscodeChannel
import com.example.telemed_k.channels.FhirEngineChannel
import com.example.telemed_k.channels.LiteRtLmChannel
import com.example.telemed_k.channels.OcrChannel
import com.example.telemed_k.channels.TelemedicineChannel
import com.example.telemed_k.services.ModelDownloadService

/**
 * Main Activity for TeleMed Hearth.
 *
 * Extends [FlutterFragmentActivity] (required by smart_auth for Android SMS Retriever API
 * fragment lifecycle) instead of the default [FlutterActivity].
 *
 * Registers three native MethodChannels that bridge Flutter ↔ Android:
 *   1. com.telemed_k/fhir_engine  — Google Android FHIR SDK (encrypted SQLite CRUD)
 *   2. com.telemed_k/litert_lm    — Google LiteRT-LM (Gemma 4 E2B local inference)
 *   3. com.telemed_k/telemedicine  — WebRTC call signaling via Medplum
 */
class MainActivity : FlutterFragmentActivity() {

    companion object {
        private const val FHIR_ENGINE_CHANNEL = "com.telemed_k/fhir_engine"
        private const val LITERT_LM_CHANNEL = "com.telemed_k/litert_lm"
        private const val TELEMEDICINE_CHANNEL = "com.telemed_k/telemedicine"
        private const val AUDIO_TRANSCODE_CHANNEL = "com.telemed_k/audio_transcode"
        private const val MODEL_DOWNLOAD_CHANNEL  = "com.telemed_k/model_download"
        private const val OCR_CHANNEL             = "com.telemed_k/ocr"
    }

    private lateinit var audioTranscodeChannel: AudioTranscodeChannel
    private lateinit var fhirEngineChannel: FhirEngineChannel
    private lateinit var liteRtLmChannel: LiteRtLmChannel
    private lateinit var ocrChannel: OcrChannel
    private lateinit var telemedicineChannel: TelemedicineChannel
    private lateinit var modelDownloadService: ModelDownloadService

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        // --- 1. Model Download Channel ---
        modelDownloadService = ModelDownloadService(this)
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            MODEL_DOWNLOAD_CHANNEL
        ).setMethodCallHandler(modelDownloadService)

        // --- 2. Audio Transcode Channel ---
        audioTranscodeChannel = AudioTranscodeChannel(this)
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            AUDIO_TRANSCODE_CHANNEL
        ).setMethodCallHandler(audioTranscodeChannel)

        // --- 2. FHIR Engine Channel ---
        fhirEngineChannel = FhirEngineChannel(this)
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            FHIR_ENGINE_CHANNEL
        ).setMethodCallHandler(fhirEngineChannel)

        // --- 2. LiteRT-LM Channel ---
        liteRtLmChannel = LiteRtLmChannel(this)
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            LITERT_LM_CHANNEL
        ).setMethodCallHandler(liteRtLmChannel)

        // --- 3. OCR Channel ---
        ocrChannel = OcrChannel(this)
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            OCR_CHANNEL
        ).setMethodCallHandler(ocrChannel)

        // --- 4. Telemedicine Channel ---
        telemedicineChannel = TelemedicineChannel(this)
        val telemedicineMethodChannel = MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            TELEMEDICINE_CHANNEL
        )
        telemedicineMethodChannel.setMethodCallHandler(telemedicineChannel)
        // Provide the channel reference back so native can invoke onIncomingCall → Dart
        telemedicineChannel.setDartChannel(telemedicineMethodChannel)
    }
}
