import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/foundation.dart';

import '../core/game_images.dart';
import '../core/palette.dart';
import '../core/sfx.dart';
import '../core/store.dart';

enum Phase { idle, dropping, ready, resolving, temple, ending }

enum FloorKind { normal, temple, triple }

class FloorEntry {
  FloorEntry(this.multiplier, this.kind);

  final double multiplier;
  final FloorKind kind;
}

class BlockBody {
  BlockBody({
    required this.sprite,
    required this.widthUnits,
    required this.x,
    required this.yBottom,
    this.rotation = 0,
  });

  final int sprite;
  final double widthUnits;
  double x;
  double yBottom;
  double rotation;

  double vx = 0;
  double vy = 0;
  double vr = 0;
  double opacity = 1;
  bool falling = false;

  /// Opacity lost per second once the body is loose debris.
  double fadeRate = 0.25;

  /// Sprite index -1 renders the fixed store that every tower starts from.
  Sprite get spriteData =>
      sprite < 0 ? GameImages.i.baseBlock : GameImages.i.blocks[sprite];

  double get heightUnits => widthUnits / spriteData.aspect;
  double get top => yBottom + heightUnits;

  /// Height of the surface the next floor rests on (below the decorative peak).
  double get seatTop => yBottom + heightUnits * spriteData.seatTop;

  /// How far the block's own base sits above its content bottom (its point
  /// dips below the block underneath by this much).
  double get seatBottomUnits => heightUnits * spriteData.seatBottom;
}

class Particle {
  Particle(
    this.x,
    this.y,
    this.vx,
    this.vy,
    this.size,
    this.rotation,
    this.vr,
    this.life,
  );

  double x;
  double y;
  double vx;
  double vy;
  double size;
  double rotation;
  double vr;
  double life;
  double age = 0;
  int sprite = 0;

  double get t => (age / life).clamp(0.0, 1.0);
}

class Popup {
  Popup(
    this.text,
    this.style,
    this.x,
    this.y, {
    this.life = 1.5,
    this.scale = 1,
  });

  final String text;
  final PopupStyle style;
  final double x;
  final double y;
  final double life;
  final double scale;
  double age = 0;

  double get t => (age / life).clamp(0.0, 1.0);
}

enum PopupStyle { gold, red, win, banner }

class CloudSpec {
  CloudSpec(this.x, this.y, this.size, this.speed, this.sprite);

  final double x;
  final double y;
  final double size;
  final double speed;
  final int sprite;
}

class Stone {
  Stone(this.x, this.y, this.rx, this.ry, this.shade);

  final double x;
  final double y;
  final double rx;
  final double ry;
  final double shade;
}

class _Scheduled {
  _Scheduled(this.at, this.action);

  final double at;
  final VoidCallback action;
  bool done = false;
}

/// Game logic and animation state of the tower.
///
/// Rules follow the original Tower Rush: every BUILD releases one floor, a
/// clean drop applies a random floor multiplier (which may be below 1x) to the
/// running total, a failed drop ends the round, and the player may cash out
/// between floors. Temple Floor / Triple Build bonuses can replace a regular
/// floor.
class TowerGame extends ChangeNotifier {
  TowerGame() {
    _resetTower();
    _buildScenery();
    bet = Store.i.bet;
    balance = Store.i.balance;
    if (balance < minBet) balance = Store.i.balance = Store.startingBalance;
  }

  /// Vertical span the cloud field repeats over, in world units.
  static const double cloudSpan = 4.2;

  final List<CloudSpec> clouds = [];
  final List<Stone> stones = [];

