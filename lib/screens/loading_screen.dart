import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/game_images.dart';
import '../core/palette.dart';
import '../core/sfx.dart';
import '../widgets/backdrop.dart';
import 'game_screen.dart';

class LoadingScreen extends StatefulWidget {
  const LoadingScreen({super.key});

  @override
  State<LoadingScreen> createState() => _LoadingScreenState();
}

class _LoadingScreenState extends State<LoadingScreen> {
  static const _minDuration = Duration(milliseconds: 2600);

  Timer? _timer;
  final Stopwatch _clock = Stopwatch();

  double _work = 0;
  double _shown = 0;
  bool _ready = false;
  bool _left = false;
  int _dots = 0;
  int _dotTick = 0;

  @override
  void initState() {
    super.initState();
    _clock.start();
    Sfx.i.music(Sfx.bgmMenu, volume: 0.22);
    _timer = Timer.periodic(const Duration(milliseconds: 16), _onTick);
    _prepare();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _prepare() async {
    await GameImages.i.load(
      onProgress: (value) {
        if (mounted) setState(() => _work = value * 0.85);
      },
    );
    if (!mounted) return;
    setState(() => _work = 1);
    final remaining = _minDuration - _clock.elapsed;
    if (remaining > Duration.zero) await Future.delayed(remaining);
    if (!mounted) return;
    setState(() => _ready = true);
  }

  void _onTick(Timer timer) {
    if (!mounted) return;
    final elapsed = _clock.elapsedMilliseconds / _minDuration.inMilliseconds;
    // Hold the bar below 100% until the game is truly ready to start.
    final target = _ready
        ? 1.0
        : math.min(0.93, math.max(_work * 0.93, elapsed * 0.9));
    final next = _shown + (target - _shown) * (_ready ? 0.20 : 0.10);
    _dotTick++;
    setState(() {
      _shown = next;
      if (_dotTick % 26 == 0) _dots = (_dots + 1) % 4;
    });
    if (_ready && _shown >= 0.999 && !_left) {
      _left = true;
      timer.cancel();
      Future.delayed(const Duration(milliseconds: 280), _openNextScreen);
    }
  }

  Future<void> _openNextScreen() async {
    if (!mounted) return;
    await SystemChrome.setPreferredOrientations(const [
      DeviceOrientation.portraitUp,
    ]);
    if (!mounted) return;
    Navigator.of(
      context,
    ).pushReplacement(MaterialPageRoute(builder: (_) => const GameScreen()));
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final landscape = size.width > size.height;
    final barWidth = size.width * (landscape ? 0.52 : 0.74);
    final barHeight = landscape ? 16.0 : 18.0;
    final progress = _shown.clamp(0.0, 1.0);

    return Scaffold(
      backgroundColor: P.skyTop,
      body: OrientationBackdrop(
        vertical: OrientationBackdrop.verticalLoading,
        horizontal: OrientationBackdrop.horizontalLoading,
        child: Align(
          alignment: Alignment(0, landscape ? 0.86 : 0.78),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Loading${'.' * _dots}',
                style: T.black(
                  landscape ? 20 : 22,
                  color: Colors.white,
                  shadows: const [
                    Shadow(
                      color: Color(0xCC0B2E4A),
                      offset: Offset(0, 2),
                      blurRadius: 5,
                    ),
                  ],
                ),
              ),
              SizedBox(height: landscape ? 8 : 12),
              _ProgressBar(width: barWidth, height: barHeight, value: progress),
              SizedBox(height: landscape ? 6 : 9),
              Text(
                '${(progress * 100).round()}%',
                style: T.black(
                  landscape ? 13 : 14,
                  color: Colors.white,
                  shadows: const [
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
      ),
    );
  }
}

class _ProgressBar extends StatelessWidget {
  const _ProgressBar({
    required this.width,
    required this.height,
    required this.value,
  });

  final double width;
  final double height;
  final double value;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(height);
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        borderRadius: radius,
        color: const Color(0xB3102A3E),
        border: Border.all(color: const Color(0xFF0E2333), width: 2),
        boxShadow: const [
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
                    colors: [P.goldLight, P.gold, P.goldDark],
                    stops: [0, 0.5, 1],
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
