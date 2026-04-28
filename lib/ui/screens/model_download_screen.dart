// Licensed under the Creative Commons Attribution 4.0 International License (CC-BY 4.0)
// You may obtain a copy of the License at https://creativecommons.org/licenses/by/4.0/
//
// TeleMed_K: Offline-first telemedicine app for seniors

import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers/app_navigation_provider.dart';
import '../../core/services/ai_engine_service.dart';
import '../../data/repositories/fhir_repository.dart';

enum _DownloadState { idle, downloading, success, error }

class ModelDownloadScreen extends ConsumerStatefulWidget {
  const ModelDownloadScreen({super.key});

  @override
  ConsumerState<ModelDownloadScreen> createState() => _ModelDownloadScreenState();
}

class _ModelDownloadScreenState extends ConsumerState<ModelDownloadScreen> {
  static const _downloadChannel = MethodChannel('com.telemed_k/model_download');

  _DownloadState _downloadState = _DownloadState.idle;
  bool _isWifi = false;
  bool _isMobile = false;
  double _progress = 0.0;
  int _progressPercent = 0;
  String? _errorMessage;

  Timer? _progressTimer;
  Timer? _wifiTimer;

  @override
  void initState() {
    super.initState();
    _checkConnectivity();
    // Re-check connectivity every 5 seconds so the banner updates automatically.
    _wifiTimer = Timer.periodic(const Duration(seconds: 5), (_) => _checkConnectivity());
  }

  @override
  void dispose() {
    _progressTimer?.cancel();
    _wifiTimer?.cancel();
    super.dispose();
  }

  // ──────────────────────────────────────────────────────────────────────────
  // Connectivity check
  // ──────────────────────────────────────────────────────────────────────────

  Future<void> _checkConnectivity() async {
    try {
      final results = await Connectivity().checkConnectivity();
      final isWifi   = results.contains(ConnectivityResult.wifi);
      final isMobile = results.contains(ConnectivityResult.mobile);
      if (mounted) {
        setState(() {
          final hadConnection = _isWifi || _isMobile;
          final hasConnection = isWifi  || isMobile;
          _isWifi   = isWifi;
          _isMobile = isMobile;
          // Clear error state when connectivity is restored.
          if (!hadConnection && hasConnection &&
              _downloadState == _DownloadState.error) {
            _downloadState = _DownloadState.idle;
            _errorMessage  = null;
          }
        });
      }
    } catch (_) {}
  }

  // ──────────────────────────────────────────────────────────────────────────
  // Download control
  // ──────────────────────────────────────────────────────────────────────────

  Future<void> _startDownload() async {
    if (_downloadState == _DownloadState.downloading ||
        _downloadState == _DownloadState.success) {
      return;
    }

    setState(() {
      _downloadState = _DownloadState.downloading;
      _progress = 0.0;
      _progressPercent = 0;
      _errorMessage = null;
    });

    try {
      await _downloadChannel.invokeMethod<void>('startDownload');
    } on PlatformException catch (e) {
      if (mounted) {
        setState(() {
          _downloadState = _DownloadState.error;
          _errorMessage = 'Eroare la pornirea descărcării: ${e.code}';
        });
      }
      return;
    }

    // Poll download progress every 2 seconds via DownloadManager query.
    _progressTimer = Timer.periodic(
      const Duration(seconds: 2),
      (_) => _pollProgress(),
    );
  }

  Future<void> _pollProgress() async {
    try {
      final raw = await _downloadChannel.invokeMethod<Map>('getDownloadProgress');
      if (raw == null || !mounted) return;

      final int status = (raw['status'] as num?)?.toInt() ?? 0;
      final int bytesDownloaded = (raw['bytesDownloaded'] as num?)?.toInt() ?? 0;
      final int totalBytes = (raw['totalBytes'] as num?)?.toInt() ?? 1;

      if (status == 8) {
        // STATUS_SUCCESSFUL — file is on disk
        _progressTimer?.cancel();
        setState(() {
          _progress = 1.0;
          _progressPercent = 100;
          _downloadState = _DownloadState.success;
        });
        await _onDownloadComplete();
        return;
      }

      if (status == 16) {
        // STATUS_FAILED — include native error reason if available
        _progressTimer?.cancel();
        if (mounted) {
          final reason = raw['errorReason'] as String?;
          setState(() {
            _downloadState = _DownloadState.error;
            _errorMessage = reason != null
                ? 'Descărcarea a eșuat ($reason). Verificați conexiunea WiFi și încercați din nou.'
                : 'Descărcarea a eșuat. Verificați conexiunea WiFi și încercați din nou.';
          });
        }
        return;
      }

      // STATUS_RUNNING (2) or STATUS_PAUSED (4) — update progress bar
      if (totalBytes > 0) {
        final double newProgress =
            (bytesDownloaded / totalBytes).clamp(0.0, 1.0);
        final int newPercent = (newProgress * 100).toInt();
        if (mounted) {
          setState(() {
            _progress = newProgress;
            _progressPercent = newPercent;
          });
        }
      }
    } catch (_) {
      // Polling errors are non-fatal; next tick will retry.
    }
  }

  Future<void> _onDownloadComplete() async {
    // Kick off model init in the background — the AI status indicator on the
    // home screen handles the not-ready → ready transition independently.
    unawaited(AiEngineService(FhirRepository()).initializeModel());
    // Navigate within 2 s of STATUS_SUCCESS landing on the Dart side.
    await Future.delayed(const Duration(milliseconds: 1500));
    if (!mounted) return;
    ref.read(appNavigationProvider.notifier).navigateTo(AppRoute.home);
  }

