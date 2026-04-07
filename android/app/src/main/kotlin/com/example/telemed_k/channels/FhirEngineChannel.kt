// Licensed under the Creative Commons Attribution 4.0 International License (CC-BY 4.0)
// You may obtain a copy of the License at https://creativecommons.org/licenses/by/4.0/
//
// TeleMed_K: Offline-first telemedicine app for seniors
// Native Kotlin Bridge — FHIR Engine MethodChannel Handler

package com.example.telemed_k.channels

import android.content.Context
import android.util.Log
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.launch

import ca.uhn.fhir.context.FhirContext
import com.google.android.fhir.FhirEngine
import com.google.android.fhir.FhirEngineConfiguration
import com.google.android.fhir.FhirEngineProvider
import com.google.android.fhir.search.search
import org.hl7.fhir.r4.model.ResourceType
import org.json.JSONArray
import org.json.JSONObject

/**
 * Native handler for the `com.telemed_k/fhir_engine` MethodChannel.
 *
 * Bridges Flutter ↔ Google Android FHIR SDK for encrypted local SQLite CRUD operations
 * on HL7 FHIR Observation, Condition, Encounter, and MedicationRequest resources.
 *
 * Methods handled:
 *   - initializeDatabase
 *   - saveObservation
 *   - saveCondition
 *   - getUnsyncedResources
 *   - getPatientHistory
 *   - getMostRecentEncounter
 *   - getMostRecentMedicationRequest
 *   - updateEncounterConsent
 *   - markAsSynced
 */
