// Licensed under the Creative Commons Attribution 4.0 International License (CC-BY 4.0)
// You may obtain a copy of the License at https://creativecommons.org/licenses/by/4.0/
//
// TeleMed Hearth: Offline-first telemedicine app for seniors

package com.example.telemed_k.channels

import android.content.Context
import android.media.MediaCodec
import android.media.MediaCodecInfo
import android.media.MediaFormat
import android.util.Log
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext
import java.io.BufferedOutputStream
import java.io.File
import java.io.FileOutputStream
import java.io.OutputStream

/**
 * Native handler for the `com.telemed_k/audio_transcode` MethodChannel.
 *
 * Transcodes a 16kHz/mono/16-bit PCM WAV file to AAC (ADTS container)
 * using Android's built-in MediaCodec — no FFmpeg, no third-party libs.
 *
 * Runs entirely on Dispatchers.IO; never blocks the UI thread.
 *
 * Methods handled:
 *   transcodeWavToAac — { inputPath: String, outputPath: String }
 *                       → returns outputPath String on success, null on failure
 */
class AudioTranscodeChannel(
    @Suppress("UNUSED_PARAMETER") private val context: Context
) : MethodChannel.MethodCallHandler {

    companion object {
        const val CHANNEL_NAME = "com.telemed_k/audio_transcode"
        private const val TAG = "AudioTranscodeChannel"

        // WAV standard RIFF header is always 44 bytes for PCM files
        // produced by the `record` Flutter package.
        private const val WAV_HEADER_SIZE = 44

        // Must match the RecordConfig in AudioRecordingService.dart
        private const val SAMPLE_RATE = 16000
        private const val CHANNEL_COUNT = 1
        private const val BIT_RATE = 64000           // 64 kbps — sufficient for mono speech

        private const val INPUT_CHUNK_SIZE = 8192     // 8 KB PCM chunks
        private const val TIMEOUT_US = 10_000L        // 10 ms dequeue timeout
    }

    private val scope = CoroutineScope(SupervisorJob() + Dispatchers.IO)

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "transcodeWavToAac" -> handleTranscodeWavToAac(call, result)
            else -> result.notImplemented()
        }
    }

    // ─────────────────────────────────────────────────────────────────────────
    // transcodeWavToAac
    // ─────────────────────────────────────────────────────────────────────────

    private fun handleTranscodeWavToAac(call: MethodCall, result: MethodChannel.Result) {
        val inputPath = call.argument<String>("inputPath")
            ?: return result.error("INVALID_ARG", "Missing 'inputPath'", null)
        val outputPath = call.argument<String>("outputPath")
            ?: return result.error("INVALID_ARG", "Missing 'outputPath'", null)

        scope.launch {
            try {
                val success = transcodeWavToAac(inputPath, outputPath)
                withContext(Dispatchers.Main) {
                    result.success(if (success) outputPath else null)
                }
            } catch (e: Exception) {
                Log.e(TAG, "Unexpected transcode error", e)
                withContext(Dispatchers.Main) {
                    result.success(null)
                }
            }
        }
    }

    // ─────────────────────────────────────────────────────────────────────────
    // Core MediaCodec encoding: WAV PCM → AAC (ADTS container)
    // ─────────────────────────────────────────────────────────────────────────

    private fun transcodeWavToAac(inputPath: String, outputPath: String): Boolean {
        val inputFile = File(inputPath)
        if (!inputFile.exists()) {
            Log.e(TAG, "Input WAV not found: $inputPath")
            return false
        }

        // Read all PCM bytes at once and skip the 44-byte RIFF/WAV header.
        // Files produced by record@6.x are standard WAV (RIFF, fmt, data chunks).
        val rawBytes = inputFile.readBytes()
        if (rawBytes.size <= WAV_HEADER_SIZE) {
            Log.e(TAG, "WAV too small to contain PCM data: ${rawBytes.size} bytes")
            return false
        }
        val pcm = rawBytes.copyOfRange(WAV_HEADER_SIZE, rawBytes.size)
        Log.d(TAG, "PCM data: ${pcm.size} bytes from $inputPath")

        // Ensure output directory exists
        File(outputPath).parentFile?.mkdirs()

        // Configure MediaFormat: AAC-LC, 16kHz, mono, 64kbps
        val format = MediaFormat.createAudioFormat(
            MediaFormat.MIMETYPE_AUDIO_AAC,
            SAMPLE_RATE,
            CHANNEL_COUNT,
        )
        format.setInteger(MediaFormat.KEY_BIT_RATE, BIT_RATE)
        format.setInteger(
            MediaFormat.KEY_AAC_PROFILE,
            MediaCodecInfo.CodecProfileLevel.AACObjectLC,
        )
        format.setInteger(MediaFormat.KEY_MAX_INPUT_SIZE, INPUT_CHUNK_SIZE)

        val codec = MediaCodec.createEncoderByType(MediaFormat.MIMETYPE_AUDIO_AAC)
        codec.configure(format, null, null, MediaCodec.CONFIGURE_FLAG_ENCODE)
        codec.start()

        val bufferInfo = MediaCodec.BufferInfo()
        val fos = BufferedOutputStream(FileOutputStream(outputPath))

        var inputOffset = 0
        var eosInput = false
        var eosOutput = false

        return try {
            while (!eosOutput) {
                // ── Feed input ─────────────────────────────────────────────
                if (!eosInput) {
                    val idx = codec.dequeueInputBuffer(TIMEOUT_US)
                    if (idx >= 0) {
                        val inBuf = codec.getInputBuffer(idx)!!
                        inBuf.clear()
                        if (inputOffset < pcm.size) {
                            val chunk = minOf(INPUT_CHUNK_SIZE, pcm.size - inputOffset)
                            inBuf.put(pcm, inputOffset, chunk)
                            codec.queueInputBuffer(idx, 0, chunk, 0L, 0)
                            inputOffset += chunk
                        } else {
                            // All PCM fed — signal end of stream
                            codec.queueInputBuffer(
                                idx, 0, 0, 0L,
                                MediaCodec.BUFFER_FLAG_END_OF_STREAM,
                            )
                            eosInput = true
                        }
                    }
                }

                // ── Drain output ───────────────────────────────────────────
                val outIdx = codec.dequeueOutputBuffer(bufferInfo, TIMEOUT_US)
                when {
                    outIdx == MediaCodec.INFO_TRY_AGAIN_LATER -> Unit // nothing ready yet
                    outIdx == MediaCodec.INFO_OUTPUT_FORMAT_CHANGED -> Unit // codec initialised
                    outIdx >= 0 -> {
                        if (bufferInfo.size > 0) {
                            val outBuf = codec.getOutputBuffer(outIdx)!!
                            val aacFrame = ByteArray(bufferInfo.size)
                            outBuf.get(aacFrame)
                            // Prepend 7-byte ADTS header before each AAC Access Unit
                            writeAdtsHeader(fos, aacFrame.size)
                            fos.write(aacFrame)
                        }
                        codec.releaseOutputBuffer(outIdx, false)
                        if (bufferInfo.flags and MediaCodec.BUFFER_FLAG_END_OF_STREAM != 0) {
                            eosOutput = true
                        }
                    }
                }
            }
            fos.flush()
            Log.i(TAG, "Transcode complete: $outputPath (${File(outputPath).length()} bytes)")
            true
        } catch (e: Exception) {
            Log.e(TAG, "MediaCodec encoding error", e)
            false
        } finally {
            fos.close()
            codec.stop()
            codec.release()
        }
    }

    // ─────────────────────────────────────────────────────────────────────────
    // ADTS header — 7 bytes, no CRC
    // Spec: ISO 13818-7 §6.2  (MPEG-4 AAC, AAC-LC profile, 16kHz, mono)
    //
    // Byte 0:     Syncword[11:4]                 = 0xFF
    // Byte 1:     Syncword[3:0] ID Layer ProtAbs = 0xF1  (MPEG-4, no CRC)
    // Byte 2:     Profile[1:0] FreqIdx[3:0] Priv ChannMSB
    //             Profile = AAC-LC → stored as (2-1)=1 = 0b01
    //             FreqIdx = 16kHz → index 8 = 0b1000
    //             ChannConfig = mono = 1 = 0b001; MSB = 0
    //             → 0b01_1000_0_0 = 0x60
    // Byte 3:     ChannLSBs[1:0] OC Home CIB CIS FrameLen[12:11]
    //             ChannLSBs = 0b01; all flags = 0
    //             → 0x40 | (frameLength >> 11)
    // Byte 4:     FrameLen[10:3] = (frameLength >> 3) & 0xFF
    // Byte 5:     FrameLen[2:0] BuffFull[10:6]
    //             BuffFull = 0x7FF (VBR) → top 5 bits = 0b11111 = 0x1F
    //             → ((frameLength & 7) << 5) | 0x1F
    // Byte 6:     BuffFull[5:0] NumBlocks[1:0]
    //             BuffFull lower 6 bits = 0b111111; NumBlocks = 0 (1 frame)
    //             → 0xFC
    // ─────────────────────────────────────────────────────────────────────────
    private fun writeAdtsHeader(out: OutputStream, dataLength: Int) {
        val frameLength = dataLength + 7 // total ADTS frame including this header
        out.write(0xFF)
        out.write(0xF1)
        out.write(0x60)
        out.write(0x40 or (frameLength shr 11))
        out.write((frameLength shr 3) and 0xFF)
        out.write(((frameLength and 7) shl 5) or 0x1F)
        out.write(0xFC)
    }
}
