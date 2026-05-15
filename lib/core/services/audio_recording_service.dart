// Licensed under the Creative Commons Attribution 4.0 International License (CC-BY 4.0)
// You may obtain a copy of the License at https://creativecommons.org/licenses/by/4.0/
//
// TeleMed Hearth: Offline-first telemedicine app for seniors

import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
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
///   After stopRecording() returns the WAV path, _transcodeToAac() is fired
///   and forgotten via unawaited(). It calls AudioTranscodeChannel (Kotlin
///   MediaCodec WAV→AAC) and stores the result in [lastAacPath].
class AudioRecordingService {
  final AudioRecorder _recorder = AudioRecorder();
  static const _transcodeChannel = MethodChannel('com.telemed_k/audio_transcode');

  String? _lastAacPath;

  /// AAC path for Medplum storage.
  /// Returns null — transcoding not yet wired (pending AudioTranscodeChannel).
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
      // Fire-and-forget: WAV is returned immediately for inference;
      // AAC transcode runs in background via AudioTranscodeChannel.
      unawaited(_transcodeToAac(path));
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

  Future<void> _transcodeToAac(String wavPath) async {
    try {
      final tmpDir = (await getTemporaryDirectory()).path;
      final docsDir = (await getApplicationDocumentsDirectory()).path;

      final aacPath = wavPath
          .replaceAll('telemed_audio_', 'telemed_archive_')
          .replaceAll('.wav', '.aac')
          .replaceAll(tmpDir, docsDir);

      final result = await _transcodeChannel.invokeMethod<String>(
        'transcodeWavToAac',
        {'inputPath': wavPath, 'outputPath': aacPath},
      );
      if (result != null) {
        _lastAacPath = aacPath;
        debugPrint('AudioRecordingService: AAC ready → $aacPath');
      } else {
        debugPrint('AudioRecordingService: transcode returned null (Kotlin error logged)');
      }
    } catch (e) {
      debugPrint('AudioRecordingService._transcodeToAac error: $e');
    }
  }

  /// Stops any active recording and releases the microphone resource.
  /// Safe to call when not recording — no-op in that case.
  /// Call from session reset, finalization, and screen dispose.
  Future<void> stopAndRelease() async {
    try {
      if (await _recorder.isRecording()) {
        await _recorder.stop();
        debugPrint('AudioRecordingService: recording stopped via stopAndRelease');
      }
      debugPrint('AudioRecordingService: microphone released');
    } catch (e) {
      debugPrint('AudioRecordingService.stopAndRelease error: $e');
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
