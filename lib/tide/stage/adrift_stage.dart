import 'package:flutter/material.dart';

import '../../core/palette.dart';
import '../ui/pier_assets.dart';
import '../ui/tide_button.dart';

/// Offline surface. Retry rebuilds the caller-supplied route via
/// `pushReplacement`. The tide pipeline is idempotent — the
/// coordinator's in-flight cache clears on completion so Retry
/// re-runs the whole pipeline (signal → probe → ruling).
class AdriftStage extends StatefulWidget {
  const AdriftStage({super.key, required this.onRebuild});

  final WidgetBuilder onRebuild;

  @override
  State<AdriftStage> createState() => _AdriftStageState();
}

class _AdriftStageState extends State<AdriftStage> {
  bool _spin = false;

  Future<void> _retry() async {
    if (_spin) return;
    setState(() => _spin = true);
    await Future<void>.delayed(const Duration(milliseconds: 560));
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute<void>(builder: widget.onRebuild),
    );
  }

  @override
  Widget build(BuildContext context) {
    final MediaQueryData mq = MediaQuery.of(context);
    final bool landscape = mq.orientation == Orientation.landscape;
    final Size size = mq.size;
    final String bg = landscape
        ? PierAssets.horizontalOffline
        : PierAssets.verticalOffline;

    // NoWiFi CTA — shrunk 15% on each side (30% total) per design
    // pass. Landscape kept narrow already, portrait now sits at 70%
    // of the screen width instead of stretching edge-to-edge.
    final double buttonWidth =
        landscape ? size.width * 0.34 : size.width * 0.70;

    return Scaffold(
      backgroundColor: P.skyTop,
      body: Stack(
        fit: StackFit.expand,
        children: <Widget>[
          Image.asset(bg, fit: BoxFit.cover),
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.center,
                end: Alignment.bottomCenter,
                colors: <Color>[Colors.transparent, Color(0x992A0F00)],
              ),
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: size.height * (landscape ? 0.10 : 0.09),
            child: Center(
              child: _spin
                  ? const SizedBox(
                      width: 34,
                      height: 34,
                      child: CircularProgressIndicator(
                        strokeWidth: 3,
                        valueColor:
                            AlwaysStoppedAnimation<Color>(P.gold),
                      ),
                    )
                  : TideButton(
                      label: 'Retry',
                      width: buttonWidth,
                      onTap: _retry,
                    ),
            ),
          ),
        ],
      ),
    );
  }
}