  void _buildScenery() {
    final rng = math.Random(20260812);
    for (var i = 0; i < 5; i++) {
      clouds.add(
        CloudSpec(
          -0.95 + rng.nextDouble() * 1.9,
          0.9 + i * (cloudSpan / 5) + rng.nextDouble() * 0.35,
          0.34 + rng.nextDouble() * 0.42,
          (rng.nextBool() ? 1 : -1) * (0.006 + rng.nextDouble() * 0.016),
          1,
        ),
      );
    }
    for (var i = 0; i < 90; i++) {
      stones.add(
        Stone(
          -0.62 + rng.nextDouble() * 1.24,
          -0.02 - rng.nextDouble() * 0.6,
          0.006 + rng.nextDouble() * 0.019,
          0.004 + rng.nextDouble() * 0.013,
          rng.nextDouble(),
        ),
      );
    }
  }

  static const double maxMultiplier = 100;
  static const double minBet = 100;
  static const double maxBet = 10000;
  static const List<double> betLadder = [
    100,
    200,
    300,
    400,
    500,
    750,
    1000,
    1500,
    2000,
    2500,
    5000,
    7500,
    10000,
  ];

  static const double groundFrac = 0.87;
  static const double towerTopFrac = 0.57;
  static const double hangTopFrac = 0.15;

  /// House edge is taken once, on the first floor of a round; later floors are
  /// EV neutral (bonus floors included) so the return does not depend on how
  /// long the player keeps building — the same way real crash games work.
  static const double _firstFloorRtp = 0.97;
  static const double _fairStep = 0.9585;
  static const double _pTemple = 0.016;
  static const double _pTriple = 0.018;

  final ValueNotifier<int> frame = ValueNotifier<int>(0);
  final math.Random _rng = math.Random();

  Size viewport = const Size(400, 600);

  // Session state.
  double balance = Store.startingBalance;
  double bet = 100;
  int roundId = 0;
  bool roundActive = false;
  double totalMultiplier = 1;
  final List<FloorEntry> results = [];
  Phase phase = Phase.idle;
  int floorsBuilt = 0;

  // World state.
  final List<BlockBody> tower = [];
  final List<BlockBody> debris = [];
  final List<Particle> particles = [];
  final List<Popup> popups = [];
  final List<_Scheduled> _scheduled = [];

  double time = 0;
  double camPx = 0;
  double _camTargetPx = 0;
  double scale = 1;
  double _scaleTarget = 1;
  double shake = 0;
  double shakePhase = 0;

  // Hook / hanging block.
  int hangSprite = 0;
  double swayPhase = 0;
  double hookOffset = 0; // 0 = docked, 1 = fully retracted above the screen.
  double _hookTarget = 0;
  bool hookHasBlock = true;

  // Falling block.
  BlockBody? flying;
  double _flyT = 0;
  double _flyDuration = 0.6;
  double _flyFrom = 0;
  double _flyTo = 0;
  double _flyX = 0;
  double _flyTargetX = 0;
  FloorOutcome? _outcome;
  bool _missed = false;

  int _autoDrops = 0;
  bool templeSpinning = false;

  double get unit => viewport.width;

  double get groundScreenY => viewport.height * groundFrac + camPx;

  double get stackTop => tower.isEmpty ? 0 : tower.last.seatTop;

  double get cashoutAmount => bet * math.min(totalMultiplier, maxMultiplier);

  double get baseWidthUnits => 0.40;

  bool get canBuild =>
      (phase == Phase.idle && balance >= bet) ||
      (phase == Phase.ready && _autoDrops == 0);

  bool get canCashout => phase == Phase.ready && roundActive && _autoDrops == 0;

  Offset toScreen(double x, double y) => Offset(
    viewport.width / 2 + x * unit * scale + shakeX,
    groundScreenY - y * unit * scale + shakeY,
  );

  double get shakeX => shake * math.sin(shakePhase * 37) * unit * 0.012;
  double get shakeY => shake * math.cos(shakePhase * 43) * unit * 0.010;

  double screenToWorldY(double screenY) =>
      (groundScreenY - screenY) / (unit * scale);

  double screenToWorldX(double screenX) =>
      (screenX - viewport.width / 2) / (unit * scale);

  double blockWidthUnits(int sprite) =>
      const [0.425, 0.385, 0.370, 0.360][sprite];

  // ---------------------------------------------------------------- lifecycle

