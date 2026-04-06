// Licensed under the Creative Commons Attribution 4.0 International License (CC-BY 4.0)
// You may obtain a copy of the License at https://creativecommons.org/licenses/by/4.0/

import 'package:flutter/material.dart';

class VideoConsultationScreen extends StatelessWidget {
  const VideoConsultationScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Center(
        child: Text(
          'Video Feed Active',
          style: TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.bold),
        ),
      ),
    );
  }
}
