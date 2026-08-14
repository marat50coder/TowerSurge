import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/game_images.dart';
import '../core/palette.dart';
import '../screens/game_screen.dart';
import 'berth.dart';
import 'stage/adrift_stage.dart';
import 'stage/harbor_stage.dart';
import 'stage/prompt_stage.dart';
import 'tide_coordinator.dart';
import 'ui/pier_assets.dart';
import 'wire/chime_channel.dart';
import 'wire/fabric_store.dart';

// ============================================================
// PIER SCREEN — the single boot surface
// ============================================================
// Responsibilities:
//   • show the loading art + horizontal progress bar,
//   • drive `TideCoordinator.decide` and lift its progress into
//     the bar (0 → 1),
//   • when the game landing is chosen, precache the game images
//     first so the game screen boots with zero flicker,
//   • destructure the returned `Berth` via `switch` and push
//     exactly one route.
// Nothing else in the app decides routing.
// ============================================================

class PierScreen extends StatefulWidget {
  const PierScreen({
    super.key,
    required this.coordinator,
    required this.store,
    required this.chime,
  });

  final TideCoordinator coordinator;
  final FabricStore store;
  final ChimeChannel chime;

  @override
  State<PierScreen> createState() => _PierScreenState();
}

class _PierScreenState extends State<PierScreen> {
  static const _minShow = Duration(milliseconds: 2600);

  Timer? _tick;
  final Stopwatch _clock = Stopwatch();

  double _work = 0.04;
  double _shown = 0;
  bool _resolved = false;
  bool _left = false;
  int _dots = 0;
  int _dotStep = 0;
  Berth? _outcome;

  @override
  void initState() {
    super.initState();
    _clock.start();
    // No music during the tide/gray boot flow — the game screen boots
    // its own soundtrack when (and only when) it takes over.
    _tick = Timer.periodic(const Duration(milliseconds: 16), _pulse);
    _drive();
  }

  @override
  void dispose() {
    _tick?.cancel();
    super.dispose();
  }

  Future<void> _drive() async {
    Berth outcome;
    try {
      outcome = await widget.coordinator.decide(onProgress: (double v) {
        if (!mounted) return;
        // Reserve the last 15% of the bar for the game-art precache
        // when the coordinator is heading toward the game.
        setState(() => _work = math.max(_work, v * 0.85));
      });
    } catch (_) {
      outcome = const AdriftBerth(returnsToGame: false);
    }
    if (!mounted) return;

    // Offline / no-adapter path: skip the min-show delay and progress
    // bar animation entirely — user expects the NoWifi screen the
    // moment we realise there's no reachable network, not after 2.6s.
    if (outcome is AdriftBerth) {
      _tick?.cancel();
      _outcome = outcome;
      _left = true;
      unawaited(_land());
      return;
    }

    if (outcome is HomeGameBerth) {
      await GameImages.i.load(
        onProgress: (double v) {
          if (!mounted) return;
          setState(() => _work = math.min(1.0, 0.85 + v * 0.15));
        },
      );
    } else {
      _work = 1;
    }
    if (!mounted) return;

    final Duration left = _minShow - _clock.elapsed;
    if (left > Duration.zero) await Future<void>.delayed(left);
    if (!mounted) return;

    setState(() {
      _resolved = true;
      _outcome = outcome;
    });
  }

  void _pulse(Timer timer) {
    if (!mounted) return;
    final double target = _resolved ? 1.0 : math.min(0.94, _work);
    final double next =
        _shown + (target - _shown) * (_resolved ? 0.22 : 0.10);
    _dotStep++;
    setState(() {
      _shown = next;
      if (_dotStep % 24 == 0) _dots = (_dots + 1) % 4;
    });
    if (_resolved && _shown >= 0.999 && !_left) {
      _left = true;
      timer.cancel();
      Future<void>.delayed(const Duration(milliseconds: 240), _land);
    }
  }