  void setViewport(Size size) {
    if (size.width <= 0 || size.height <= 0) return;
    if ((size.width - viewport.width).abs() < 0.5 &&
        (size.height - viewport.height).abs() < 0.5) {
      return;
    }
    viewport = size;
    _camTargetPx = _cameraTarget();
    camPx = _camTargetPx;
  }

  void _resetTower() {
    tower
      ..clear()
      ..add(
        BlockBody(sprite: -1, widthUnits: baseWidthUnits, x: 0, yBottom: 0),
      );
    debris.clear();
    particles.clear();
    scale = _scaleTarget = 1;
    camPx = _camTargetPx = 0;
    hangSprite = _rng.nextInt(
      GameImages.i.loaded ? GameImages.i.blocks.length : 4,
    );
    hookHasBlock = true;
    hookOffset = 0;
    _hookTarget = 0;
    flying = null;
  }

  // ------------------------------------------------------------------- betting

  void changeBet(int direction) {
    if (phase != Phase.idle) return;
    var index = betLadder.indexWhere((v) => (v - bet).abs() < 0.01);
    if (index < 0) {
      index = betLadder.lastIndexWhere((v) => v <= bet);
      if (index < 0) index = 0;
    }
    final next = (index + direction).clamp(0, betLadder.length - 1);
    _setBet(betLadder[next]);
    Sfx.i.play(Sfx.click, volume: 0.6);
  }

  void doubleBet() {
    if (phase != Phase.idle) return;
    _setBet(bet * 2);
    Sfx.i.play(Sfx.click, volume: 0.6);
  }

  void allIn() {
    if (phase != Phase.idle) return;
    _setBet(balance);
    Sfx.i.play(Sfx.click, volume: 0.6);
  }

  void resetBalance() {
    if (phase != Phase.idle) return;
    Store.i.resetBalance();
    balance = Store.startingBalance;
    _setBet(bet);
    notifyListeners();
  }

  void _setBet(double value) {
    final capped = value.clamp(
      minBet,
      math.min(maxBet, math.max(minBet, balance)),
    );
    bet = capped.toDouble();
    Store.i.bet = bet;
    notifyListeners();
  }

  // ------------------------------------------------------------------ commands

  void build() {
    if (!canBuild) return;
    if (phase == Phase.idle) {
      if (balance < bet) return;
      balance -= bet;
      Store.i.balance = balance;
      roundActive = true;
      roundId = 100000000 + _rng.nextInt(899999999);
      totalMultiplier = 1;
      floorsBuilt = 0;
      results.clear();
      popups.clear();
    }
    _release(rollFloor(floorsBuilt + 1));
  }

  void cashout() {
    if (!canCashout) return;
    final amount = cashoutAmount;
    balance += amount;
    Store.i.balance = balance;
    phase = Phase.ending;
    Sfx.i.play(Sfx.cashout);
    _schedule(0.25, () => Sfx.i.play(Sfx.coin));
    _showPopup(
      Popup('+${fmtAmount(amount)} FUN', PopupStyle.win, 0, 0.45, life: 1.9),
    );
    if (totalMultiplier >= 5) _schedule(0.4, () => Sfx.i.play(Sfx.win));
    _liftTower();
    _schedule(1.5, _finishRound);
    notifyListeners();
  }

  // -------------------------------------------------------------------- rolls

  @visibleForTesting
  FloorOutcome rollFloor(int index) {
    if (index > 1) {
      final roll = _rng.nextDouble();
      if (roll < _pTemple) {
        return FloorOutcome(kind: FloorKind.temple, multiplier: 1);
      }
      if (roll < _pTemple + _pTriple) {
        return FloorOutcome(
          kind: FloorKind.triple,
          multiplier: safeMultiplier(),
        );
      }
    }
    final table = _tableFor(index);
    final mean = _mean(table);
    final target = index == 1 ? _firstFloorRtp : _fairStep;
    final pFail = (1 - target / mean).clamp(0.05, 0.6);
    if (_rng.nextDouble() < pFail) {
      return FloorOutcome(kind: FloorKind.normal, multiplier: 0, failed: true);
    }
    return FloorOutcome(kind: FloorKind.normal, multiplier: _pick(table));
  }

