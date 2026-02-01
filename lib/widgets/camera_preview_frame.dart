import 'package:flutter/material.dart';
import 'package:camera/camera.dart';

class CameraPreviewFrame extends StatelessWidget {
  final CameraController controller;
  final bool isAligned;

  const CameraPreviewFrame({
    super.key,
    required this.controller,
    required this.isAligned,
  });

  @override
  Widget build(BuildContext context) {
    if (!controller.value.isInitialized) {
      return Container(
        width: 260,
        height: 340,
        decoration: BoxDecoration(
          color: Colors.black,
          borderRadius: BorderRadius.circular(16),
        ),
        child: const Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    return Container(
      width: 260,
      height: 340,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Colors.black, Colors.black87],
        ),
        border: Border.all(
          color: isAligned ? Colors.greenAccent : Colors.redAccent,
          width: 3,
        ),
        boxShadow: [
          BoxShadow(
            color: (isAligned ? Colors.greenAccent : Colors.redAccent)
                .withOpacity(0.6),
            blurRadius: 24,
            spreadRadius: 8,
          ),
        ],
        borderRadius: BorderRadius.circular(16),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: CameraPreview(controller),
      ),
    );
  }
}
