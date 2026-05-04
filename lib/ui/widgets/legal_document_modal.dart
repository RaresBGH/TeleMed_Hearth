// Licensed under the Creative Commons Attribution 4.0 International License (CC-BY 4.0)
// You may obtain a copy of the License at https://creativecommons.org/licenses/by/4.0/
//
// TeleMed_K: Offline-first telemedicine app for seniors

import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../../core/constants/legal_content.dart';

/// Which legal document to display.
enum LegalDocumentType { terms, privacy }

/// Full-screen legal document viewer built from the Stitch designs.
///
/// Usage with enum (preferred — shows full Stitch content):
///   LegalDocumentModal(type: LegalDocumentType.terms)
///
/// Usage with raw strings (backward-compat — shows generic content):
///   LegalDocumentModal(title: 'My Title', content: 'My content...')
class LegalDocumentModal extends StatelessWidget {
  final LegalDocumentType? type;
  final String title;
  final String content;

  const LegalDocumentModal({
    super.key,
    this.type,
    this.title = '',
    this.content = '',
  });

  // ── Terms of Use — rendered via WebView ──────────────────────────────────

  Widget _buildTerms(BuildContext context) =>
      _WebShell(title: 'Termeni de Utilizare', html: kTermsHtml);

  // ── Privacy Policy — rendered via WebView ─────────────────────────────────

  Widget _buildPrivacy(BuildContext context) =>
      _WebShell(title: 'Politica de Confidențialitate', html: kPrivacyHtml);

  // ── Generic fallback ──────────────────────────────────────────────────────

  Widget _buildGeneric(BuildContext context) {
    return _Shell(
      title: title,
      child: Text(
        content,
        style: const TextStyle(
          fontSize: 18,
          color: Color(0xFF1A1C1C),
          height: 1.6,
        ),
      ),
    );
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    switch (type) {
      case LegalDocumentType.terms:
        return _buildTerms(context);
      case LegalDocumentType.privacy:
        return _buildPrivacy(context);
      case null:
        return _buildGeneric(context);
    }
  }

}

// ── Private layout widgets ─────────────────────────────────────────────────

/// Full-screen Scaffold that renders an HTML string via [WebViewWidget].
/// The Flutter AppBar provides a reliable back button; the HTML's own
/// in-page navigation buttons are non-functional (expected — read-only view).
class _WebShell extends StatefulWidget {
  final String title;
  final String html;
  const _WebShell({required this.title, required this.html});
  @override
  State<_WebShell> createState() => _WebShellState();
}

class _WebShellState extends State<_WebShell> {
  late final WebViewController _controller;

  @override
  void initState() {
    super.initState();
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..loadHtmlString(widget.html);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF9F9F9),
      appBar: AppBar(
        backgroundColor: const Color(0xFFF9F9F9),
        elevation: 0,
        centerTitle: true,
        leading: Semantics(
          button: true,
          label: 'Înapoi',
          child: SizedBox(
            height: 64,
            width: 64,
            child: IconButton(
              icon: const Icon(Icons.chevron_left, size: 32,
                  color: Color(0xFF5BA4CF)),
              onPressed: () => Navigator.of(context).pop(),
            ),
          ),
        ),
        title: Text(
          widget.title,
          style: const TextStyle(
            color: Color(0xFF1A1C1C),
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: WebViewWidget(controller: _controller),
    );
  }
}

/// Full-screen shell: AppBar + scrollable body + glassmorphism back button.
class _Shell extends StatelessWidget {
  final String title;
  final Widget child;

  const _Shell({required this.title, required this.child});

  static const Color _primary = Color(0xFF5BA4CF);
  static const Color _bg = Color(0xFFF9F9F9);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        automaticallyImplyLeading: false,
        backgroundColor: _bg,
        elevation: 0,
        centerTitle: true,
        title: Text(
          title,
          style: const TextStyle(
            color: Color(0xFF1A1C1C),
            fontSize: 22,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(24, 16, 24, 120),
        child: child,
      ),
      bottomNavigationBar: ClipRect(
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
          child: Container(
            color: Colors.white.withValues(alpha: 0.85),
            padding: EdgeInsets.fromLTRB(
              24,
              12,
              24,
              MediaQuery.of(context).padding.bottom + 12,
            ),
            child: Semantics(
              button: true,
              label: 'Înapoi',
              child: SizedBox(
                height: 64,
                child: ElevatedButton.icon(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.chevron_left, size: 32,
                      color: Colors.white),
                  label: const Text(
                    'Înapoi',
                    style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.white),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _primary,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                      side: const BorderSide(color: Colors.black, width: 2),
                    ),
                    elevation: 0,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