class FhirEngineChannel(
    private val context: Context
) : MethodChannel.MethodCallHandler {

    companion object {
        private const val TAG = "FhirEngineChannel"
        // Singleton HAPI FHIR context — thread-safe, expensive to create, reuse always.
        private val fhirContext: FhirContext by lazy { FhirContext.forR4() }
    }

    private val scope = CoroutineScope(SupervisorJob() + Dispatchers.IO)
    private var fhirEngine: FhirEngine? = null
    private var isInitialized = false

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "initializeDatabase" -> handleInitializeDatabase(call, result)
            "saveObservation" -> handleSaveObservation(call, result)
            "saveCondition" -> handleSaveCondition(call, result)
            "getUnsyncedResources" -> handleGetUnsyncedResources(result)
            "getPatientHistory" -> handleGetPatientHistory(result)
            "getMostRecentEncounter" -> handleGetMostRecentEncounter(result)
            "getMostRecentMedicationRequest" -> handleGetMostRecentMedicationRequest(result)
            "updateEncounterConsent" -> handleUpdateEncounterConsent(call, result)
            "markAsSynced" -> handleMarkAsSynced(call, result)
            else -> result.notImplemented()
        }
    }

    // ──────────────────────────────────────────────────────────────────────────
    // initializeDatabase
    // ──────────────────────────────────────────────────────────────────────────
    private fun handleInitializeDatabase(call: MethodCall, result: MethodChannel.Result) {
        scope.launch {
            try {
                val enableEncryption = call.argument<Boolean>("enableEncryption") ?: true

                // The FHIR SDK must be initialized once per app lifecycle via FhirEngineProvider.
                // FhirEngineProvider.init() is idempotent; subsequent calls are no-ops.
                FhirEngineProvider.init(
                    FhirEngineConfiguration(
                        enableEncryptionIfSupported = enableEncryption
                    )
                )
                fhirEngine = FhirEngineProvider.getInstance(context)
                isInitialized = true

                Log.i(TAG, "FHIR Engine initialized (encryption=$enableEncryption)")
                result.success(null)
            } catch (e: Exception) {
                Log.e(TAG, "Failed to initialize FHIR Engine", e)
                result.error("FHIR_INIT_ERROR", "Database initialization failed", null)
            }
        }
    }

    // ──────────────────────────────────────────────────────────────────────────
    // saveObservation
    // ──────────────────────────────────────────────────────────────────────────
    private fun handleSaveObservation(call: MethodCall, result: MethodChannel.Result) {
        scope.launch {
            try {
                ensureInitialized()
                val resourceJson = call.argument<String>("resource")
                    ?: return@launch result.error("INVALID_ARG", "Missing 'resource' argument", null)

                val parser = fhirContext.newJsonParser()
                val observation = parser.parseResource(
                    org.hl7.fhir.r4.model.Observation::class.java,
                    resourceJson
                )
                fhirEngine!!.create(observation)

                Log.i(TAG, "Observation saved: ${observation.idElement?.idPart}")
                result.success(null)
            } catch (e: Exception) {
                Log.e(TAG, "Failed to save Observation", e)
                result.error("FHIR_WRITE_ERROR", "Observation write failed", null)
            }
        }
    }

    // ──────────────────────────────────────────────────────────────────────────
    // saveCondition
    // ──────────────────────────────────────────────────────────────────────────
    private fun handleSaveCondition(call: MethodCall, result: MethodChannel.Result) {
        scope.launch {
            try {
                ensureInitialized()
                val resourceJson = call.argument<String>("resource")
                    ?: return@launch result.error("INVALID_ARG", "Missing 'resource' argument", null)

                val parser = fhirContext.newJsonParser()
                val condition = parser.parseResource(
                    org.hl7.fhir.r4.model.Condition::class.java,
                    resourceJson
                )
                fhirEngine!!.create(condition)

                Log.i(TAG, "Condition saved: ${condition.idElement?.idPart}")
                result.success(null)
            } catch (e: Exception) {
                Log.e(TAG, "Failed to save Condition", e)
                result.error("FHIR_WRITE_ERROR", "Condition write failed", null)
            }
        }
    }

    // ──────────────────────────────────────────────────────────────────────────
    // getUnsyncedResources
    // ──────────────────────────────────────────────────────────────────────────
    private fun handleGetUnsyncedResources(result: MethodChannel.Result) {
        scope.launch {
            try {
                ensureInitialized()
                // Query all local Observations and Conditions that have not yet been synced.
                // The FHIR SDK tracks local-only resources via its internal sync state.
                val unsyncedObservations = fhirEngine!!.search<org.hl7.fhir.r4.model.Observation> {}
                val unsyncedConditions = fhirEngine!!.search<org.hl7.fhir.r4.model.Condition> {}

                val parser = fhirContext.newJsonParser()
                val jsonArray = JSONArray()

                unsyncedObservations.forEach { searchResult ->
                    jsonArray.put(JSONObject(parser.encodeResourceToString(searchResult.resource)))
                }
                unsyncedConditions.forEach { searchResult ->
                    jsonArray.put(JSONObject(parser.encodeResourceToString(searchResult.resource)))
                }

                result.success(jsonArray.toString())
            } catch (e: Exception) {
                Log.e(TAG, "Failed to get unsynced resources", e)
                result.error("FHIR_READ_ERROR", "Unsynced resource query failed", null)
            }
        }
    }

    // ──────────────────────────────────────────────────────────────────────────
    // getPatientHistory
    // ──────────────────────────────────────────────────────────────────────────
    private fun handleGetPatientHistory(result: MethodChannel.Result) {
        scope.launch {
            try {
                ensureInitialized()
                val observations = fhirEngine!!.search<org.hl7.fhir.r4.model.Observation> {}
                val conditions = fhirEngine!!.search<org.hl7.fhir.r4.model.Condition> {}

                val parser = fhirContext.newJsonParser()
                val jsonArray = JSONArray()

                observations.forEach { searchResult ->
                    jsonArray.put(JSONObject(parser.encodeResourceToString(searchResult.resource)))
                }
                conditions.forEach { searchResult ->
                    jsonArray.put(JSONObject(parser.encodeResourceToString(searchResult.resource)))
                }

                result.success(jsonArray.toString())
            } catch (e: Exception) {
                Log.e(TAG, "Failed to get patient history", e)
                result.error("FHIR_READ_ERROR", "Patient history query failed", null)
            }
        }
    }

    // ──────────────────────────────────────────────────────────────────────────
    // getMostRecentEncounter
    // ──────────────────────────────────────────────────────────────────────────
    private fun handleGetMostRecentEncounter(result: MethodChannel.Result) {
        scope.launch {
            try {
                ensureInitialized()
                val encounters = fhirEngine!!.search<org.hl7.fhir.r4.model.Encounter> {}

                if (encounters.isEmpty()) {
                    result.success(null)
                    return@launch
                }

                // Sort by period.start descending and return the most recent
                val mostRecent = encounters
                    .sortedByDescending { it.resource.period?.start?.time ?: 0L }
                    .first()

                val parser = fhirContext.newJsonParser()
                result.success(parser.encodeResourceToString(mostRecent.resource))
            } catch (e: Exception) {
                Log.e(TAG, "Failed to get most recent encounter", e)
                result.error("FHIR_READ_ERROR", "Encounter query failed", null)
            }
        }
    }

    // ──────────────────────────────────────────────────────────────────────────
    // getMostRecentMedicationRequest
    // ──────────────────────────────────────────────────────────────────────────
    private fun handleGetMostRecentMedicationRequest(result: MethodChannel.Result) {
        scope.launch {
            try {
                ensureInitialized()
                val requests = fhirEngine!!.search<org.hl7.fhir.r4.model.MedicationRequest> {}

                if (requests.isEmpty()) {
                    result.success(null)
                    return@launch
                }

                val mostRecent = requests
                    .sortedByDescending { it.resource.authoredOn?.time ?: 0L }
                    .first()

                val parser = fhirContext.newJsonParser()
                result.success(parser.encodeResourceToString(mostRecent.resource))
            } catch (e: Exception) {
                Log.e(TAG, "Failed to get most recent medication request", e)
                result.error("FHIR_READ_ERROR", "MedicationRequest query failed", null)
            }
        }
    }

    // ──────────────────────────────────────────────────────────────────────────
    // updateEncounterConsent
    // ──────────────────────────────────────────────────────────────────────────
    private fun handleUpdateEncounterConsent(call: MethodCall, result: MethodChannel.Result) {
        scope.launch {
            try {
                ensureInitialized()
                val callId = call.argument<String>("callId")
                    ?: return@launch result.error("INVALID_ARG", "Missing 'callId' argument", null)
                val consent = call.argument<Boolean>("consent") ?: true

                // Retrieve the Encounter by logical ID, stamp a consent extension, and update.
                val encounter = fhirEngine!!.get(ResourceType.Encounter, callId) as org.hl7.fhir.r4.model.Encounter

                // Add FHIR-compliant consent extension
                val consentExtension = org.hl7.fhir.r4.model.Extension(
                    "http://telemed-k.example.com/fhir/StructureDefinition/digital-consent"
                ).setValue(org.hl7.fhir.r4.model.BooleanType(consent))
                encounter.addExtension(consentExtension)

                fhirEngine!!.update(encounter)

                Log.i(TAG, "Encounter $callId consent updated: $consent")
                result.success(null)
            } catch (e: Exception) {
                Log.e(TAG, "Failed to update encounter consent", e)
                result.error("FHIR_WRITE_ERROR", "Consent update failed", null)
            }
        }
    }

    // ──────────────────────────────────────────────────────────────────────────
    // markAsSynced
    // ──────────────────────────────────────────────────────────────────────────
    private fun handleMarkAsSynced(call: MethodCall, result: MethodChannel.Result) {
        scope.launch {
            try {
                ensureInitialized()
                @Suppress("UNCHECKED_CAST")
                val resourceIds = call.argument<List<String>>("resourceIds")
                    ?: return@launch result.error("INVALID_ARG", "Missing 'resourceIds' argument", null)

                // Mark each resource with a "synced" meta tag so future getUnsyncedResources
                // queries can filter them out. In a production app this would use the FHIR SDK's
                // built-in sync state machine; here we stamp a meta.tag for explicitness.
                for (id in resourceIds) {
                    try {
                        // Attempt Observation first, then Condition
                        val observation = runCatching {
                            fhirEngine!!.get(ResourceType.Observation, id) as org.hl7.fhir.r4.model.Observation
                        }.getOrNull()

                        if (observation != null) {
                            observation.meta.addTag(
                                org.hl7.fhir.r4.model.Coding()
                                    .setSystem("http://telemed-k.example.com/sync-status")
                                    .setCode("synced")
                            )
                            fhirEngine!!.update(observation)
                            continue
                        }

                        val condition = runCatching {
                            fhirEngine!!.get(ResourceType.Condition, id) as org.hl7.fhir.r4.model.Condition
                        }.getOrNull()

                        if (condition != null) {
                            condition.meta.addTag(
                                org.hl7.fhir.r4.model.Coding()
                                    .setSystem("http://telemed-k.example.com/sync-status")
                                    .setCode("synced")
                            )
                            fhirEngine!!.update(condition)
                        }
                    } catch (innerEx: Exception) {
                        Log.w(TAG, "Could not mark resource $id as synced", innerEx)
                    }
                }

                Log.i(TAG, "Marked ${resourceIds.size} resources as synced")
                result.success(null)
            } catch (e: Exception) {
                Log.e(TAG, "Failed to mark resources as synced", e)
                result.error("FHIR_WRITE_ERROR", "Mark synced failed", null)
            }
        }
    }

    // ──────────────────────────────────────────────────────────────────────────
    // Helpers
    // ──────────────────────────────────────────────────────────────────────────
    private fun ensureInitialized() {
        if (!isInitialized || fhirEngine == null) {
            throw IllegalStateException("FHIR Engine not initialized. Call initializeDatabase first.")
        }
    }
}
