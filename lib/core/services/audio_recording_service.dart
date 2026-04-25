// Licensed under the Creative Commons Attribution 4.0 International License (CC-BY 4.0)
// You may obtain a copy of the License at https://creativecommons.org/licenses/by/4.0/
//
// TeleMed_K: Offline-first telemedicine app for seniors

import 'dart:io';

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
///   Transcoding is handled by AudioTranscodeChannel (Kotlin MediaCodec).
///   [lastAacPath] returns null until that channel is wired.
class AudioRecordingService {
  final AudioRecorder _recorder = AudioRecorder();

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
      // TODO: WAV→AAC transcoding handled by AudioTranscodeChannel (Kotlin MediaCodec)
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

  void dispose() {
    _recorder.dispose();
  }
}

final audioRecordingServiceProvider = Provider<AudioRecordingService>((ref) {
  final service = AudioRecordingService();
  ref.onDispose(service.dispose);
  return service;
});
