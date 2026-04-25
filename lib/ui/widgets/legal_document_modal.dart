// Licensed under the Creative Commons Attribution 4.0 International License (CC-BY 4.0)
// You may obtain a copy of the License at https://creativecommons.org/licenses/by/4.0/
//
// TeleMed_K: Offline-first telemedicine app for seniors

import 'dart:ui';
import 'package:flutter/material.dart';

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

  static const Color _primary = Color(0xFF5BA4CF);
  static const Color _bg      = Color(0xFFF9F9F9);
  static const Color _surface = Color(0xFFF3F3F3);
  static const Color _surfaceHigh = Color(0xFFE8E8E8);
  static const Color _onSurface  = Color(0xFF1A1C1C);
  static const Color _onSurfaceVariant = Color(0xFF40493D);

  // ── Terms of Use ──────────────────────────────────────────────────────────

  Widget _buildTerms(BuildContext context) {
    return _Shell(
      title: 'Termeni de Utilizare',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Hero card
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: _surface,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const [
                Text(
                  'Respectul față de datele dumneavoastră',
                  style: TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.w900,
                    color: _onSurface,
                    height: 1.2,
                  ),
                ),
                SizedBox(height: 12),
                Text(
                  'Acest document definește regulile de utilizare ale serviciului nostru, '
                  'conceput special pentru a oferi o experiență sigură și demnă.',
                  style: TextStyle(
                    fontSize: 18,
                    color: _onSurfaceVariant,
                    height: 1.6,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 32),

          _Section(
            number: '1.',
            heading: 'Acceptarea Termenilor',
            body: 'Prin accesarea și utilizarea acestei aplicații, confirmați că ați citit, '
                'înțeles și sunteți de acord cu acești termeni. Serviciul nostru este dedicat '
                'exclusiv utilizării personale, oferind suport pentru sănătate și monitorizare '
                'zilnică, respectând cele mai înalte standarde de etică digitală.',
          ),
          _Section(
            number: '2.',
            heading: 'Confidențialitatea Datelor',
            body: 'Protecția informațiilor dumneavoastră este prioritatea noastră absolută. '
                'Nu vindem și nu partajăm datele dumneavoastră medicale sau personale cu '
                'terțe părți în scopuri publicitare. Toate datele sunt stocate criptat și '
                'sunt folosite exclusiv pentru a vă oferi asistența necesară.',
          ),
          _Section(
            number: '3.',
            heading: 'Responsabilitatea Utilizatorului',
            body: 'Sunteți responsabil pentru menținerea confidențialității contului '
                'dumneavoastră. Vă rugăm să ne notificați imediat în cazul oricărei '
                'utilizări neautorizate. Aplicația nu înlocuiește sfatul medical profesionist, '
                'ci servește ca un instrument auxiliar de monitorizare a stării de bine.',
          ),
          _Section(
            number: '4.',
            heading: 'Modificări ale Serviciului',
            body: 'Ne rezervăm dreptul de a actualiza acești termeni pentru a reflecta '
                'schimbările în legislație sau îmbunătățirile aduse tehnologiei noastre. '
                'Orice modificare majoră va fi comunicată clar printr-o notificare în cadrul '
                'aplicației, oferindu-vă timpul necesar pentru a revizui noile condiții.',
          ),
          _Section(
            number: '5.',
            heading: 'Limitarea Răspunderii',
            body: 'În limita permisă de lege, echipa noastră nu va fi responsabilă pentru '
                'daune indirecte sau accidentale care rezultă din utilizarea serviciului. '
                'Ne angajăm să oferim un serviciu stabil, însă nu putem garanta '
                'disponibilitatea neîntreruptă în perioadele de mentenanță critică.',
          ),
        ],
      ),
    );
  }

  // ── Privacy Policy ────────────────────────────────────────────────────────

  Widget _buildPrivacy(BuildContext context) {
    return _Shell(
      title: 'Politica de Confidențialitate',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _Section(
            number: '1.',
            heading: 'Angajamentul Nostru',
            body: 'Protecția datelor dumneavoastră medicale este prioritatea noastră absolută. '
                'Înțelegem responsabilitatea pe care o avem în gestionarea informațiilor '
                'sensibile legate de sănătatea dumneavoastră și ne angajăm să respectăm cele '
                'mai înalte standarde de securitate și confidențialitate, conform '
                'Regulamentului General privind Protecția Datelor (GDPR).',
          ),
          const SizedBox(height: 8),

          // Section 2 — bullet list
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: _surface,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '2. Ce date colectăm?',
                  style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: _primary,
                      height: 1.2),
                ),
                const SizedBox(height: 12),
                const Text(
                  'Pentru a vă oferi cea mai bună îngrijire și asistență, colectăm '
                  'următoarele categorii de date:',
                  style: TextStyle(fontSize: 18, color: _onSurface, height: 1.6),
                ),
                const SizedBox(height: 16),
                _bullet('Informații de identificare: Nume, prenume și data nașterii.'),
                _bullet('Date de contact: Număr de telefon și adresa de domiciliu.'),
                _bullet(
                    'Informații medicale: Istoric medical, tratamente curente și observații ale medicului.'),
              ],
            ),
          ),
          const SizedBox(height: 24),

          _Section(
            number: '3.',
            heading: 'Scopul Prelucrării',
            body: 'Datele dumneavoastră sunt utilizate exclusiv pentru:',
          ),
          Row(
            children: [
              Expanded(
                child: _InfoCard(
                  heading: 'Monitorizare Sănătate',
                  body: 'Urmărirea parametrilor vitali și a evoluției stării de bine.',
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _InfoCard(
                  heading: 'Comunicare Medic',
                  body: 'Facilitarea legăturii directe cu personalul medical autorizat.',
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),

          // Section 4 — left-border rights
          const Text(
            '4. Drepturile Dumneavoastră',
            style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: _primary,
                height: 1.2),
          ),
          const SizedBox(height: 8),
          const Text(
            'În calitate de utilizator, aveți drepturi depline asupra informațiilor dumneavoastră:',
            style: TextStyle(fontSize: 18, color: _onSurface, height: 1.6),
          ),
          const SizedBox(height: 16),
          _RightItem(
            heading: 'Dreptul de acces',
            body: 'Puteți solicita oricând o copie a datelor pe care le deținem.',
          ),
          _RightItem(
            heading: 'Dreptul la rectificare',
            body: 'Puteți corecta orice informație eronată din profilul dumneavoastră.',
          ),
          _RightItem(
            heading: 'Dreptul de a fi uitat',
            body: 'Puteți solicita ștergerea definitivă a contului și a datelor asociate.',
          ),
          const SizedBox(height: 8),

          _Section(
            number: '5.',
            heading: 'Securitatea Datelor',
            body: 'Utilizăm tehnologii de criptare de ultimă generație pentru a ne asigura '
                'că nimeni în afară de dumneavoastră și medicul dumneavoastră nu are acces '
                'la aceste informații. Serverele noastre sunt securizate și monitorizate '
                '24 de ore din 24.',
          ),

          // Section 6 — contact with inline primary-color email
          const Text(
            '6. Contact',
            style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: _primary,
                height: 1.2),
          ),
          const SizedBox(height: 8),
          RichText(
            text: const TextSpan(
              style: TextStyle(
                  fontSize: 18,
                  color: _onSurface,
                  height: 1.6,
                  fontFamily: 'Lexend'),
              children: [
                TextSpan(
                  text: 'Pentru orice întrebări legate de confidențialitatea datelor '
                      'dumneavoastră, ne puteți contacta la adresa de email: ',
                ),
                TextSpan(
                  text: 'protectie.date@digital-concierge.ro',
                  style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: _primary),
                ),
                TextSpan(
                    text: ' sau la numărul de telefon afișat în secțiunea de asistență.'),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Generic fallback ──────────────────────────────────────────────────────

  Widget _buildGeneric(BuildContext context) {
    return _Shell(
      title: title,
      child: Text(
        content,
        style: const TextStyle(
          fontSize: 18,
          color: _onSurface,
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

  // ── Helpers ───────────────────────────────────────────────────────────────

  static Widget _bullet(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('•',
              style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: _primary)),
          const SizedBox(width: 12),
          Expanded(
            child: Text(text,
                style: const TextStyle(
                    fontSize: 18, color: _onSurface, height: 1.5)),
          ),
        ],
      ),
    );
  }
}

// ── Private layout widgets ─────────────────────────────────────────────────

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

/// A numbered section with a primary-coloured heading and body text.
class _Section extends StatelessWidget {
  final String number;
  final String heading;
  final String body;

  const _Section({
    required this.number,
    required this.heading,
    required this.body,
  });

  static const Color _primary = Color(0xFF5BA4CF);
  static const Color _onSurface = Color(0xFF1A1C1C);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '$number $heading',
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: _primary,
              height: 1.2,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            body,
            style: const TextStyle(
                fontSize: 18, color: _onSurface, height: 1.6),
          ),
        ],
      ),
    );
  }
}

/// Surface-container-high card used in the "Scopul Prelucrării" grid.
class _InfoCard extends StatelessWidget {
  final String heading;
  final String body;

  const _InfoCard({required this.heading, required this.body});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFE8E8E8),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(heading,
              style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1A1C1C))),
          const SizedBox(height: 6),
          Text(body,
              style: const TextStyle(
                  fontSize: 18, color: Color(0xFF1A1C1C), height: 1.5)),
        ],
      ),
    );
  }
}

/// Left-border right item used in "Drepturile Dumneavoastră".
class _RightItem extends StatelessWidget {
  final String heading;
  final String body;

  const _RightItem({required this.heading, required this.body});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.fromLTRB(16, 8, 8, 8),
      decoration: const BoxDecoration(
        border: Border(
          left: BorderSide(color: Color(0xFF5BA4CF), width: 4),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(heading,
              style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1A1C1C))),
          const SizedBox(height: 4),
          Text(body,
              style: const TextStyle(
                  fontSize: 18, color: Color(0xFF1A1C1C), height: 1.5)),
        ],
      ),
    );
  }
}