  @visibleForTesting
  double safeMultiplier() => _pick(const [
    [1.0, 5],
    [1.05, 5],
    [1.1, 5],
    [1.2, 4],
    [1.3, 3],
    [1.5, 2],
    [1.75, 1],
  ]);

  List<List<double>> _tableFor(int index) {
    if (index <= 3) {
      return const [
        [0.5, 4],
        [0.65, 5],
        [0.75, 7],
        [0.9, 10],
        [1.0, 12],
        [1.05, 11],
        [1.1, 10],
        [1.2, 8],
        [1.25, 7],
        [1.35, 5],
        [1.5, 4],
        [1.65, 2],
        [1.85, 1.5],
        [2.0, 1],
      ];
    }
    if (index <= 8) {
      return const [
        [0.5, 4],
        [0.65, 5],
        [0.8, 7],
        [0.95, 9],
        [1.05, 11],
        [1.15, 10],
        [1.25, 9],
        [1.4, 7],
        [1.55, 5],
        [1.75, 4],
        [2.0, 2.5],
        [2.5, 1.2],
        [3.0, 0.7],
      ];
    }
    return const [
      [0.5, 4],
      [0.7, 5],
      [0.9, 7],
      [1.05, 9],
      [1.2, 10],
      [1.35, 9],
      [1.55, 8],
      [1.8, 6],
      [2.1, 4],
      [2.5, 2.5],
      [3.0, 1.5],
      [4.0, 0.8],
    ];
  }

  double _mean(List<List<double>> table) {
    var w = 0.0;
    var s = 0.0;
    for (final row in table) {
      w += row[1];
      s += row[0] * row[1];
    }
    return s / w;
  }

  double _pick(List<List<double>> table) {
    var total = 0.0;
    for (final row in table) {
      total += row[1];
    }
    var roll = _rng.nextDouble() * total;
    for (final row in table) {
      roll -= row[1];
      if (roll <= 0) return row[0];
    }
    return table.last[0];
  }

  // -------------------------------------------------------------------- drops

  void _release(FloorOutcome outcome) {
    _outcome = outcome;
    _missed = false;
    phase = Phase.dropping;
    final sprite = hangSprite;
    final width = blockWidthUnits(sprite);
    final hangScreenTop = viewport.height * hangTopFrac;
    final heightUnits = width / GameImages.i.blocks[sprite].aspect;
    _flyFrom = screenToWorldY(hangScreenTop) - heightUnits;
    // The floor leaves the hook exactly where the crane was when BUILD was
    // pressed; the aim assist below only nudges it from there.
    _flyX = screenToWorldX(_hangScreenX());
    // Sink the block so its contact band meets the surface below, closing the
    // air gap left by a tapered (hexagonal) base.
    final seatBottomUnits =
        heightUnits * GameImages.i.blocks[sprite].seatBottom;
    _flyTo = stackTop - seatBottomUnits;
    _flyTargetX = _dropTargetX(outcome, _flyX, width);
    _flyT = 0;
    final distance = math.max(0.2, _flyFrom - _flyTo);
    _flyDuration = (0.34 + 0.20 * distance).clamp(0.34, 0.8);
    flying = BlockBody(
      sprite: sprite,
      widthUnits: width,
      x: _flyX,
      yBottom: _flyFrom,
      rotation: _hangRotation(),
    );
    hookHasBlock = false;
    _hookTarget = 1;
    Sfx.i.play(Sfx.drop, volume: 0.8);
    notifyListeners();
  }

  /// How strongly a floor is steered from the release point toward the tower.
  /// Low on purpose: the original only helps the player a little.
  static const double _aimAssist = 0.55;

