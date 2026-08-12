import 'package:flutter/material.dart';

import '../../core/palette.dart';

/// Shared button for every tide-side screen (pier, prompt, adrift).
///
/// Two visual variants — `TideButtonKind.flame` for the primary
/// action, `TideButtonKind.dusk` for the secondary. Both render as
/// real gradient pills with equal tap height. The design contract
/// (gray_part_pitfalls.md §12) forbids opacity-only "Skip" links;
/// visual weight comes from the palette contrast, not size.
enum TideButtonKind { flame, dusk }

class TideButton extends StatefulWidget {
  const TideButton({
    super.key,
    required this.label,
    required this.onTap,
    this.kind = TideButtonKind.flame,
    this.width,
    this.compact = false,
  });

  final String label;
  final VoidCallback onTap;
  final TideButtonKind kind;
  final double? width;
  final bool compact;

  @override
  State<TideButton> createState() => _TideButtonState();
}

class _TideButtonState extends State<TideButton> {
  double _scale = 1.0;

  static const _flameGrad = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: <Color>[P.goldLight, P.gold, P.goldDark],
    stops: <double>[0.0, 0.55, 1.0],
  );

  static const _duskGrad = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: <Color>[Color(0xFF3A5A78), Color(0xFF20364A), Color(0xFF0F1E2E)],
    stops: <double>[0.0, 0.5, 1.0],
  );

  @override
  Widget build(BuildContext context) {
    final bool flame = widget.kind == TideButtonKind.flame;
    final LinearGradient grad = flame ? _flameGrad : _duskGrad;
    final Color border = flame
        ? const Color(0xFF7C4A0F)
        : const Color(0xFF7FB1D8).withValues(alpha: 0.80);
    final Color labelColor = flame ? const Color(0xFF3B1E00) : Colors.white;
    final double fontSize = widget.compact ? 16 : 18;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (_) => setState(() => _scale = 0.96),
      onTapCancel: () => setState(() => _scale = 1.0),
      onTapUp: (_) {
        setState(() => _scale = 1.0);
        widget.onTap();
      },
      child: AnimatedScale(
        scale: _scale,
        duration: const Duration(milliseconds: 90),
        curve: Curves.easeOut,
        child: Container(
          width: widget.width,
          padding: EdgeInsets.symmetric(
            horizontal: widget.compact ? 22 : 30,
            vertical: widget.compact ? 12 : 16,
          ),
          decoration: BoxDecoration(
            gradient: grad,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: border, width: 2),
            boxShadow: <BoxShadow>[
              BoxShadow(
                color: (flame ? const Color(0xFF6E3C00) : const Color(0xFF06131F))
                    .withValues(alpha: 0.65),
                offset: const Offset(0, 4),
                blurRadius: 0,
              ),
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.28),
                offset: const Offset(0, 5),
                blurRadius: 12,
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: <Widget>[
              Text(
                widget.label,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontFamily: T.family,
                  color: labelColor,
                  fontSize: fontSize,
                  fontWeight: FontWeight.w900,
                  height: 1.0,
                  letterSpacing: 0.4,
                  shadows: flame
                      ? const <Shadow>[
                          Shadow(
                            color: Color(0x66FFFFFF),
                            offset: Offset(0, 1),
                            blurRadius: 2,
                          ),
                        ]
                      : const <Shadow>[
                          Shadow(
                            color: Color(0x99000000),
                            offset: Offset(0, 2),
                            blurRadius: 3,
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
