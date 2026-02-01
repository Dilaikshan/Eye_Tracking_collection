import 'package:flutter/material.dart';

class AlignmentGuide extends StatelessWidget {
  final bool isAligned;
  final double width;
  final double height;

  const AlignmentGuide({
    super.key,
    required this.isAligned,
    this.width = 240,
    this.height = 320,
  });

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      ignoring: true,
      child: SizedBox(
        width: width,
        height: height,
        child: CustomPaint(
          painter: _GuidePainter(
            color: isAligned ? Colors.greenAccent : Colors.redAccent,
          ),
        ),
      ),
    );
  }
}

class _GuidePainter extends CustomPainter {
  final Color color;

  _GuidePainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color.withOpacity(0.7)
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;

    // Draw outer rectangle
    final rect = Rect.fromLTWH(0, 0, size.width, size.height);
    canvas.drawRect(rect, paint);

    // Draw crosshair
    canvas.drawLine(
      Offset(size.width / 2, 0),
      Offset(size.width / 2, size.height),
      paint,
    );
    canvas.drawLine(
      Offset(0, size.height / 2),
      Offset(size.width, size.height / 2),
      paint,
    );

    // Draw face oval guide
    final ovalRect = Rect.fromCenter(
      center: Offset(size.width / 2, size.height / 2),
      width: size.width * 0.6,
      height: size.height * 0.7,
    );
    canvas.drawOval(ovalRect, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