  Future<void> _land() async {
    final Berth? outcome = _outcome;
    if (!mounted || outcome == null) return;

    switch (outcome) {
      case HomeGameBerth():
        await SystemChrome.setPreferredOrientations(const <DeviceOrientation>[
          DeviceOrientation.portraitUp,
        ]);
        if (!mounted) return;
        Navigator.of(context).pushReplacement(
          MaterialPageRoute<void>(builder: (_) => const GameScreen()),
        );
      case HarborBerth(url: final String url):
        if (widget.store.shouldPromptPermission) {
          Navigator.of(context).pushReplacement(
            MaterialPageRoute<void>(
              builder: (_) => PromptStage(
                store: widget.store,
                chime: widget.chime,
                destinationUrl: url,
              ),
            ),
          );
        } else {
          Navigator.of(context).pushReplacement(
            MaterialPageRoute<void>(
              builder: (_) => HarborStage(
                url: url,
                store: widget.store,
                chime: widget.chime,
              ),
            ),
          );
        }
      case AdriftBerth():
        Navigator.of(context).pushReplacement(
          MaterialPageRoute<void>(
            builder: (_) => AdriftStage(
              onRebuild: (_) => PierScreen(
                coordinator: widget.coordinator,
                store: widget.store,
                chime: widget.chime,
              ),
            ),
          ),
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final Size size = MediaQuery.of(context).size;
    final bool landscape = size.width > size.height;
    final String bg = landscape
        ? PierAssets.horizontalLoading
        : PierAssets.verticalLoading;
    final double barWidth = size.width * (landscape ? 0.52 : 0.74);
    final double barHeight = landscape ? 16 : 18;
    final double progress = _shown.clamp(0.0, 1.0);

    return Scaffold(
      backgroundColor: P.skyTop,
      body: Stack(
        fit: StackFit.expand,
        children: <Widget>[
          Image.asset(
            bg,
            fit: BoxFit.cover,
            filterQuality: FilterQuality.medium,
            gaplessPlayback: true,
          ),
          Align(
            alignment: Alignment(0, landscape ? 0.86 : 0.78),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Text(
                  'Loading${'.' * _dots}',
                  style: T.black(
                    landscape ? 20 : 22,
                    color: Colors.white,
                    shadows: const <Shadow>[
                      Shadow(
                        color: Color(0xCC0B2E4A),
                        offset: Offset(0, 2),
                        blurRadius: 5,
                      ),
                    ],
                  ),
                ),
                SizedBox(height: landscape ? 8 : 12),
                _PierBar(width: barWidth, height: barHeight, value: progress),
                SizedBox(height: landscape ? 6 : 9),
                Text(
                  '${(progress * 100).round()}%',
                  style: T.black(
                    landscape ? 13 : 14,
                    color: Colors.white,
                    shadows: const <Shadow>[
                      Shadow(
                        color: Color(0xAA0B2E4A),
                        offset: Offset(0, 1),
                        blurRadius: 3,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PierBar extends StatelessWidget {
  const _PierBar({required this.width, required this.height, required this.value});

  final double width;
  final double height;
  final double value;

  @override
  Widget build(BuildContext context) {
    final BorderRadius radius = BorderRadius.circular(height);
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        borderRadius: radius,
        color: const Color(0xB3102A3E),
        border: Border.all(color: const Color(0xFF0E2333), width: 2),
        boxShadow: const <BoxShadow>[
          BoxShadow(
            color: Color(0x66000000),
            offset: Offset(0, 2),
            blurRadius: 4,
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(2.5),
        child: ClipRRect(
          borderRadius: radius,
          child: Align(
            alignment: Alignment.centerLeft,
            child: FractionallySizedBox(
              widthFactor: value.clamp(0.0, 1.0),
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: radius,
                  gradient: const LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: <Color>[P.goldLight, P.gold, P.goldDark],
                    stops: <double>[0, 0.5, 1],
                  ),
                ),
                child: Align(
                  alignment: Alignment.topCenter,
                  child: FractionallySizedBox(
                    heightFactor: 0.42,
                    widthFactor: 0.94,
                    child: Container(
                      decoration: BoxDecoration(
                        borderRadius: radius,
                        color: Colors.white.withValues(alpha: 0.30),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