  // ──────────────────────────────────────────────────────────────────────────
  // Build
  // ──────────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final bool canDownload = _downloadState != _DownloadState.downloading;
    final bool showProgress = _downloadState == _DownloadState.downloading ||
        _downloadState == _DownloadState.success;

    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 40.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const SizedBox(height: 16),

              // ── App icon ──────────────────────────────────────────────────
              Container(
                width: 100,
                height: 100,
                decoration: BoxDecoration(
                  color: const Color(0xFF5BA4CF).withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.health_and_safety,
                  size: 60,
                  color: Color(0xFF5BA4CF),
                ),
              ),
              const SizedBox(height: 32),

              // ── Title ─────────────────────────────────────────────────────
              const Text(
                'Pregătim asistentul medical',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: Colors.black,
                  height: 1.2,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),

              // ── Subtitle ──────────────────────────────────────────────────
              const Text(
                'Se descarcă asistentul virtual. Aceasta este o operațiune ce va avea loc o singură dată, la crearea contului.',
                style: TextStyle(
                  fontSize: 18,
                  color: Colors.black87,
                  height: 1.5,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 32),

              // ── Progress bar + percentage ─────────────────────────────────
              if (showProgress) ...[
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: LinearProgressIndicator(
                    value: _progress,
                    minHeight: 14,
                    backgroundColor: const Color(0xFFE0E0E0),
                    valueColor: const AlwaysStoppedAnimation<Color>(
                      Color(0xFF5BA4CF),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  '$_progressPercent% descărcat',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.black,
                  ),
                ),
                const SizedBox(height: 8),
              ],

              // ── File size hint ────────────────────────────────────────────
              const Text(
                'Dimensiune: ~2.4 GB',
                style: TextStyle(fontSize: 16, color: Colors.grey),
              ),
              const SizedBox(height: 20),

              // ── WiFi status banner ────────────────────────────────────────
              _WifiBanner(
                isWifi: _isWifi,
                isMobile: _isMobile,
                isDownloading: _downloadState == _DownloadState.downloading,
              ),
              const SizedBox(height: 24),

              // ── Error message ─────────────────────────────────────────────
              if (_downloadState == _DownloadState.error &&
                  _errorMessage != null) ...[
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.red.shade50,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.red.shade300, width: 1.5),
                  ),
                  child: Text(
                    _errorMessage!,
                    style: const TextStyle(fontSize: 16, color: Colors.red),
                    textAlign: TextAlign.center,
                  ),
                ),
                const SizedBox(height: 16),
              ],

              // ── Main action button — hidden permanently after success ─────
              if (_downloadState != _DownloadState.success) ...[
                Semantics(
                  button: true,
                  label: _downloadState == _DownloadState.downloading
                      ? 'Se descarcă modelul AI, vă rugăm așteptați'
                      : _downloadState == _DownloadState.error
                          ? 'Încearcă din nou descărcarea modelului AI'
                          : 'Descarcă modelul AI pe dispozitiv',
                  child: SizedBox(
                    width: double.infinity,
                    height: 72,
                    child: ElevatedButton(
                      onPressed: canDownload ? _startDownload : null,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF5BA4CF),
                        disabledBackgroundColor: Colors.grey.shade400,
                        foregroundColor: Colors.white,
                        disabledForegroundColor: Colors.white70,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                          side: BorderSide(
                            color: canDownload ? Colors.black : Colors.transparent,
                            width: 2,
                          ),
                        ),
                        elevation: 0,
                      ),
                      child: _downloadState == _DownloadState.downloading
                          ? const Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                SizedBox(
                                  width: 24,
                                  height: 24,
                                  child: CircularProgressIndicator(
                                    color: Colors.white,
                                    strokeWidth: 3,
                                  ),
                                ),
                                SizedBox(width: 16),
                                Text(
                                  'SE DESCARCĂ...',
                                  style: TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            )
                          : Text(
                              _downloadState == _DownloadState.error
                                  ? 'ÎNCEARCĂ DIN NOU'
                                  : 'DESCARCĂ ACUM',
                              style: const TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 1.5,
                              ),
                            ),
                    ),
                  ),
                ),
                const SizedBox(height: 32),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

// ──────────────────────────────────────────────────────────────────────────────
// WiFi status banner — extracted to keep build() readable
// ──────────────────────────────────────────────────────────────────────────────

class _WifiBanner extends StatelessWidget {
  final bool isWifi;
  final bool isMobile;
  final bool isDownloading;

  const _WifiBanner({
    required this.isWifi,
    required this.isMobile,
    required this.isDownloading,
  });

  @override
  Widget build(BuildContext context) {
    // Green: WiFi active
    if (isWifi) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.green.shade50,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.green.shade400, width: 1.5),
        ),
        child: Row(
          children: [
            Icon(Icons.wifi, color: Colors.green.shade700, size: 28),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'WiFi activ — descărcarea este sigură',
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.green.shade800,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      );
    }

    // Orange: mobile data — soft warning, download still allowed
    if (isMobile) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.orange.shade50,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.orange.shade400, width: 1.5),
        ),
        child: Row(
          children: [
            Icon(Icons.signal_cellular_alt, color: Colors.orange.shade800, size: 28),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'Descărcare prin date mobile - pot fi aplicate costuri',
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.orange.shade900,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      );
    }

    // Amber: no connection
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.amber.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.amber.shade700, width: 1.5),
      ),
      child: Row(
        children: [
          Icon(Icons.wifi_off, color: Colors.amber.shade800, size: 28),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              isDownloading
                  ? 'Conexiune pierdută în timpul descărcării'
                  : 'Fără conexiune la internet',
              style: TextStyle(
                fontSize: 16,
                color: Colors.amber.shade900,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
