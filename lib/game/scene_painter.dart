import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../core/game_images.dart';
import '../core/palette.dart';
import 'tower_game.dart';

class ScenePainter extends CustomPainter {
  ScenePainter(this.game) : super(repaint: game.frame);

  final TowerGame game;

  @override
  void paint(Canvas canvas, Size size) {
    game.setViewport(size);
    final images = GameImages.i;
    if (!images.loaded) return;

    canvas.save();
    canvas.clipRect(Offset.zero & size);

    _paintSky(canvas, size);
    _paintClouds(canvas, size);
    _paintGround(canvas, size);

    for (final body in game.tower) {
      _paintBlock(canvas, body);
    }
    // Loose bodies fall in front of the tower they bounced off.
    for (final body in game.debris) {
      _paintBlock(canvas, body);
    }
    final flying = game.flying;
    if (flying != null) _paintBlock(canvas, flying);

    _paintCrane(canvas, size);
    _paintParticles(canvas);
    _paintPopups(canvas, size);

    canvas.restore();
  }

  // ------------------------------------------------------------------ backdrop

  void _paintSky(Canvas canvas, Size size) {
    final sprite = GameImages.i.sky;
    final dst = Offset.zero & size;
    final srcAspect = sprite.content.width / sprite.content.height;
    final dstAspect = size.width / size.height;
    Rect src;
    if (srcAspect > dstAspect) {
      final w = sprite.content.height * dstAspect;
      src = Rect.fromLTWH(
        sprite.content.left + (sprite.content.width - w) / 2,
        sprite.content.top,
        w,
        sprite.content.height,
      );
    } else {
      final h = sprite.content.width / dstAspect;
      src = Rect.fromLTWH(
        sprite.content.left,
        sprite.content.top + (sprite.content.height - h) * 0.35,
        sprite.content.width,
        h,
      );
    }
    canvas.drawImageRect(
      sprite.image,
      src,
      dst,
      Paint()..filterQuality = FilterQuality.medium,
    );
  }

  void _paintClouds(Canvas canvas, Size size) {
    final camWorld = game.camPx / (game.unit * game.scale);
    final paint = Paint()..filterQuality = FilterQuality.low;
    for (final cloud in game.clouds) {
      var y = cloud.y;
      final wraps = ((camWorld - y) / TowerGame.cloudSpan).floorToDouble();
      y += wraps * TowerGame.cloudSpan + TowerGame.cloudSpan;
      final drift = math.sin(game.time * cloud.speed * 6 + cloud.x * 9) * 0.06;
      final width = cloud.size * game.unit;
      final sprite = GameImages.i.clouds[cloud.sprite];
      final height = width / sprite.aspect;
      final center = game.toScreen(cloud.x + drift, y);
      final rect = Rect.fromCenter(
        center: Offset(center.dx, center.dy - game.camPx * 0.35),
        width: width,
        height: height,
      );
      if (rect.bottom < -40 || rect.top > size.height + 40) continue;
      paint.colorFilter = ColorFilter.mode(
        Colors.white.withValues(alpha: 0.72),
        BlendMode.modulate,
      );
      canvas.drawImageRect(sprite.image, sprite.content, rect, paint);
    }
  }

