// Licensed under the Creative Commons Attribution 4.0 International License (CC-BY 4.0)
// You may obtain a copy of the License at https://creativecommons.org/licenses/by/4.0/

import 'package:flutter/material.dart';
import 'package:smart_auth/smart_auth.dart';
import 'package:telemed_k/ui/widgets/legal_document_modal.dart';
import 'package:telemed_k/ui/screens/home_screen.dart';

class LoginVerificationScreen extends StatefulWidget {
  const LoginVerificationScreen({super.key});

  @override
  State<LoginVerificationScreen> createState() => _LoginVerificationScreenState();
}

class _LoginVerificationScreenState extends State<LoginVerificationScreen> {
  final List<TextEditingController> _controllers = List.generate(6, (index) => TextEditingController());
  final List<FocusNode> _focusNodes = List.generate(6, (index) => FocusNode());

  @override
  void initState() {
    super.initState();
    _startSmsListener();
  }

  void _startSmsListener() async {
    final smartAuth = SmartAuth.instance;
    final res = await smartAuth.getSmsWithUserConsentApi();
    if (res.hasData && res.data?.code != null) {
      final code = res.data!.code!;
      if (code.length >= 6) {
        for (int i = 0; i < 6; i++) {
          _controllers[i].text = code[i];
        }
      }
    }
  }

  @override
  void dispose() {
    SmartAuth.instance.removeUserConsentApiListener();
    for (var controller in _controllers) {
      controller.dispose();
    }
    for (var node in _focusNodes) {
      node.dispose();
    }
    super.dispose();
  }

  void _onDigitChanged(String value, int index) {
    if (value.isNotEmpty && index < 5) {
      _focusNodes[index + 1].requestFocus();
    }
    if (value.isEmpty && index > 0) {
      _focusNodes[index - 1].requestFocus();
    }
  }

  void _openLegalModal(BuildContext context, String title, String content) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => LegalDocumentModal(title: title, content: content),
        fullscreenDialog: true,
      ),
    );
  }

  void _onConfirmAndCreateAccount() {
    // Navigating directly to home screen per instructions
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => const HomeScreen(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(
        automaticallyImplyLeading: false, // Rule enforced
        backgroundColor: const Color(0xFFF5F5F5),
        elevation: 0,
        title: const Text(
          'Verificare',
          style: TextStyle(
            color: Color(0xFF000000),
            fontSize: 22,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Introduceți codul din 6 cifre primit prin SMS',
                style: TextStyle(
                  color: Color(0xFF000000),
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  height: 1.2,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 48),
              
              // 6-digit OTP fields
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: List.generate(6, (index) {
                  return SizedBox(
                    width: 50,
                    height: 70, // Massive 50x70 bounding box 
                    child: TextField(
                      controller: _controllers[index],
                      focusNode: _focusNodes[index],
                      keyboardType: TextInputType.number,
                      textAlign: TextAlign.center,
                      maxLength: 1,
                      style: const TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF000000),
                      ),
                      onChanged: (value) => _onDigitChanged(value, index),
                      decoration: InputDecoration(
                        counterText: '',
                        filled: true,
                        fillColor: Colors.white,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: Color(0xFF000000), width: 2),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: Color(0xFF2E7D32), width: 4),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: Color(0xFF000000), width: 2),
                        ),
                      ),
                    ),
                  );
                }),
              ),
              
              const SizedBox(height: 64),
              
              // Visual Context Card
              Container(
                decoration: BoxDecoration(
                  color: const Color(0xFFF3F3F3),
                  borderRadius: BorderRadius.circular(12),
                  border: const Border(
                    left: BorderSide(color: Color(0xFF0D631B), width: 8),
                  ),
                ),
                padding: const EdgeInsets.all(24),
                child: const Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.security,
                      color: Color(0xFF0D631B),
                      size: 32,
                    ),
                    SizedBox(width: 16),
                    Expanded(
                      child: Text(
                        'Siguranța datelor dumneavoastră este prioritatea noastră. Prin acest cod, confirmăm identitatea dumneavoastră pentru a vă proteja dosarul medical.',
                        style: TextStyle(
                          color: Color(0xFF000000),
                          fontSize: 18,
                          height: 1.5,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              
              const SizedBox(height: 64),
              
              // Call to Action
              ElevatedButton(
                onPressed: _onConfirmAndCreateAccount,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF0D631B),
                  foregroundColor: Colors.white,
                  minimumSize: const Size(double.infinity, 80), // Rule enforced: Massive button
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: const BorderSide(color: Colors.black, width: 2),
                  ),
                  elevation: 0,
                ),
                child: const Text(
                  'SUNT DE ACORD CU TERMENII - CREEAZĂ CONT',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              
              const SizedBox(height: 32),
              
              GestureDetector(
                onTap: _startSmsListener,
                child: const Text(
                  'Nu ați primit codul? Trimite din nou',
                  style: TextStyle(
                    color: Color(0xFF000000),
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    decoration: TextDecoration.underline,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
              
              const SizedBox(height: 48),
              
              // Legal Documents
              Column(
                children: [
                  ElevatedButton(
                    onPressed: () => _openLegalModal(
                      context,
                      'Termeni de Utilizare',
                      'Placeholder pentru Termeni de Utilizare.\n\n1. Acceptarea Termenilor\nPrin accesarea și utilizarea acestei aplicații, confirmați că ați citit, înțeles și sunteți de acord cu acești termeni. Serviciul nostru este dedicat exclusiv utilizării personale, oferind suport pentru sănătate și monitorizare zilnică, respectând cele mai înalte standarde de etică digitală.\n\n2. Confidențialitatea Datelor\nProtecția informațiilor dumneavoastră este prioritatea noastră absolută.',
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFF5F5F5),
                      foregroundColor: const Color(0xFF000000),
                      minimumSize: const Size(double.infinity, 64), // Rule enforced
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                        side: const BorderSide(color: Colors.black, width: 2),
                      ),
                      elevation: 0,
                    ),
                    child: const Text(
                      '📖 Termeni de Utilizare',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () => _openLegalModal(
                      context,
                      'Politica de Confidențialitate',
                      'Placeholder pentru Politica de Confidențialitate.\n\nModul de stocare al datelor:\nToate datele medicale sunt stocate local pe dispozitiv via Google Android FHIR SDK SQLCipher.\n\nFără Telemetrie Ascunsă:\nInference-ul se realizează exclusiv On-Device utilizând rețeaua neuronală LiteRT-LM (Gemma 4 E2B). Nu vor exista apeluri către servere cloud pentru procesarea RAG.\n',
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFF5F5F5),
                      foregroundColor: const Color(0xFF000000),
                      minimumSize: const Size(double.infinity, 64), // Rule enforced
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                        side: const BorderSide(color: Colors.black, width: 2),
                      ),
                      elevation: 0,
                    ),
                    child: const Text(
                      '🔒 Politica de Confidențialitate',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
              
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}
