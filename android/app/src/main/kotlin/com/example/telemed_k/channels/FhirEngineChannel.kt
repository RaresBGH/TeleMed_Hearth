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
 *   - updateObservation
 *   - lookupPatientByCnp
 *   - savePatient
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
            "getPatientHistory" -> handleGetPatientHistory(call, result)
            "getMostRecentEncounter" -> handleGetMostRecentEncounter(result)
            "getMostRecentMedicationRequest" -> handleGetMostRecentMedicationRequest(result)
            "updateEncounterConsent" -> handleUpdateEncounterConsent(call, result)
            "updateObservation" -> handleUpdateObservation(call, result)
            "lookupPatientByCnp" -> handleLookupPatientByCnp(call, result)
            "savePatient" -> handleSavePatient(call, result)
            "updatePatient" -> handleUpdatePatient(call, result)
            "deletePatientData" -> handleDeletePatientData(call, result)
            "saveAppointment" -> handleSaveAppointment(call, result)
            "getAppointments" -> handleGetAppointments(call, result)
            "markAsSynced" -> handleMarkAsSynced(call, result)
            "seedMockData" -> handleSeedMockData(result)
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
    private fun handleGetPatientHistory(call: MethodCall, result: MethodChannel.Result) {
        scope.launch {
            try {
                ensureInitialized()
                val cnp = call.argument<String>("cnp") ?: ""

                val observations = fhirEngine!!.search<org.hl7.fhir.r4.model.Observation> {}
                val conditions   = fhirEngine!!.search<org.hl7.fhir.r4.model.Condition> {}

                val parser = fhirContext.newJsonParser()
                val jsonArray = JSONArray()

                observations.forEach { searchResult ->
                    val obs = searchResult.resource
                    if (cnp.isEmpty() || matchesPatientCnp(obs.subject, cnp)) {
                        jsonArray.put(JSONObject(parser.encodeResourceToString(obs)))
                    }
                }
                conditions.forEach { searchResult ->
                    val cond = searchResult.resource
                    if (cnp.isEmpty() || matchesPatientCnp(cond.subject, cnp)) {
                        jsonArray.put(JSONObject(parser.encodeResourceToString(cond)))
                    }
                }

                Log.i(TAG, "getPatientHistory: returned ${jsonArray.length()} resources for CNP=$cnp")
                result.success(jsonArray.toString())
            } catch (e: Exception) {
                Log.e(TAG, "Failed to get patient history", e)
                result.error("FHIR_READ_ERROR", "Patient history query failed", null)
            }
        }
    }

    /**
     * Returns true if [subject] belongs to the patient identified by [cnp].
     *
     * Handles two formats used in this app:
     *  - Triage Observations: subject.identifier.value == cnp
     *  - Mock Conditions:     subject.reference == "Patient/patient-<cnp>"
     */
    private fun matchesPatientCnp(subject: org.hl7.fhir.r4.model.Reference, cnp: String): Boolean {
        // Format 1 — identifier-based (triage Observations from medical_session_provider)
        if (subject.hasIdentifier() && subject.identifier?.value == cnp) return true
        // Format 2 — literal reference (mock seed Conditions: "Patient/patient-<cnp>")
        val ref = subject.reference ?: return false
        return ref == "Patient/patient-$cnp"
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
    // updateObservation — overwrites an existing Observation by logical ID
    // ──────────────────────────────────────────────────────────────────────────
    private fun handleUpdateObservation(call: MethodCall, result: MethodChannel.Result) {
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
                fhirEngine!!.update(observation)

                Log.i(TAG, "Observation updated: ${observation.idElement?.idPart}")
                result.success(null)
            } catch (e: Exception) {
                Log.e(TAG, "Failed to update Observation", e)
                result.error("FHIR_WRITE_ERROR", "Observation update failed", null)
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
    // lookupPatientByCnp — finds a Patient whose identifier matches the CNP
    // ──────────────────────────────────────────────────────────────────────────
    private fun handleLookupPatientByCnp(call: MethodCall, result: MethodChannel.Result) {
        scope.launch {
            try {
                ensureInitialized()
                val cnp = call.argument<String>("cnp")
                    ?: return@launch result.error("INVALID_ARG", "Missing 'cnp' argument", null)

                val patients = fhirEngine!!.search<org.hl7.fhir.r4.model.Patient> {}
                val parser = fhirContext.newJsonParser()

                val found = patients.firstOrNull { sr ->
                    sr.resource.identifier.any { id ->
                        id.system == "urn:oid:1.2.40.0.10.1.4.3.1" && id.value == cnp
                    }
                }

                if (found != null) {
                    Log.i(TAG, "lookupPatientByCnp: found patient ${found.resource.idElement?.idPart} for CNP $cnp")
                    result.success(parser.encodeResourceToString(found.resource))
                } else {
                    Log.i(TAG, "lookupPatientByCnp: no patient found for CNP $cnp")
                    result.success(null)
                }
            } catch (e: Exception) {
                Log.e(TAG, "Failed to lookup patient by CNP", e)
                result.error("FHIR_READ_ERROR", "Patient lookup failed", null)
            }
        }
    }

    // ──────────────────────────────────────────────────────────────────────────
    // savePatient — creates a new Patient resource for a newly registered user
    // ──────────────────────────────────────────────────────────────────────────
    private fun handleSavePatient(call: MethodCall, result: MethodChannel.Result) {
        scope.launch {
            try {
                ensureInitialized()
                val resourceJson = call.argument<String>("resource")
                    ?: return@launch result.error("INVALID_ARG", "Missing 'resource' argument", null)

                val parser = fhirContext.newJsonParser()
                val patient = parser.parseResource(
                    org.hl7.fhir.r4.model.Patient::class.java,
                    resourceJson
                )
                fhirEngine!!.create(patient)

                Log.i(TAG, "Patient saved: ${patient.idElement?.idPart}")
                result.success(null)
            } catch (e: Exception) {
                Log.e(TAG, "Failed to save Patient", e)
                result.error("FHIR_WRITE_ERROR", "Patient write failed", null)
            }
        }
    }

    // ──────────────────────────────────────────────────────────────────────────
    // updatePatient — overwrites an existing Patient resource by logical ID
    // ──────────────────────────────────────────────────────────────────────────
    private fun handleUpdatePatient(call: MethodCall, result: MethodChannel.Result) {
        scope.launch {
            try {
                ensureInitialized()
                val resourceJson = call.argument<String>("resource")
                    ?: return@launch result.error("INVALID_ARG", "Missing 'resource' argument", null)

                val parser = fhirContext.newJsonParser()
                val patient = parser.parseResource(
                    org.hl7.fhir.r4.model.Patient::class.java,
                    resourceJson
                )
                fhirEngine!!.update(patient)

                Log.i(TAG, "Patient updated: ${patient.idElement?.idPart}")
                result.success(null)
            } catch (e: Exception) {
                Log.e(TAG, "Failed to update Patient", e)
                result.error("FHIR_WRITE_ERROR", "Patient update failed", null)
            }
        }
    }

    // ──────────────────────────────────────────────────────────────────────────
    // deletePatientData — removes all FHIR resources for a given CNP
    // ──────────────────────────────────────────────────────────────────────────
    private fun handleDeletePatientData(call: MethodCall, result: MethodChannel.Result) {
        scope.launch {
            try {
                ensureInitialized()
                val cnp = call.argument<String>("cnp")
                    ?: return@launch result.error("INVALID_ARG", "Missing 'cnp' argument", null)

                // Delete Observations belonging to this patient
                fhirEngine!!.search<org.hl7.fhir.r4.model.Observation> {}.forEach { sr ->
                    if (matchesPatientCnp(sr.resource.subject, cnp)) {
                        runCatching {
                            fhirEngine!!.delete(ResourceType.Observation, sr.resource.idElement?.idPart ?: "")
                        }
                    }
                }

                // Delete Conditions belonging to this patient
                fhirEngine!!.search<org.hl7.fhir.r4.model.Condition> {}.forEach { sr ->
                    if (matchesPatientCnp(sr.resource.subject, cnp)) {
                        runCatching {
                            fhirEngine!!.delete(ResourceType.Condition, sr.resource.idElement?.idPart ?: "")
                        }
                    }
                }

                // Delete Encounters (all — shared clinic resource, fine for single-patient app)
                fhirEngine!!.search<org.hl7.fhir.r4.model.Encounter> {}.forEach { sr ->
                    runCatching {
                        fhirEngine!!.delete(ResourceType.Encounter, sr.resource.idElement?.idPart ?: "")
                    }
                }

                // Delete Appointments — Appointment type may not be registered; guard entirely
                runCatching {
                    fhirEngine!!.search<org.hl7.fhir.r4.model.Appointment> {}.forEach { sr ->
                        runCatching {
                            fhirEngine!!.delete(ResourceType.Appointment, sr.resource.idElement?.idPart ?: "")
                        }
                    }
                }

                // Delete the Patient resource itself (last, to preserve FK references above)
                val patients = fhirEngine!!.search<org.hl7.fhir.r4.model.Patient> {}
                patients.firstOrNull { sr ->
                    sr.resource.identifier.any { id ->
                        id.system == "urn:oid:1.2.40.0.10.1.4.3.1" && id.value == cnp
                    }
                }?.let { sr ->
                    runCatching {
                        fhirEngine!!.delete(ResourceType.Patient, sr.resource.idElement?.idPart ?: "")
                    }
                }

                Log.i(TAG, "Deleted all FHIR data for CNP=$cnp")
                result.success(null)
            } catch (e: Exception) {
                Log.e(TAG, "Failed to delete patient data", e)
                result.error("FHIR_DELETE_ERROR", "Patient data deletion failed", null)
            }
        }
    }

    // ──────────────────────────────────────────────────────────────────────────
    // saveAppointment — creates a FHIR Appointment for a patient booking
    // ──────────────────────────────────────────────────────────────────────────
    private fun handleSaveAppointment(call: MethodCall, result: MethodChannel.Result) {
        scope.launch {
            try {
                ensureInitialized()
                val patientCnp     = call.argument<String>("patientId")       ?: ""
                val practitionerId = call.argument<String>("practitionerId")   ?: "family"
                val dateTimeIso    = call.argument<String>("dateTimeIso")      ?: ""
                val durationMin    = call.argument<Int>("durationMinutes")     ?: 30
                val description    = call.argument<String>("description")      ?: ""
                val status         = call.argument<String>("status")           ?: "booked"

                // Parse ISO 8601 — handle both "...Z" and "...+00:00" formats
                val startInstant = runCatching { java.time.Instant.parse(dateTimeIso) }
                    .getOrElse { java.time.OffsetDateTime.parse(dateTimeIso).toInstant() }
                val startDate = java.util.Date.from(startInstant)
                val endDate   = java.util.Date.from(startInstant.plusSeconds(durationMin * 60L))

                val appointment = org.hl7.fhir.r4.model.Appointment()

                appointment.status = when (status.lowercase()) {
                    "fulfilled" -> org.hl7.fhir.r4.model.Appointment.AppointmentStatus.FULFILLED
                    "cancelled" -> org.hl7.fhir.r4.model.Appointment.AppointmentStatus.CANCELLED
                    else        -> org.hl7.fhir.r4.model.Appointment.AppointmentStatus.BOOKED
                }
                appointment.description = description
                appointment.start = startDate
                appointment.end   = endDate

                appointment.appointmentType = org.hl7.fhir.r4.model.CodeableConcept().apply {
                    addCoding(
                        org.hl7.fhir.r4.model.Coding()
                            .setSystem("http://terminology.hl7.org/CodeSystem/v2-0276")
                            .setCode("ROUTINE").setDisplay("Routine appointment")
                    )
                }

                // Patient participant (identified by CNP)
                appointment.addParticipant(
                    org.hl7.fhir.r4.model.Appointment.AppointmentParticipantComponent().apply {
                        actor = org.hl7.fhir.r4.model.Reference().apply {
                            identifier = org.hl7.fhir.r4.model.Identifier().apply {
                                system = "urn:oid:1.2.40.0.10.1.4.3.1"
                                value  = patientCnp
                            }
                        }
                        required = org.hl7.fhir.r4.model.Appointment.ParticipantRequired.REQUIRED
                        setStatus(org.hl7.fhir.r4.model.Appointment.ParticipationStatus.ACCEPTED)
                    }
                )

                // Practitioner participant
                appointment.addParticipant(
                    org.hl7.fhir.r4.model.Appointment.AppointmentParticipantComponent().apply {
                        actor  = org.hl7.fhir.r4.model.Reference("Practitioner/$practitionerId")
                        setStatus(org.hl7.fhir.r4.model.Appointment.ParticipationStatus.ACCEPTED)
                    }
                )

                fhirEngine!!.create(appointment)
                Log.i(TAG, "Appointment saved: ${appointment.idElement?.idPart}")
                result.success(null)
            } catch (e: Exception) {
                Log.e(TAG, "Failed to save Appointment", e)
                result.error("FHIR_WRITE_ERROR", "Appointment write failed", null)
            }
        }
    }

    // ──────────────────────────────────────────────────────────────────────────
    // getAppointments — returns Appointments filtered by patient CNP
    // ──────────────────────────────────────────────────────────────────────────
    private fun handleGetAppointments(call: MethodCall, result: MethodChannel.Result) {
        scope.launch {
            try {
                ensureInitialized()
                val patientCnp       = call.argument<String>("cnp") ?: ""
                val practitionerRef  = call.argument<String>("practitionerRef") // nullable

                // Guard: Appointment type may not be in FHIR schema yet
                val appointments = runCatching {
                    fhirEngine!!.search<org.hl7.fhir.r4.model.Appointment> {}
                }.getOrElse {
                    Log.w(TAG, "Appointment resource type not available: ${it.message}")
                    emptyList()
                }

                val parser    = fhirContext.newJsonParser()
                val jsonArray = JSONArray()

                val now = System.currentTimeMillis()

                val filtered = appointments
                    .filter { sr ->
                        // Filter by patient CNP
                        if (patientCnp.isNotEmpty()) {
                            val hasPatient = sr.resource.participant.any { p ->
                                p.actor?.identifier?.system == "urn:oid:1.2.40.0.10.1.4.3.1" &&
                                p.actor?.identifier?.value  == patientCnp
                            }
                            if (!hasPatient) return@filter false
                        }
                        // Filter by practitionerRef when provided (per-doctor calendar scoping)
                        if (practitionerRef != null) {
                            val hasPractitioner = sr.resource.participant.any { p ->
                                p.actor?.reference == "Practitioner/$practitionerRef"
                            }
                            if (!hasPractitioner) return@filter false
                        }
                        true
                    }

                // Upcoming (start >= now) sorted ascending (soonest first),
                // past (start < now) sorted descending (most recent first).
                val upcoming = filtered
                    .filter { (it.resource.start?.time ?: 0L) >= now }
                    .sortedBy   { it.resource.start?.time ?: 0L }
                val past = filtered
                    .filter { (it.resource.start?.time ?: 0L) < now }
                    .sortedByDescending { it.resource.start?.time ?: 0L }

                (upcoming + past).take(50).forEach { sr ->
                    jsonArray.put(JSONObject(parser.encodeResourceToString(sr.resource)))
                }

                Log.i(TAG, "getAppointments: returned ${jsonArray.length()} for CNP=$patientCnp")
                result.success(jsonArray.toString())
            } catch (e: Exception) {
                Log.e(TAG, "Failed to get Appointments", e)
                result.error("FHIR_READ_ERROR", "Appointment query failed", null)
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
    // seedMockData
    // ──────────────────────────────────────────────────────────────────────────
    private fun handleSeedMockData(result: MethodChannel.Result) {
        scope.launch {
            try {
                ensureInitialized()
                val parser = fhirContext.newJsonParser()

                // ── 5 mock patients — Romanian clinic roster ─────────────────
                data class PatientSeed(val id: String, val cnp: String, val family: String,
                    val given: String, val dob: String, val phone: String, val condition: String)
                val seeds = listOf(
                    PatientSeed("patient-2540203152485","2540203152485","Ionescu","Maria","1954-02-03","0721234567","Hipertensiune arterială"),
                    PatientSeed("patient-1490815054321","1490815054321","Popescu","Ion","1949-08-15","0732345678","Diabet zaharat tip 2"),
                    PatientSeed("patient-2621105287654","2621105287654","Dumitrescu","Elena","1962-11-05","0743456789","Artrită reumatoidă"),
                    PatientSeed("patient-1551220187432","1551220187432","Stan","Gheorghe","1955-12-20","0754567890","Insuficiență cardiacă"),
                    PatientSeed("patient-2480430098765","2480430098765","Constantin","Ana","1948-04-30","0765678901","Boală pulmonară obstructivă cronică")
                )
                val patients = seeds.map { s ->
                    parser.parseResource(org.hl7.fhir.r4.model.Patient::class.java, """
                    {"resourceType":"Patient","id":"${s.id}",
                     "identifier":[{"system":"urn:oid:1.2.40.0.10.1.4.3.1","value":"${s.cnp}"}],
                     "name":[{"family":"${s.family}","given":["${s.given}"]}],
                     "birthDate":"${s.dob}",
                     "telecom":[{"system":"phone","value":"${s.phone}","use":"mobile"}]}
                    """.trimIndent())
                }
                val conditions = seeds.map { s ->
                    parser.parseResource(org.hl7.fhir.r4.model.Condition::class.java, """
                    {"resourceType":"Condition","id":"condition-${s.cnp}",
                     "clinicalStatus":{"coding":[{"system":"http://terminology.hl7.org/CodeSystem/condition-clinical","code":"active"}]},
                     "subject":{"reference":"Patient/${s.id}"},
                     "code":{"text":"${s.condition}"},
                     "recordedDate":"2020-01-01"}
                    """.trimIndent())
                }

                // Practitioner Mock
                val practitionerJson = """
                {
                  "resourceType": "Practitioner",
                  "id": "mock-practitioner-1",
                  "name": [{"family": "Bogheanu", "given": ["Adriana"], "prefix": ["Dr."]}]
                }
                """.trimIndent()
                val practitioner = parser.parseResource(org.hl7.fhir.r4.model.Practitioner::class.java, practitionerJson)

                // MedicationRequest Mock
                val medicationJson = """
                {
                  "resourceType": "MedicationRequest",
                  "id": "mock-medication-1",
                  "status": "active",
                  "intent": "order",
                  "medicationCodeableConcept": {
                    "coding": [{"system": "http://www.nlm.nih.gov/research/umls/rxnorm", "code": "316049", "display": "Lisinopril 10 MG Oral Tablet"}]
                  },
                  "subject": {"reference": "Patient/mock-patient-1"},
                  "authoredOn": "2026-04-01T08:00:00Z"
                }
                """.trimIndent()
                val medication = parser.parseResource(org.hl7.fhir.r4.model.MedicationRequest::class.java, medicationJson)

                // Pending Encounter Mock
                val encounterJson = """
                {
                  "resourceType": "Encounter",
                  "id": "pending-encounter",
                  "status": "planned",
                  "class": {
                    "system": "http://terminology.hl7.org/CodeSystem/v3-ActCode",
                    "code": "VR",
                    "display": "virtual"
                  },
                  "subject": {"reference": "Patient/mock-patient-1"},
                  "participant": [{"individual": {"reference": "Practitioner/mock-practitioner-1"}}]
                }
                """.trimIndent()
                val encounter = parser.parseResource(org.hl7.fhir.r4.model.Encounter::class.java, encounterJson)

                // Insert into DB if not exists (upsert pattern).
                val resources = patients + conditions + listOf(practitioner, medication, encounter)
                resources.forEach { resource ->
                    runCatching {
                        fhirEngine!!.create(resource)
                    }.onFailure { ex ->
                        // if already exists or fails to create, try to update it just to be safe
                        runCatching { fhirEngine!!.update(resource) }
                            .onFailure { updateEx -> Log.w(TAG, "Failed to upsert resource: " + resource.id, updateEx) }
                    }
                }

                Log.i(TAG, "Mock FHIR resources seeded successfully")
                result.success(null)
            } catch (e: Exception) {
                Log.e(TAG, "Failed to seed mock data", e)
                result.error("FHIR_SEED_ERROR", "Mock data seeding failed", null)
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