  void _paintGround(Canvas canvas, Size size) {
    final groundY = game.groundScreenY + game.shakeY;
    final unit = game.unit;

    // Warm sunset glow behind the store.
    final glowCenter = Offset(
      size.width / 2 + game.shakeX,
      groundY - unit * 0.22,
    );
    final glowRadius = unit * 0.72;
    canvas.drawCircle(
      glowCenter,
      glowRadius,
      Paint()
        ..shader = ui.Gradient.radial(
          glowCenter,
          glowRadius,
          [
            const Color(0x88FFD98A),
            const Color(0x22FFC46B),
            const Color(0x00FFC46B),
          ],
          [0.0, 0.55, 1.0],
        ),
    );

    final strip = GameImages.i.cityStrip;
    final stripWidth = size.width * 1.18;
    final stripHeight = stripWidth / strip.aspect;
    final stripRect = Rect.fromLTWH(
      (size.width - stripWidth) / 2 + game.shakeX,
      groundY - stripHeight,
      stripWidth,
      stripHeight,
    );
    if (stripRect.bottom > 0 && stripRect.top < size.height) {
      canvas.drawImageRect(
        strip.image,
        strip.content,
        stripRect,
        Paint()..filterQuality = FilterQuality.medium,
      );
    }

    if (groundY >= size.height) return;

    final dirtRect = Rect.fromLTWH(
      0,
      groundY,
      size.width,
      size.height - groundY + 4,
    );
    canvas.drawRect(
      dirtRect,
      Paint()
        ..shader = ui.Gradient.linear(
          dirtRect.topLeft,
          dirtRect.bottomLeft,
          const [Color(0xFF5A3D28), Color(0xFF3B2718), Color(0xFF20150D)],
          const [0.0, 0.4, 1.0],
        ),
    );
    canvas.drawRect(
      Rect.fromLTWH(0, groundY, size.width, 3),
      Paint()..color = const Color(0xFF23160E),
    );

    canvas.save();
    canvas.clipRect(dirtRect);
    final stonePaint = Paint();
    for (final stone in game.stones) {
      final center = Offset(
        size.width / 2 + stone.x * size.width + game.shakeX,
        groundY - stone.y * unit,
      );
      if (center.dy > size.height + 20) continue;
      final shade = stone.shade;
      stonePaint.color = Color.lerp(
        const Color(0xFF8A6B4E),
        const Color(0xFF3B2618),
        shade,
      )!;
      canvas.drawOval(
        Rect.fromCenter(
          center: center,
          width: stone.rx * 2 * unit,
          height: stone.ry * 2 * unit,
        ),
        stonePaint,
      );
      canvas.drawOval(
        Rect.fromCenter(
          center: center.translate(0, -stone.ry * unit * 0.35),
          width: stone.rx * 1.5 * unit,
          height: stone.ry * unit,
        ),
        Paint()..color = Colors.white.withValues(alpha: 0.06 + shade * 0.05),
      );
    }
    canvas.restore();
  }

  // -------------------------------------------------------------------- blocks

