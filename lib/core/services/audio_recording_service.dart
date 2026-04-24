// Licensed under the Creative Commons Attribution 4.0 International License (CC-BY 4.0)
// You may obtain a copy of the License at https://creativecommons.org/licenses/by/4.0/
//
// TeleMed_K: Offline-first telemedicine app for seniors

import 'dart:io';

import 'package:ffmpeg_kit_flutter_min_gpl/ffmpeg_kit.dart';
import 'package:ffmpeg_kit_flutter_min_gpl/return_code.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:record/record.dart';

/// Handles microphone recording for triage sessions.
///
/// WAV flow (LiteRT-LM inference):
///   startRecording() → records to tmp/telemed_audio_{ts}.wav (16kHz, mono, 16-bit)
///   stopRecording()  → stops, returns WAV path immediately for inference
///
/// AAC flow (Medplum storage):
///   After stopRecording() returns, a background ffmpeg transcode begins.
///   When complete, [lastAacPath] is set to recordings/audio_{ts}.aac.
class AudioRecordingService {
  final AudioRecorder _recorder = AudioRecorder();

  String? _lastAacPath;

  /// AAC path produced by the last successful transcode.
  /// Null until transcoding completes after [stopRecording].
  String? get lastAacPath => _lastAacPath;

  /// Requests microphone permission. Returns true if granted.
  Future<bool> requestPermission() async {
    try {
      // record package also handles permission, but permission_handler gives
      // us explicit rationale control before the system dialog appears.
      final status = await Permission.microphone.request();
      return status == PermissionStatus.granted;
    } catch (e) {
      debugPrint('AudioRecordingService.requestPermission error: $e');
      return false;
    }
  }

  /// Starts recording to a WAV file.
  /// WAV spec: 16 kHz, mono, 16-bit PCM — matches LiteRT-LM AudioPreprocessor USM config.
  /// Throws if permission is not granted.
  Future<void> startRecording() async {
    try {
      final tmpDir = await getTemporaryDirectory();
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final wavPath = '${tmpDir.path}/telemed_audio_$timestamp.wav';

      await _recorder.start(
        const RecordConfig(
          encoder: AudioEncoder.wav,
          sampleRate: 16000,  // matches AudioPreprocessorConfig.CreateDefaultUsmConfig()
          numChannels: 1,     // mono — USM config requirement
          bitRate: 256000,    // 16-bit PCM at 16kHz = 256kbps
        ),
        path: wavPath,
      );
      debugPrint('AudioRecordingService: recording started → $wavPath');
    } catch (e) {
      debugPrint('AudioRecordingService.startRecording error: $e');
      rethrow;
    }
  }

  /// Stops recording. Returns the WAV file path for immediate LiteRT-LM inference.
  /// Returns empty string on error — caller must check before passing to inference.
  /// Kicks off async AAC transcoding after returning; [lastAacPath] will be set
  /// once transcoding completes.
  Future<String> stopRecording() async {
    try {
      final path = await _recorder.stop();
      if (path == null || path.isEmpty) {
        debugPrint('AudioRecordingService: stop returned null/empty path');
        return '';
      }
      debugPrint('AudioRecordingService: recording stopped → $path');
      // Transcode to AAC asynchronously — does NOT block the return.
      // The WAV is returned immediately so inference can begin.
      _transcodeToAac(path);
      return path;
    } catch (e) {
      debugPrint('AudioRecordingService.stopRecording error: $e');
      return '';
    }
  }

  /// Deletes the WAV file after LiteRT-LM inference is complete.
  /// WAV files are ~1.9 MB/min; delete promptly to avoid tmp bloat.
  Future<void> deleteWavFile(String path) async {
    try {
      final file = File(path);
      if (file.existsSync()) {
        await file.delete();
        debugPrint('AudioRecordingService: WAV deleted → $path');
      }
    } catch (e) {
      debugPrint('AudioRecordingService.deleteWavFile error: $e');
    }
  }

  // ──────────────────────────────────────────────────────────────────────────
  // Internal: WAV → AAC via ffmpeg_kit_flutter_min_gpl
  // ──────────────────────────────────────────────────────────────────────────

  Future<void> _transcodeToAac(String wavPath) async {
    try {
      final docsDir = await getApplicationDocumentsDirectory();
      final recordingsDir = Directory('${docsDir.path}/recordings');
      if (!recordingsDir.existsSync()) {
        recordingsDir.createSync(recursive: true);
      }

      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final aacPath = '${recordingsDir.path}/audio_$timestamp.aac';

      // -c:a aac           — AAC encoder (built into ffmpeg min-gpl)
      // -b:a 64k           — 64 kbps sufficient for speech; 16kHz mono input
      // -movflags faststart — moov atom at start (streaming-friendly M4A)
      // -y                 — overwrite if exists
      final session = await FFmpegKit.execute(
        '-i $wavPath -c:a aac -b:a 64k -movflags +faststart -y $aacPath',
      );

      final returnCode = await session.getReturnCode();
      if (ReturnCode.isSuccess(returnCode)) {
        _lastAacPath = aacPath;
        debugPrint('AudioRecordingService: AAC transcode complete → $aacPath');
      } else {
        final logs = await session.getAllLogsAsString();
        debugPrint('AudioRecordingService: AAC transcode failed — $logs');
      }
    } catch (e) {
      debugPrint('AudioRecordingService: _transcodeToAac error: $e');
    }
  }

  void dispose() {
    _recorder.dispose();
  }
}

final audioRecordingServiceProvider = Provider<AudioRecordingService>((ref) {
  final service = AudioRecordingService();
  ref.onDispose(service.dispose);
  return service;
});
