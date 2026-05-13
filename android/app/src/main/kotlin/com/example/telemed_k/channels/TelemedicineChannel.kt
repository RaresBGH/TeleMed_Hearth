// Licensed under the Creative Commons Attribution 4.0 International License (CC-BY 4.0)
// You may obtain a copy of the License at https://creativecommons.org/licenses/by/4.0/
//
// TeleMed_K: Offline-first telemedicine app for seniors
// Native Kotlin Bridge — Telemedicine MethodChannel Handler (WebRTC Signaling)

package com.example.telemed_k.channels

import android.content.Context
import android.util.Log
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.launch

/**
 * Native handler for the `com.telemed_k/telemedicine` MethodChannel.
 *
 * Bridges Flutter ↔ native Android for WebRTC call signaling via Medplum.
 * Also handles FCM token retrieval for push notification-based call initiation.
 *
 * Methods handled (Dart → Native):
 *   - getFcmToken   — Returns the current Firebase Cloud Messaging device token
 *   - answerCall    — Answers an incoming WebRTC call by callId
 *
 * Methods invoked (Native → Dart):
 *   - onIncomingCall — Pushes incoming call metadata to the Flutter layer
 */
class TelemedicineChannel(
    private val context: Context
) : MethodChannel.MethodCallHandler {

    companion object {
        const val CHANNEL_NAME = "com.telemed_k/telemedicine"
        private const val TAG = "TelemedicineChannel"
    }

    private val scope = CoroutineScope(SupervisorJob() + Dispatchers.IO)

    // Reference to the Dart-side MethodChannel for native → Dart invocations
    private var dartChannel: MethodChannel? = null

    /**
     * Stores the MethodChannel reference so this handler can invoke methods
     * back into Dart (e.g., onIncomingCall when an FCM push arrives).
     */
    fun setDartChannel(channel: MethodChannel) {
        dartChannel = channel
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "getFcmToken" -> handleGetFcmToken(result)
            "answerCall" -> handleAnswerCall(call, result)
            else -> result.notImplemented()
        }
    }

    // ──────────────────────────────────────────────────────────────────────────
    // getFcmToken
    // ──────────────────────────────────────────────────────────────────────────
    private fun handleGetFcmToken(result: MethodChannel.Result) {
        scope.launch {
            try {
                // Production implementation (requires Firebase dependency):
                //   val token = FirebaseMessaging.getInstance().token.await()
                //   result.success(token)
                //
                // Bridge stub — returns a placeholder token for testing the channel wiring.
                // The real FCM token will be available once google-services.json is configured.
                val stubToken = "fcm-stub-token-telemed-k-${System.currentTimeMillis()}"
                Log.i(TAG, "FCM token requested (stub): $stubToken")
                result.success(stubToken)
            } catch (e: Exception) {
                Log.e(TAG, "Failed to retrieve FCM token", e)
                result.error("FCM_ERROR", "FCM token retrieval failed", null)
            }
        }
    }

    // ──────────────────────────────────────────────────────────────────────────
    // answerCall
    // ──────────────────────────────────────────────────────────────────────────
    private fun handleAnswerCall(call: MethodCall, result: MethodChannel.Result) {
        scope.launch {
            try {
                val callId = call.argument<String>("callId")
                    ?: return@launch result.error("INVALID_ARG", "Missing 'callId' argument", null)

                // Production implementation:
                //   1. Retrieve offer SDP from Medplum FHIR Communication resource by callId
                //   2. Create PeerConnection with ICE servers
                //   3. Set remote description (offer)
                //   4. Create answer SDP
                //   5. Set local description (answer)
                //   6. POST answer SDP back to Medplum
                //   7. Begin ICE candidate exchange
                //
                // Bridge stub — acknowledges the call answer for channel testing:
                Log.i(TAG, "Call answered (stub): callId=$callId")
                result.success(null)
            } catch (e: Exception) {
                Log.e(TAG, "Failed to answer call", e)
                result.error("CALL_ERROR", "Call answer failed", null)
            }
        }
    }

}