  double _dropTargetX(FloorOutcome outcome, double releaseX, double width) {
    final top = tower.last.x;
    if (outcome.failed) {
      // A missed floor comes down over the edge it was released above, but
      // stays on screen so the player sees it clip the tower.
      final side = releaseX >= top ? 1.0 : -1.0;
      final miss = top + side * width * (0.58 + _rng.nextDouble() * 0.18);
      final onScreen = 0.44 - width / 2;
      return miss.clamp(-onScreen, onScreen);
    }
    // Ideal spot: slightly pulled back toward the base plus a small jitter.
    final wanted = top * 0.6 + _landingOffset(outcome, width);
    final aimed = releaseX + (wanted - releaseX) * _aimAssist;
    // Keep the stack away from the screen edges whatever the player does.
    final limit = math.min(0.10, 0.42 - width / 2);
    return aimed.clamp(-limit, limit);
  }

  double _landingOffset(FloorOutcome outcome, double width) {
    final quality = ((outcome.multiplier - 0.5) / 1.6).clamp(0.0, 1.0);
    final spread = lerpDouble(0.22, 0.04, quality)!;
    final magnitude = spread * (0.45 + 0.55 * _rng.nextDouble());
    return width * magnitude * (_rng.nextBool() ? 1 : -1);
  }

  void _land() {
    final outcome = _outcome!;
    final block = flying!;
    flying = null;
    block.yBottom = _flyTo;
    block.x = _flyTargetX;
    block.rotation = (_rng.nextDouble() - 0.5) * 0.05;
    tower.add(block);
    floorsBuilt++;
    _scaleTarget = (1 - 0.013 * floorsBuilt).clamp(0.70, 1.0);
    shake = 0.55;
    _spawnLandingDust(block);
    Sfx.i.play(Sfx.place);

    totalMultiplier = math.min(
      maxMultiplier,
      totalMultiplier * outcome.multiplier,
    );
    results.insert(0, FloorEntry(outcome.multiplier, outcome.kind));
    _showPopup(
      Popup(fmtMultiplier(outcome.multiplier), PopupStyle.gold, -0.04, 0.42),
    );
    Sfx.i.play(Sfx.success, volume: 0.7);

    switch (outcome.kind) {
      case FloorKind.temple:
        _showPopup(
          Popup('TEMPLE FLOOR', PopupStyle.banner, 0, 0.22, life: 1.6),
        );
        Sfx.i.play(Sfx.levelUp);
        phase = Phase.temple;
        _schedule(0.7, () {
          templeSpinning = true;
          notifyListeners();
        });
        notifyListeners();
        return;
      case FloorKind.triple:
        // Only the floor that triggered the bonus queues the two extra drops.
        if (outcome.autoDrop) break;
        _showPopup(
          Popup('TRIPLE BUILD', PopupStyle.banner, 0, 0.22, life: 1.8),
        );
        Sfx.i.play(Sfx.levelUp);
        _autoDrops = 2;
        break;
      case FloorKind.normal:
        break;
    }

    _afterFloor();
  }

  void _afterFloor() {
    phase = Phase.ready;
    _schedule(0.32, _dockNewBlock);
    if (_autoDrops > 0) {
      _schedule(0.85, () {
        if (_autoDrops <= 0 || phase != Phase.ready) return;
        _autoDrops--;
        _release(
          FloorOutcome(
            kind: FloorKind.triple,
            multiplier: safeMultiplier(),
            autoDrop: true,
          ),
        );
      });
    }
    notifyListeners();
  }

  void applyTempleResult(double value) {
    templeSpinning = false;
    totalMultiplier = math.min(maxMultiplier, totalMultiplier * value);
    _showPopup(
      Popup(fmtMultiplier(value), PopupStyle.gold, 0, 0.45, life: 1.6),
    );
    Sfx.i.play(Sfx.win);
    _afterFloor();
  }

  void _dockNewBlock() {
    if (phase != Phase.ready && phase != Phase.idle) return;
    hangSprite = _rng.nextInt(GameImages.i.blocks.length);
    hookHasBlock = true;
    hookOffset = 1;
    _hookTarget = 0;
    notifyListeners();
  }

