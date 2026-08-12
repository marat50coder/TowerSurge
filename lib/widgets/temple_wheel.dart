import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../core/palette.dart';
import '../core/sfx.dart';

/// Temple Floor bonus: a ten segment wheel that boosts the running total.
class TempleWheel extends StatefulWidget {
  const TempleWheel({super.key, required this.onDone});

  final void Function(double value) onDone;

  /// Segment layout of the bonus wheel.
  static const List<double> segments = [1.5, 3, 2, 5, 1.5, 7, 2, 2, 3, 5];

  @override
  State<TempleWheel> createState() => _TempleWheelState();
}

class _TempleWheelState extends State<TempleWheel>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final int _target;
  late final double _totalTurn;

  @override
  void initState() {
    super.initState();
    final rng = math.Random();
    _target = rng.nextInt(TempleWheel.segments.length);
    final segment = 2 * math.pi / TempleWheel.segments.length;
    _totalTurn =
        6 * 2 * math.pi + (2 * math.pi - (_target * segment + segment / 2));
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3400),
    );
    Sfx.i.play(Sfx.levelUp);
    _controller.forward().whenComplete(() {
      Sfx.i.play(Sfx.win);
      Future.delayed(const Duration(milliseconds: 900), () {
        if (!mounted) return;
        widget.onDone(TempleWheel.segments[_target]);
      });
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    final diameter = math.min(width * 0.82, 340.0);
    return Container(
      color: const Color(0xA6000814),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              'TEMPLE FLOOR',
              style: T.black(
                width * 0.075,
                color: Colors.white,
                shadows: const [
                  Shadow(
                    color: Color(0xCC0A2033),
                    offset: Offset(0, 3),
                    blurRadius: 6,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Bonus wheel boost',
              style: T.bold(width * 0.038, color: const Color(0xFFCDE7FA)),
            ),
            const SizedBox(height: 18),
            SizedBox(
              width: diameter,
              height: diameter + 18,
              child: AnimatedBuilder(
                animation: _controller,
                builder: (context, _) {
                  final angle =
                      Curves.easeOutQuart.transform(_controller.value) *
                      _totalTurn;
                  return CustomPaint(painter: _WheelPainter(angle));
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _WheelPainter extends CustomPainter {
  _WheelPainter(this.angle);

  final double angle;

  @override
  void paint(Canvas canvas, Size size) {
    final diameter = math.min(size.width, size.height - 18);
    final center = Offset(size.width / 2, 18 + diameter / 2);
    final radius = diameter / 2;
    final segments = TempleWheel.segments;
    final sweep = 2 * math.pi / segments.length;

    canvas.drawCircle(
      center,
      radius + 7,
      Paint()..color = const Color(0xFF8A5A12),
    );
    canvas.drawCircle(center, radius + 4, Paint()..color = P.gold);

    for (var i = 0; i < segments.length; i++) {
      final start = -math.pi / 2 + i * sweep + angle;
      final value = segments[i];
      final paint = Paint()
        ..color = i.isEven ? const Color(0xFF2C6E45) : const Color(0xFF3E8F58);
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        start,
        sweep,
        true,
        paint,
      );
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        start,
        sweep,
        true,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2
          ..color = const Color(0x66FFE8A8),
      );

      final label =
          'x${value == value.roundToDouble() ? value.toInt() : value}';
      final painter = TextPainter(
        text: TextSpan(
          text: label,
          style: TextStyle(
            fontFamily: T.family,
            fontWeight: FontWeight.w900,
            fontSize: radius * 0.19,
            color: Colors.white,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      final mid = start + sweep / 2;
      final position = Offset(
        center.dx + math.cos(mid) * radius * 0.66,
        center.dy + math.sin(mid) * radius * 0.66,
      );
      // Keep every label upright as the wheel turns.
      var textAngle = mid + math.pi / 2;
      final normalized =
          (textAngle % (2 * math.pi) + 2 * math.pi) % (2 * math.pi);
      if (normalized > math.pi / 2 && normalized < 3 * math.pi / 2) {
        textAngle += math.pi;
      }
      canvas.save();
      canvas.translate(position.dx, position.dy);
      canvas.rotate(textAngle);
      painter.paint(canvas, Offset(-painter.width / 2, -painter.height / 2));
      canvas.restore();
    }

    canvas.drawCircle(center, radius * 0.17, Paint()..color = P.goldDark);
    canvas.drawCircle(center, radius * 0.13, Paint()..color = P.goldLight);

    final pointer = Path()
      ..moveTo(center.dx, center.dy - radius + 2)
      ..lineTo(center.dx - 13, center.dy - radius - 16)
      ..lineTo(center.dx + 13, center.dy - radius - 16)
      ..close();
    canvas.drawPath(pointer, Paint()..color = P.red);
    canvas.drawPath(
      pointer,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..color = Colors.white,
    );
  }

  @override
  bool shouldRepaint(covariant _WheelPainter oldDelegate) =>
      oldDelegate.angle != angle;
}