  void _paintBlock(Canvas canvas, BlockBody body) {
    final sprite = body.spriteData;
    final width = body.widthUnits * game.unit * game.scale;
    final height = width / sprite.aspect;
    final bottomCenter = game.toScreen(body.x, body.yBottom);
    final rect = Rect.fromLTWH(
      bottomCenter.dx - width / 2,
      bottomCenter.dy - height,
      width,
      height,
    );
    if (rect.bottom < -height || rect.top > game.viewport.height + height) {
      return;
    }

    final paint = Paint()..filterQuality = FilterQuality.medium;
    if (body.opacity < 1) {
      paint.colorFilter = ColorFilter.mode(
        Colors.white.withValues(alpha: body.opacity),
        BlendMode.modulate,
      );
    }

    // Contact shadow so stacked floors read as solid volumes.
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(bottomCenter.dx, bottomCenter.dy - height * 0.015),
        width: width * 0.86,
        height: height * 0.09,
      ),
      Paint()
        ..color = Colors.black.withValues(alpha: 0.16 * body.opacity)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, width * 0.03),
    );
    _drawSprite(canvas, sprite, rect, rotation: body.rotation, paint: paint);
  }

  void _drawSprite(
    Canvas canvas,
    Sprite sprite,
    Rect dst, {
    double rotation = 0,
    Paint? paint,
  }) {
    final p = paint ?? (Paint()..filterQuality = FilterQuality.medium);
    if (rotation == 0) {
      canvas.drawImageRect(sprite.image, sprite.content, dst, p);
      return;
    }
    canvas.save();
    canvas.translate(dst.center.dx, dst.center.dy);
    canvas.rotate(rotation);
    canvas.translate(-dst.center.dx, -dst.center.dy);
    canvas.drawImageRect(sprite.image, sprite.content, dst, p);
    canvas.restore();
  }

  // --------------------------------------------------------------------- crane

  void _paintCrane(Canvas canvas, Size size) {
    final anchor = game.hangAnchor();
    final hook = GameImages.i.hook;
    final hangingBlock = game.hangingBlockRect();

    final hookHeight = size.height * 0.34;
    final hookWidth = hookHeight * hook.aspect;
    final ropeGap = size.height * 0.035;
    final hookRect = Rect.fromLTWH(
      anchor.dx - hookWidth / 2,
      anchor.dy - ropeGap - hookHeight,
      hookWidth,
      hookHeight,
    );
    if (hookRect.bottom > -20) {
      canvas.drawImageRect(
        hook.image,
        hook.content,
        hookRect,
        Paint()..filterQuality = FilterQuality.medium,
      );
    }

    if (hangingBlock == null) return;

    final rect = hangingBlock.rect;
    final rope = Paint()
      ..color = const Color(0xFF23231F)
      ..strokeWidth = math.max(1.5, size.width * 0.005)
      ..strokeCap = StrokeCap.round;
    final tip = Offset(anchor.dx, anchor.dy - ropeGap * 0.35);
    final left = Offset(
      rect.left + rect.width * 0.16,
      rect.top + rect.height * 0.06,
    );
    final right = Offset(
      rect.right - rect.width * 0.16,
      rect.top + rect.height * 0.06,
    );
    canvas.save();
    canvas.translate(rect.center.dx, rect.center.dy);
    canvas.rotate(hangingBlock.rotation);
    canvas.translate(-rect.center.dx, -rect.center.dy);
    canvas.drawLine(tip, left, rope);
    canvas.drawLine(tip, right, rope);
    canvas.restore();

    _drawSprite(
      canvas,
      GameImages.i.blocks[game.hangSprite],
      rect,
      rotation: hangingBlock.rotation,
    );
  }

  // ----------------------------------------------------------------- particles

  void _paintParticles(Canvas canvas) {
    final paint = Paint()..filterQuality = FilterQuality.low;
    for (final particle in game.particles) {
      final t = particle.t;
      final alpha = (t < 0.25 ? t / 0.25 : 1 - (t - 0.25) / 0.75).clamp(
        0.0,
        1.0,
      );
      final sprite = GameImages.i.clouds[particle.sprite];
      final width = particle.size * game.unit * game.scale * (0.8 + t * 0.6);
      final height = width / sprite.aspect;
      final center = game.toScreen(particle.x, particle.y);
      final rect = Rect.fromCenter(
        center: center,
        width: width,
        height: height,
      );
      paint.colorFilter = ColorFilter.mode(
        const Color(0xFFF2EFE6).withValues(alpha: alpha * 0.92),
        BlendMode.modulate,
      );
      canvas.save();
      canvas.translate(center.dx, center.dy);
      canvas.rotate(particle.rotation);
      canvas.translate(-center.dx, -center.dy);
      canvas.drawImageRect(sprite.image, sprite.content, rect, paint);
      canvas.restore();
    }
  }

  // -------------------------------------------------------------------- popups

  void _paintPopups(Canvas canvas, Size size) {
    for (final popup in game.popups) {
      final t = popup.t;
      final grow = t < 0.16 ? Curves.easeOutBack.transform(t / 0.16) : 1.0;
      final fade = t < 0.62 ? 1.0 : 1 - (t - 0.62) / 0.38;
      final rise = t < 0.62 ? 0.0 : (t - 0.62) / 0.38;

      late Offset center;
      late double fontSize;
      late Color fill;
      late Color stroke;

      switch (popup.style) {
        case PopupStyle.gold:
          center = Offset(size.width * (0.5 + popup.x), size.height * popup.y);
          fontSize = size.width * 0.16 * popup.scale;
          fill = const Color(0xFFF6C445);
          stroke = const Color(0xFF6B3C0C);
          break;
        case PopupStyle.red:
          center = game.toScreen(popup.x, popup.y);
          fontSize = size.width * 0.17 * popup.scale;
          fill = const Color(0xFFE2372B);
          stroke = Colors.white;
          break;
        case PopupStyle.win:
          center = Offset(size.width * (0.5 + popup.x), size.height * popup.y);
          fontSize = size.width * 0.105 * popup.scale;
          fill = const Color(0xFFFFDD63);
          stroke = const Color(0xFF5A3305);
          break;
        case PopupStyle.banner:
          center = Offset(size.width * (0.5 + popup.x), size.height * popup.y);
          fontSize = size.width * 0.072 * popup.scale;
          fill = Colors.white;
          stroke = const Color(0xFF17324A);
          break;
      }

      final alpha = fade.clamp(0.0, 1.0);
      final scale = grow * (1 + rise * 0.12);
      final painter = TextPainter(
        text: TextSpan(
          text: popup.text,
          style: TextStyle(
            fontFamily: T.family,
            fontWeight: FontWeight.w900,
            fontSize: fontSize,
            height: 1,
            foreground: Paint()
              ..style = PaintingStyle.stroke
              ..strokeWidth = fontSize * 0.10
              ..strokeJoin = StrokeJoin.round
              ..color = stroke.withValues(alpha: alpha),
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      final fillPainter = TextPainter(
        text: TextSpan(
          text: popup.text,
          style: TextStyle(
            fontFamily: T.family,
            fontWeight: FontWeight.w900,
            fontSize: fontSize,
            height: 1,
            color: fill.withValues(alpha: alpha),
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();

      canvas.save();
      canvas.translate(center.dx, center.dy - rise * size.height * 0.06);
      canvas.scale(scale);
      final offset = Offset(-painter.width / 2, -painter.height / 2);
      painter.paint(canvas, offset);
      fillPainter.paint(canvas, offset);
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(covariant ScenePainter oldDelegate) => true;
}