  /// A failed floor hits the top of the tower and tumbles off on its own; the
  /// tower itself stays standing.
  void _missFloor() {
    _missed = true;
    final block = flying!;
    flying = null;

    final top = tower.last;
    final side = block.x >= top.x ? 1.0 : -1.0;
    block.yBottom = _flyTo;
    block.falling = true;
    // Glancing hit: the floor is thrown sideways and spins as it drops.
    block.vx = side * (0.34 + _rng.nextDouble() * 0.22);
    block.vy = 0.18 + _rng.nextDouble() * 0.12;
    block.vr = side * (2.4 + _rng.nextDouble() * 2.2);
    block.fadeRate = 0;
    debris.add(block);

    _spawnImpactDust(block, side);
    _showPopup(
      Popup(
        'x0',
        PopupStyle.red,
        block.x,
        block.yBottom + block.heightUnits * 0.6,
        life: 1.5,
        scale: 1.25,
      ),
    );
    Sfx.i.play(Sfx.fail);
    shake = 0.9;
    phase = Phase.resolving;
    _schedule(1.5, _finishRound);
    notifyListeners();
  }

  void _spawnImpactDust(BlockBody block, double side) {
    for (var i = 0; i < 12; i++) {
      particles.add(
        Particle(
          block.x - side * block.widthUnits * (0.1 + _rng.nextDouble() * 0.35),
          block.yBottom + _rng.nextDouble() * 0.03,
          -side * (0.05 + _rng.nextDouble() * 0.35),
          0.1 + _rng.nextDouble() * 0.4,
          0.05 + _rng.nextDouble() * 0.07,
          _rng.nextDouble() * math.pi,
          (_rng.nextDouble() - 0.5) * 1.4,
          0.45 + _rng.nextDouble() * 0.4,
        )..sprite = _rng.nextInt(2),
      );
    }
  }

  void _liftTower() {
    for (var i = 1; i < tower.length; i++) {
      final block = tower[i];
      block.falling = true;
      block.vx = (_rng.nextDouble() - 0.5) * 0.25;
      block.vy = 0.55 + _rng.nextDouble() * 0.25;
      block.vr = (_rng.nextDouble() - 0.5) * 0.8;
      debris.add(block);
    }
    if (tower.length > 1) tower.removeRange(1, tower.length);
  }

  /// Popups of the same style replace each other so quick chains stay readable.
  void _showPopup(Popup popup) {
    popups.removeWhere((existing) => existing.style == popup.style);
    popups.add(popup);
  }

  void _finishRound() {
    roundActive = false;
    roundId = 0;
    totalMultiplier = 1;
    floorsBuilt = 0;
    _autoDrops = 0;
    phase = Phase.idle;
    _scaleTarget = 1;
    if (bet > balance) _setBet(balance);
    _resetTower();
    notifyListeners();
  }

  void _spawnLandingDust(BlockBody block, {int count = 5}) {
    for (var side = -1; side <= 1; side += 2) {
      for (var i = 0; i < count; i++) {
        particles.add(
          Particle(
            block.x + side * block.widthUnits * 0.45,
            block.yBottom + 0.01,
            side * (0.12 + _rng.nextDouble() * 0.35),
            0.05 + _rng.nextDouble() * 0.25,
            0.05 + _rng.nextDouble() * 0.06,
            _rng.nextDouble() * math.pi,
            (_rng.nextDouble() - 0.5) * 1.2,
            0.4 + _rng.nextDouble() * 0.35,
          )..sprite = _rng.nextInt(2),
        );
      }
    }
  }

  void _schedule(double delay, VoidCallback action) {
    _scheduled.add(_Scheduled(time + delay, action));
  }

  // --------------------------------------------------------------------- tick

