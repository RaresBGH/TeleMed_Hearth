// Licensed under the Creative Commons Attribution 4.0 International License (CC-BY 4.0)
// You may obtain a copy of the License at https://creativecommons.org/licenses/by/4.0/

import 'package:flutter/material.dart';
import 'package:telemed_k/ui/screens/home_screen.dart';

class DeviceConflictModal extends StatelessWidget {
  const DeviceConflictModal({super.key});

  void _onConfirm(BuildContext context) {
    // Placeholder Medplum session revocation
    debugPrint('Medplum session revoked for old device.');
    
    // Route directly to home_screen
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const HomeScreen()),
      (route) => false,
    );
  }

  void _onCancel(BuildContext context) {
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(
        automaticallyImplyLeading: false, // Rule enforced: no X or back arrow
        backgroundColor: const Color(0xFFF5F5F5),
        elevation: 0,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Spacer(),
              // Visual Icon Anchor
              Container(
                width: 120,
                height: 120,
                decoration: const BoxDecoration(
                  color: Color(0xFFE8E8E8), // surface-container-high
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.phonelink_erase, // closest match
                  size: 64,
                  color: Color(0xFF5BA4CF), // primary
                ),
              ),
              const SizedBox(height: 32),
              
              const Text(
                'Cont Activ pe Alt Telefon',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Color(0xFF000000),
                  fontSize: 32,
                  fontWeight: FontWeight.w900,
                  height: 1.1,
                ),
              ),
              const SizedBox(height: 24),
              
              // Explanation text using RichText to respect bolding
              RichText(
                textAlign: TextAlign.center,
                text: const TextSpan(
                  style: TextStyle(
                    color: Color(0xFF000000),
                    fontSize: 22,
                    height: 1.4,
                  ),
                  children: [
                    TextSpan(text: 'Am detectat că folosiți alt telefon. Doriți să mutați contul aici?\n\n'),
                    TextSpan(
                      text: 'Celălalt telefon va fi deconectat.',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ),
              const Spacer(),
              
              // Footer buttons
              Container(
                padding: const EdgeInsets.symmetric(vertical: 24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Primary Button: "Da, Mută Contul Aici"
                    ElevatedButton(
                      onPressed: () => _onConfirm(context),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF5BA4CF),
                        foregroundColor: Colors.white,
                        minimumSize: const Size(double.infinity, 72), // Enforce >= 64x64 dp
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                          side: const BorderSide(color: Color(0xFF000000), width: 2), // Accessibility standard outline
                        ),
                        elevation: 0,
                      ),
                      child: const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.swap_horiz, size: 28, color: Colors.white),
                          SizedBox(width: 12),
                          Text(
                            'Da, Mută Contul Aici',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    
                    // Secondary Button: "Anulează"
                    ElevatedButton(
                      onPressed: () => _onCancel(context),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFAB1118), // tertiary red
                        foregroundColor: Colors.white,
                        minimumSize: const Size(double.infinity, 72), // Enforce >= 64x64 dp
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                          side: const BorderSide(color: Color(0xFF000000), width: 3), // CSS `border-[3px]`
                        ),
                        elevation: 0,
                      ),
                      child: const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.close, size: 28, color: Colors.white),
                          SizedBox(width: 12),
                          Text(
                            'Anulează',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    
                    const Text(
                      'Acțiunea este securizată și protejează datele dumneavoastră.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Color(0xFF5E5E5E),
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
