import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import '../core/palette.dart';
import '../core/sfx.dart';
import '../game/scene_painter.dart';
import '../game/tower_game.dart';
import '../widgets/game_buttons.dart';
import '../widgets/hazard.dart';
import '../widgets/menu_sheet.dart';
import '../widgets/results_panel.dart';
import '../widgets/temple_wheel.dart';
import '../widgets/top_bar.dart';

class GameScreen extends StatefulWidget {
  const GameScreen({super.key});

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  late final TowerGame _game;
  late final Ticker _ticker;
  Duration _last = Duration.zero;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _game = TowerGame();
    _ticker = createTicker((elapsed) {
      final dt = (elapsed - _last).inMicroseconds / 1000000;
      _last = elapsed;
      _game.tick(dt);
    })..start();
    Sfx.i.music(Sfx.bgmGame, volume: 0.28);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _ticker.dispose();
    _game.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      Sfx.i.applyMusicSetting();
    } else {
      Sfx.i.stopMusic();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: P.skyTop,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AnimatedBuilder(
            animation: _game,
            builder: (context, _) => GameTopBar(
              balance: _game.balance,
              roundId: _game.roundId,
              onMenu: () => showGameMenu(context, _game),
            ),
          ),
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) {
                return Stack(
                  children: [
                    Positioned.fill(
                      child: RepaintBoundary(
                        child: CustomPaint(
                          painter: ScenePainter(_game),
                          size: Size.infinite,
                          child: const SizedBox.expand(),
                        ),
                      ),
                    ),
                    Positioned(
                      right: 12,
                      top: 12,
                      child: DotsButton(onTap: () => showGameInfo(context)),
                    ),
                    Positioned(
                      right: 10,
                      top: constraints.maxHeight * 0.26,
                      child: AnimatedBuilder(
                        animation: _game,
                        builder: (context, _) =>
                            ResultsPanel(results: _game.results),
                      ),
                    ),
                    Positioned.fill(
                      child: AnimatedBuilder(
                        animation: _game,
                        builder: (context, _) => _game.templeSpinning
                            ? TempleWheel(
                                onDone: (value) =>
                                    _game.applyTempleResult(value),
                              )
                            : const SizedBox.shrink(),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
          AnimatedBuilder(
            animation: _game,
            builder: (context, _) => _BottomPanel(game: _game),
          ),
        ],
      ),
    );
  }
}

class _BottomPanel extends StatelessWidget {
  const _BottomPanel({required this.game});

  final TowerGame game;

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).padding.bottom;
    final inRound = game.roundActive;
    return Container(
      color: P.bottomPanel,
      child: Column(
        children: [
          const HazardStrip(height: 9, stripeWidth: 11),
          Padding(
            padding: EdgeInsets.fromLTRB(10, 10, 10, bottomInset + 10),
            child: Column(
              children: [
                if (!inRound) ...[
                  Row(
                    children: [
                      Expanded(
                        flex: 3,
                        child: BlueButton(
                          height: 44,
                          enabled:
                              game.phase == Phase.idle &&
                              game.balance >= TowerGame.minBet,
                          onTap: game.allIn,
                          child: Text(
                            'ALL IN',
                            style: T.black(15, spacing: 0.6),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        flex: 5,
                        child: BetStepper(
                          value: fmtAmount(game.bet),
                          enabled: game.phase == Phase.idle,
                          onMinus: () => game.changeBet(-1),
                          onPlus: () => game.changeBet(1),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        flex: 3,
                        child: BlueButton(
                          height: 44,
                          enabled:
                              game.phase == Phase.idle &&
                              game.balance >= game.bet * 2,
                          onTap: game.doubleBet,
                          child: Text('x2', style: T.black(17)),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 9),
                  BuildButton(
                    height: 54,
                    enabled: game.canBuild,
                    onTap: game.build,
                  ),
                ] else
                  Row(
                    children: [
                      Expanded(
                        child: CashoutButton(
                          height: 54,
                          amount: fmtAmount(game.cashoutAmount),
                          enabled: game.canCashout,
                          onTap: game.cashout,
                        ),
                      ),
                      const SizedBox(width: 9),
                      Expanded(
                        child: BuildButton(
                          height: 54,
                          enabled: game.canBuild,
                          onTap: game.build,
                        ),
                      ),
                    ],
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
