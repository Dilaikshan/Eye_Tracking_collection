import 'package:eye_tracking_collection/core/constants/app_colors.dart';
import 'package:flutter/material.dart';

class PulsingTarget extends StatefulWidget {
  const PulsingTarget({super.key, this.color});

  final Color? color;

  @override
  State<PulsingTarget> createState() => _PulsingTargetState();
}

class _PulsingTargetState extends State<PulsingTarget>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);
    _scale = Tween<double>(begin: 0.7, end: 1.1).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ScaleTransition(
      scale: _scale,
      child: Container(
        width: 48,
        height: 48,
        decoration: BoxDecoration(
          color: widget.color ?? AppColors.target,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: (widget.color ?? AppColors.target).withOpacity(0.9),
              blurRadius: 18,
              spreadRadius: 4,
            ),
          ],
        ),
      ),
    );
  }
}
