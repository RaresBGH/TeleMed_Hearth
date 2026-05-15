// Licensed under the Creative Commons Attribution 4.0 International License (CC-BY 4.0)
// You may obtain a copy of the License at https://creativecommons.org/licenses/by/4.0/
//
// TeleMed Hearth: Offline-first telemedicine app for seniors

import 'dart:io';

import 'package:flutter/material.dart';

/// Full-screen image viewer used by chat bubbles in both
/// [MedicalResponseScreen] and [VideoConsultationScreen].
class ImagePreviewScreen extends StatelessWidget {
  final String imagePath;
  final String title;

  const ImagePreviewScreen({
    super.key,
    required this.imagePath,
    required this.title,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        iconTheme: const IconThemeData(color: Colors.white),
        title: Text(title, style: const TextStyle(color: Colors.white)),
      ),
      body: Center(
        child: InteractiveViewer(
          child: Image.file(
            File(imagePath),
            errorBuilder: (_, __, ___) =>
                const Icon(Icons.broken_image, size: 64, color: Colors.grey),
          ),
        ),
      ),
    );
  }
}
