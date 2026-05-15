// Licensed under the Creative Commons Attribution 4.0 International License (CC-BY 4.0)
// You may obtain a copy of the License at https://creativecommons.org/licenses/by/4.0/

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/l10n/app_strings.dart';
import '../../core/providers/auth_provider.dart';
import '../../core/providers/language_provider.dart';
import '../../core/providers/medical_session_provider.dart';
import '../../core/utils/fhir_extension_utils.dart';

class ObservationThreadScreen extends ConsumerStatefulWidget {
  final String observationId;
  final Map<String, dynamic> observation;

  const ObservationThreadScreen({
    super.key,
    required this.observationId,
    required this.observation,
  });

  @override
  ConsumerState<ObservationThreadScreen> createState() => _ObservationThreadScreenState();
}

class _ObservationThreadScreenState extends ConsumerState<ObservationThreadScreen> {
  final _textController = TextEditingController();
  final _scrollController = ScrollController();

  List<Map<String, dynamic>> _communications = [];
  bool _loading = true;
  bool _sending = false;
  late String _noteText;
  late bool _isReviewed;

  static const _brandBlue = Color(0xFF5BA4CF);

  @override
  void initState() {
    super.initState();
    _noteText = ((widget.observation['note'] as List?)?.firstOrNull?['text'] as String?) ?? '';
    final status = widget.observation['status'] as String?;
    final exts = (widget.observation['extension'] as List?) ?? [];
    _isReviewed = status == 'final' ||
        exts.any((e) => (e['url'] as String? ?? '').contains('reviewed-by'));
    _loadThread();
  }

