import 'package:flutter/material.dart';

import '../core/palette.dart';
import '../core/sfx.dart';

class _Press extends StatefulWidget {
  const _Press({required this.child, required this.onTap, this.enabled = true});

  final Widget child;
  final VoidCallback onTap;
  final bool enabled;

  @override
  State<_Press> createState() => _PressState();
}

class _PressState extends State<_Press> {
  bool _down = false;

  @override
  Widget build(BuildContext context) {
    return Listener(
      onPointerDown: widget.enabled
          ? (_) => setState(() => _down = true)
          : null,
      onPointerUp: widget.enabled ? (_) => setState(() => _down = false) : null,
      onPointerCancel: widget.enabled
          ? (_) => setState(() => _down = false)
          : null,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: widget.enabled ? widget.onTap : null,
        child: AnimatedScale(
          scale: _down ? 0.96 : 1,
          duration: const Duration(milliseconds: 80),
          child: Opacity(
            opacity: widget.enabled ? 1 : 0.45,
            child: widget.child,
          ),
        ),
      ),
    );
  }
}

/// Golden BUILD plate with the construction tape edges.
class BuildButton extends StatelessWidget {
  const BuildButton({
    super.key,
    required this.onTap,
    this.enabled = true,
    this.height = 52,
  });

  final VoidCallback onTap;
  final bool enabled;
  final double height;

  @override
  Widget build(BuildContext context) {
    return _Press(
      enabled: enabled,
      onTap: () {
        Sfx.i.play(Sfx.click);
        onTap();
      },
      child: SizedBox(
        height: height,
        child: Stack(
          fit: StackFit.expand,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: Image.asset(
                'assets/Tower_Surge_gameplay_assets/button_blank.webp',
                fit: BoxFit.fill,
                filterQuality: FilterQuality.medium,
              ),
            ),
            Center(
              child: Text(
                'BUILD',
                style: T.black(
                  height * 0.42,
                  color: Colors.white,
                  spacing: 1.2,
                  shadows: const [
                    Shadow(
                      color: Color(0x99503000),
                      offset: Offset(0, 2),
                      blurRadius: 3,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Blue plate used for CASHOUT, ALL IN and x2.
class BlueButton extends StatelessWidget {
  const BlueButton({
    super.key,
    required this.onTap,
    required this.child,
    this.enabled = true,
    this.height = 44,
    this.width,
  });

  final VoidCallback onTap;
  final Widget child;
  final bool enabled;
  final double height;
  final double? width;

  @override
  Widget build(BuildContext context) {
    return _Press(
      enabled: enabled,
      onTap: () {
        Sfx.i.play(Sfx.click);
        onTap();
      },
      child: Container(
        height: height,
        width: width,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(9),
          gradient: const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [P.blueLight, P.blue, P.blueDark],
            stops: [0, 0.45, 1],
          ),
          border: Border.all(color: const Color(0xFF8ED0FF), width: 1.2),
          boxShadow: const [
            BoxShadow(
              color: Color(0x66000000),
              offset: Offset(0, 2),
              blurRadius: 4,
            ),
          ],
        ),
        child: Center(child: child),
      ),
    );
  }
}

class CashoutButton extends StatelessWidget {
  const CashoutButton({
    super.key,
    required this.amount,
    required this.onTap,
    required this.enabled,
    this.height = 52,
  });

  final String amount;
  final VoidCallback onTap;
  final bool enabled;
  final double height;

  @override
  Widget build(BuildContext context) {
    return BlueButton(
      onTap: onTap,
      enabled: enabled,
      height: height,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            'CASHOUT',
            style: T.black(height * 0.30, color: Colors.white, spacing: 0.8),
          ),
          const SizedBox(height: 1),
          Text(
            '$amount FUN',
            style: T.bold(height * 0.26, color: const Color(0xFFEAF6FF)),
          ),
        ],
      ),
    );
  }
}

class BetStepper extends StatelessWidget {
  const BetStepper({
    super.key,
    required this.value,
    required this.onMinus,
    required this.onPlus,
    required this.enabled,
    this.height = 44,
  });

  final String value;
  final VoidCallback onMinus;
  final VoidCallback onPlus;
  final bool enabled;
  final double height;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: height,
      decoration: BoxDecoration(
        color: const Color(0xFF262522),
        borderRadius: BorderRadius.circular(9),
        border: Border.all(color: const Color(0xFF4A4844), width: 1.2),
      ),
      child: Row(
        children: [
          _StepIcon(
            icon: Icons.remove_rounded,
            onTap: onMinus,
            enabled: enabled,
          ),
          Expanded(
            child: Center(
              child: FittedBox(
                child: Text(value, style: T.black(height * 0.40)),
              ),
            ),
          ),
          _StepIcon(icon: Icons.add_rounded, onTap: onPlus, enabled: enabled),
        ],
      ),
    );
  }
}

class _StepIcon extends StatelessWidget {
  const _StepIcon({
    required this.icon,
    required this.onTap,
    required this.enabled,
  });

  final IconData icon;
  final VoidCallback onTap;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return _Press(
      enabled: enabled,
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10),
        child: Icon(icon, color: Colors.white, size: 24),
      ),
    );
  }
}

/// Round blue button with three dots that opens the game info.
class DotsButton extends StatelessWidget {
  const DotsButton({super.key, required this.onTap, this.size = 40});

  final VoidCallback onTap;
  final double size;

  @override
  Widget build(BuildContext context) {
    return _Press(
      onTap: () {
        Sfx.i.play(Sfx.click);
        onTap();
      },
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: const RadialGradient(
            center: Alignment(-0.3, -0.5),
            radius: 1.1,
            colors: [Color(0xFF7CC8FA), Color(0xFF2E93E5), Color(0xFF1567B8)],
            stops: [0, 0.55, 1],
          ),
          border: Border.all(color: const Color(0x66FFFFFF), width: 1),
          boxShadow: const [
            BoxShadow(
              color: Color(0x55000000),
              offset: Offset(0, 2),
              blurRadius: 4,
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(
            3,
            (i) => Container(
              width: size * 0.11,
              height: size * 0.11,
              margin: EdgeInsets.symmetric(horizontal: size * 0.035),
              decoration: const BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
