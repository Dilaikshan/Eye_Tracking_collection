import 'package:eye_tracking_collection/core/constants/app_colors.dart';
import 'package:flutter/material.dart';

class AccessibleTextField extends StatelessWidget {
  const AccessibleTextField({
    super.key,
    required this.controller,
    required this.label,
    this.keyboardType,
  });

  final TextEditingController controller;
  final String label;
  final TextInputType? keyboardType;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      style: const TextStyle(color: AppColors.textPrimary, fontSize: 18),
      decoration: InputDecoration(
        labelText: label,
      ),
    );
  }
}
