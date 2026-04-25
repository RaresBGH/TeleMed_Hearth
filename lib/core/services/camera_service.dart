// Licensed under the Creative Commons Attribution 4.0 International License (CC-BY 4.0)
// You may obtain a copy of the License at https://creativecommons.org/licenses/by/4.0/
//
// TeleMed_K: Offline-first telemedicine app for seniors

import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:video_compress/video_compress.dart';

/// Handles camera capture for triage sessions.
///
/// Image flow (LiteRT-LM inference):
///   captureImage() → opens system camera, compresses JPEG at quality 85,
///                    saves to tmp/telemed_img_{ts}.jpg, returns path for
///                    immediate Content.ImageFile() inference.
///
/// Video flow (Medplum storage only — no LiteRT-LM video API):
///   captureVideo() → opens system camera, returns original path immediately,
///                    fires async VideoCompress.compressVideo() (LowQuality MP4).
///                    Compressed path available via [lastCompressedVideoPath].
class CameraService {
  final ImagePicker _picker = ImagePicker();
  String? _lastCompressedVideoPath;

  /// Compressed video path set after async compression completes.
  /// Null until the compression triggered by [captureVideo] finishes.
  String? get lastCompressedVideoPath => _lastCompressedVideoPath;

  /// Requests camera permission. Returns true if granted.
  Future<bool> requestPermission() async {
    try {
      final status = await Permission.camera.request();
      return status == PermissionStatus.granted;
    } catch (e) {
      debugPrint('CameraService.requestPermission error: $e');
      return false;
    }
  }

  /// Opens the system camera and captures a JPEG image.
  /// Saves to [getTemporaryDirectory()]/telemed_img_{timestamp}.jpg at quality 85.
  /// Returns the file path for immediate LiteRT-LM inference via Content.ImageFile.
  /// Returns null on cancellation or any error.
  Future<String?> captureImage() async {
    try {
      final xFile = await _picker.pickImage(
        source: ImageSource.camera,
        imageQuality: 85,   // JPEG quality — matches Medplum storage requirement
      );
      if (xFile == null) return null; // user cancelled

      // Copy to a deterministic temp path with timestamp so callers can
      // manage the file lifecycle independently of image_picker's cache.
      final tmpDir = await getTemporaryDirectory();
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final destPath = '${tmpDir.path}/telemed_img_$timestamp.jpg';
      await File(xFile.path).copy(destPath);

      debugPrint('CameraService: image captured → $destPath');
      return destPath;
    } catch (e) {
      debugPrint('CameraService.captureImage error: $e');
      return null;
    }
  }

  /// Opens the system camera and captures a video.
  /// Returns the original (uncompressed) path immediately — video is NOT
  /// passed to LiteRT-LM (no Content.VideoFile API exists in LiteRT-LM).
  /// Kicks off async MP4/H264 compression for Medplum storage;
  /// [lastCompressedVideoPath] is set when compression completes.
  /// Returns null on cancellation or any error.
  Future<String?> captureVideo() async {
    try {
      final xFile = await _picker.pickVideo(source: ImageSource.camera);
      if (xFile == null) return null; // user cancelled

      final originalPath = xFile.path;
      debugPrint('CameraService: video captured → $originalPath');

      // Compress asynchronously — does not block the return path.
      _compressVideo(originalPath);

      return originalPath;
    } catch (e) {
      debugPrint('CameraService.captureVideo error: $e');
      return null;
    }
  }

  /// Deletes a temporary capture file after inference or sync is complete.
  Future<void> deleteTempFile(String path) async {
    try {
      final file = File(path);
      if (file.existsSync()) {
        await file.delete();
        debugPrint('CameraService: temp file deleted → $path');
      }
    } catch (e) {
      debugPrint('CameraService.deleteTempFile error: $e');
    }
  }

  // ──────────────────────────────────────────────────────────────────────────
  // Internal: async video compression via video_compress
  // ──────────────────────────────────────────────────────────────────────────

  Future<void> _compressVideo(String videoPath) async {
    try {
      final info = await VideoCompress.compressVideo(
        videoPath,
        quality: VideoQuality.LowQuality, // smallest output; sufficient for medical record
        deleteOrigin: false,              // keep original until Medplum confirms upload
        includeAudio: true,
      );

      if (info?.path != null) {
        _lastCompressedVideoPath = info!.path;
        debugPrint('CameraService: video compressed → ${info.path}');
      } else {
        debugPrint('CameraService: video compression returned null path');
      }
    } catch (e) {
      debugPrint('CameraService._compressVideo error: $e');
    }
  }

  void dispose() {
    VideoCompress.dispose();
  }
}

final cameraServiceProvider = Provider<CameraService>((ref) {
  final service = CameraService();
  ref.onDispose(service.dispose);
  return service;
});
