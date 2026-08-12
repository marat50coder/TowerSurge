import 'package:flutter/material.dart';

import '../core/palette.dart';

/// Yellow/black construction tape used as a separator above the controls.
class HazardStrip extends StatelessWidget {
  const HazardStrip({super.key, this.height = 10, this.stripeWidth = 12});

  final double height;
  final double stripeWidth;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: height,
      width: double.infinity,
      child: CustomPaint(painter: _HazardPainter(stripeWidth: stripeWidth)),
    );
  }
}

class _HazardPainter extends CustomPainter {
  _HazardPainter({required this.stripeWidth});

  final double stripeWidth;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(Offset.zero & size, Paint()..color = P.hazardYellow);
    final paint = Paint()
      ..color = P.hazardBlack
      ..style = PaintingStyle.fill;
    canvas.save();
    canvas.clipRect(Offset.zero & size);
    final step = stripeWidth * 2;
    for (var x = -size.height; x < size.width + size.height; x += step) {
      final path = Path()
        ..moveTo(x, size.height)
        ..lineTo(x + size.height, 0)
        ..lineTo(x + size.height + stripeWidth, 0)
        ..lineTo(x + stripeWidth, size.height)
        ..close();
      canvas.drawPath(path, paint);
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _HazardPainter oldDelegate) =>
      oldDelegate.stripeWidth != stripeWidth;
}

/// Dark diagonal texture of the top status bar.
class TopBarTexture extends StatelessWidget {
  const TopBarTexture({super.key});

  @override
  Widget build(BuildContext context) => CustomPaint(painter: _TopBarPainter());
}

class _TopBarPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(Offset.zero & size, Paint()..color = P.topBar);
    final paint = Paint()..color = P.topBarDark;
    const stripe = 9.0;
    canvas.save();
    canvas.clipRect(Offset.zero & size);
    for (var x = -size.height; x < size.width + size.height; x += stripe * 2) {
      final path = Path()
        ..moveTo(x, size.height)
        ..lineTo(x + size.height, 0)
        ..lineTo(x + size.height + stripe, 0)
        ..lineTo(x + stripe, size.height)
        ..close();
      canvas.drawPath(path, paint);
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
