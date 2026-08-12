import 'package:flutter/material.dart';

import '../../core/palette.dart';
import '../harbor_config.dart';
import '../ui/pier_assets.dart';
import '../ui/tide_button.dart';
import '../wire/chime_channel.dart';
import '../wire/fabric_store.dart';
import 'harbor_stage.dart';

/// One-shot push opt-in promo shown before the WebView when
/// `store.shouldPromptPermission` is true (first launch, or the
/// snooze window has expired).
class PromptStage extends StatefulWidget {
  const PromptStage({
    super.key,
    required this.store,
    required this.chime,
    required this.destinationUrl,
  });

  final FabricStore store;
  final ChimeChannel chime;
  final String destinationUrl;

  @override
  State<PromptStage> createState() => _PromptStageState();
}

class _PromptStageState extends State<PromptStage> {
  Future<void> _accept() async {
    final bool granted = await widget.chime.requestPermission();
    if (!granted) {
      await widget.store.writeSnoozeUntil(_snoozeTarget());
    }
    if (mounted) _forward();
  }

  Future<void> _skip() async {
    await widget.store.writeSnoozeUntil(_snoozeTarget());
    if (mounted) _forward();
  }

  int _snoozeTarget() =>
      DateTime.now().millisecondsSinceEpoch ~/ 1000 +
      HarborConfig.permissionSnoozeSeconds;

  void _forward() {
    Navigator.of(context).pushReplacement(
      MaterialPageRoute<void>(
        builder: (_) => HarborStage(
          url: widget.destinationUrl,
          store: widget.store,
          chime: widget.chime,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final MediaQueryData mq = MediaQuery.of(context);
    final Size size = mq.size;
    final bool landscape = mq.orientation == Orientation.landscape;
    final String bg = landscape
        ? PierAssets.horizontalNotifications
        : PierAssets.verticalNotifications;

    final double primaryWidth =
        landscape ? size.width * 0.34 : size.width * 0.70;
    final double secondaryWidth =
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
            bottom: size.height * (landscape ? 0.07 : 0.09),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                TideButton(
                  label: 'Accept',
                  width: primaryWidth,
                  onTap: _accept,
                ),
                SizedBox(height: landscape ? 10 : 14),
                TideButton(
                  label: 'Skip',
                  kind: TideButtonKind.dusk,
                  compact: true,
                  width: secondaryWidth,
                  onTap: _skip,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