  @override
  void dispose() {
    _textController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadThread() async {
    setState(() => _loading = true);
    try {
      final cnp = ref.read(loginCnpProvider);
      final comms = await ref.read(fhirRepositoryProvider).getCommunications(
        cnp: cnp,
        aboutReference: 'Observation/${widget.observationId}',
      );
      comms.sort((a, b) {
        final aS = a['sent'] as String? ?? '';
        final bS = b['sent'] as String? ?? '';
        return aS.compareTo(bS);
      });
      if (!mounted) return;
      setState(() {
        _communications = comms;
        _loading = false;
      });
      _scrollToBottom();
    } catch (_) {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _send() async {
    final text = _textController.text.trim();
    if (text.isEmpty || _sending) return;
    _textController.clear();
    setState(() => _sending = true);
    try {
      final cnp = ref.read(loginCnpProvider);
      await ref.read(fhirRepositoryProvider).saveCommunication(
        patientCnp: cnp,
        observationId: widget.observationId,
        text: text,
        isPatient: true,
        timestamp: DateTime.now(),
      );
      if (!mounted) return;
      await _loadThread();
    } catch (_) {
      if (!mounted) return;
    }
    setState(() => _sending = false);
  }

  bool _isPatientMessage(Map<String, dynamic> comm) {
    final exts = (comm['extension'] as List?) ?? [];
    return exts.any((e) =>
        (e['url'] == FhirExtensionUtils.isPatientUrl || e['url'] == 'isPatient') &&
        e['valueBoolean'] == true);
  }

  @override
  Widget build(BuildContext context) {
    final lang = ref.watch(languageProvider);
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(
        title: Text(AppStrings.of(lang, 'thread.title'),
            style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 20)),
        backgroundColor: const Color(0xFFF5F5F5),
        elevation: 0,
        foregroundColor: Colors.black,
      ),
      body: _isReviewed ? _buildLockedView(lang) : _buildThreadView(lang),
    );
  }

  Widget _buildLockedView(String lang) {
    final valueString = widget.observation['valueString'] as String? ?? '';
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (valueString.isNotEmpty) ...[
            Text(valueString,
                style: const TextStyle(fontSize: 16, color: Color(0xFF40484E), height: 1.5)),
            const SizedBox(height: 20),
          ],
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFFF3F3F3),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              AppStrings.of(lang, 'dossier.conversation_locked'),
              style: const TextStyle(fontSize: 14, color: Color(0xFF40484E)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildThreadView(String lang) {
    return Column(
      children: [
        Expanded(
          child: _loading
              ? const Center(child: CircularProgressIndicator(color: _brandBlue))
              : ListView(
                  controller: _scrollController,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  children: [
                    // Original triage transcript block
                    if (_noteText.isNotEmpty) _buildTranscriptBlock(lang),
                    const SizedBox(height: 8),
                    // Communication bubbles
                    if (_communications.isEmpty)
                      Center(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          child: Text(
                            AppStrings.of(lang, 'thread.no_messages'),
                            style: const TextStyle(fontSize: 14, color: Color(0xFF40484E)),
                          ),
                        ),
                      )
                    else
                      ..._communications.map((comm) => _buildBubble(comm, lang)),
                  ],
                ),
        ),
        _buildInputRow(lang),
      ],
    );
  }

  Widget _buildTranscriptBlock(String lang) {
    final lines = _noteText.split('\n')
        .where((l) => l.trim().isNotEmpty)
        .toList();
    return Container(
      margin: const EdgeInsets.only(bottom: 4),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF0F0F0),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFE0E0E0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: lines.map((line) {
          Color textColor = const Color(0xFF40484E);
          if (line.startsWith('[AI]') || line.startsWith('[Doctor]')) textColor = const Color(0xFF1A6495);
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 2),
            child: Text(
              line.replaceAll(RegExp(r'^\[[^\]]+\]\s*\d+:\d+:\s*'), '').trim(),
              style: TextStyle(fontSize: 13, color: textColor, height: 1.4),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildBubble(Map<String, dynamic> comm, String lang) {
    final isPatient = _isPatientMessage(comm);
    final text = (comm['payload'] as List?)?.firstOrNull?['contentString'] as String? ?? '';
    final sentStr = comm['sent'] as String? ?? '';
    String timeLabel = '';
    if (sentStr.isNotEmpty) {
      final dt = DateTime.tryParse(sentStr)?.toLocal();
      if (dt != null) {
        timeLabel = '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
      }
    }
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Align(
        alignment: isPatient ? Alignment.centerRight : Alignment.centerLeft,
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.78),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: isPatient ? _brandBlue : Colors.white,
              borderRadius: BorderRadius.only(
                topLeft:     Radius.circular(isPatient ? 18 : 4),
                topRight:    Radius.circular(isPatient ? 4 : 18),
                bottomLeft:  const Radius.circular(18),
                bottomRight: const Radius.circular(18),
              ),
              boxShadow: const [BoxShadow(color: Color(0x0A000000), blurRadius: 4, offset: Offset(0, 2))],
            ),
            child: Column(
              crossAxisAlignment: isPatient ? CrossAxisAlignment.end : CrossAxisAlignment.start,
              children: [
                Text(text,
                    style: TextStyle(
                        fontSize: 15,
                        color: isPatient ? Colors.white : const Color(0xFF1A1C1C),
                        height: 1.4)),
                if (timeLabel.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(timeLabel,
                      style: TextStyle(
                          fontSize: 11,
                          color: isPatient ? Colors.white70 : const Color(0xFF40484E))),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildInputRow(String lang) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      decoration: const BoxDecoration(
        color: Colors.white,
        boxShadow: [BoxShadow(color: Color(0x0F000000), blurRadius: 8, offset: Offset(0, -2))],
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _textController,
              style: const TextStyle(fontSize: 15),
              decoration: InputDecoration(
                hintText: AppStrings.of(lang, 'thread.input_placeholder'),
                hintStyle: const TextStyle(color: Color(0xFF90989F)),
                filled: true,
                fillColor: const Color(0xFFF5F5F5),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              ),
              onSubmitted: (_) => _send(),
            ),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: _send,
            child: Container(
              width: 44, height: 44,
              decoration: BoxDecoration(
                color: _sending ? const Color(0xFFC4C4C4) : _brandBlue,
                shape: BoxShape.circle,
              ),
              child: _sending
                  ? const Center(child: SizedBox(width: 20, height: 20,
                      child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)))
                  : const Icon(Icons.send_rounded, color: Colors.white, size: 20),
            ),
          ),
        ],
      ),
    );
  }
}