  void tick(double dt) {
    if (dt <= 0) return;
    dt = math.min(dt, 1 / 30);
    time += dt;

    // Callbacks can queue new work, so iterate over a snapshot.
    final due = _scheduled.where((item) => time >= item.at).toList();
    for (final item in due) {
      if (item.done) continue;
      item.done = true;
      item.action();
    }
    _scheduled.removeWhere((item) => item.done);

    swayPhase += dt * 2.6;
    final hookStep = dt * (_hookTarget > hookOffset ? 2.6 : 2.0);
    if ((hookOffset - _hookTarget).abs() <= hookStep) {
      hookOffset = _hookTarget;
    } else {
      hookOffset += _hookTarget > hookOffset ? hookStep : -hookStep;
    }

    _camTargetPx = _cameraTarget();
    camPx += (_camTargetPx - camPx) * math.min(1, dt * 6.5);
    scale += (_scaleTarget - scale) * math.min(1, dt * 5);

    if (shake > 0) {
      shakePhase += dt;
      shake = math.max(0, shake - dt * 2.4);
    }

    final block = flying;
    if (block != null) {
      _flyT += dt / _flyDuration;
      final outcome = _outcome!;
      if (_flyT >= 1) {
        if (outcome.failed && !_missed) {
          _missFloor();
        } else {
          _land();
        }
      } else {
        // Gravity on the way down, constant sideways drift: a plain throw.
        block.yBottom = _flyFrom + (_flyTo - _flyFrom) * _flyT * _flyT;
        block.x = _flyX + (_flyTargetX - _flyX) * _flyT;
        block.rotation *= (1 - dt * 4).clamp(0.0, 1.0);
      }
    }

    for (final particle in particles) {
      particle.age += dt;
      particle.x += particle.vx * dt;
      particle.y += particle.vy * dt;
      particle.vy -= dt * 0.35;
      particle.vx *= (1 - dt * 1.6).clamp(0.0, 1.0);
      particle.rotation += particle.vr * dt;
      particle.size += dt * 0.06;
    }
    particles.removeWhere((p) => p.age >= p.life);

    for (final body in debris) {
      body.vy -= dt * 2.6;
      body.x += body.vx * dt;
      body.yBottom += body.vy * dt;
      body.rotation += body.vr * dt;
      body.opacity = (body.opacity - dt * body.fadeRate).clamp(0.0, 1.0);
    }
    debris.removeWhere((b) => b.yBottom < -1.8 || b.opacity <= 0.02);

    for (final popup in popups) {
      popup.age += dt;
    }
    popups.removeWhere((p) => p.age >= p.life);

    frame.value++;
  }

  double _cameraTarget() {
    final threshold = viewport.height * (groundFrac - towerTopFrac);
    final topPx = stackTop * unit * scale;
    return math.max(0, topPx - threshold);
  }

  double _hangScreenX() =>
      viewport.width / 2 + math.sin(swayPhase) * viewport.width * 0.145;

  double _hangRotation() => -0.055 * math.cos(swayPhase);

  /// Point the crane rope ends at, in screen space.
  Offset hangAnchor() => Offset(
    _hangScreenX(),
    viewport.height * hangTopFrac - hookOffset * viewport.height * 0.62,
  );

  /// Screen-space geometry of the block currently hanging on the hook.
  ({Rect rect, double rotation})? hangingBlockRect() {
    if (!hookHasBlock) return null;
    final width = blockWidthUnits(hangSprite) * unit * scale;
    final height = width / GameImages.i.blocks[hangSprite].aspect;
    final anchor = hangAnchor();
    return (
      rect: Rect.fromLTWH(anchor.dx - width / 2, anchor.dy, width, height),
      rotation: _hangRotation(),
    );
  }
}

/// Result the RNG produced for one BUILD press.
class FloorOutcome {
  FloorOutcome({
    required this.kind,
    required this.multiplier,
    this.failed = false,
    this.autoDrop = false,
  });

  final FloorKind kind;
  final double multiplier;
  final bool failed;

  /// True for the two extra floors handed out by a Triple Build.
  final bool autoDrop;
}
