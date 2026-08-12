import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:towersurgegame/core/game_images.dart';
import 'package:towersurgegame/core/store.dart';
import 'package:towersurgegame/game/tower_game.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await Store.init();
    await GameImages.i.load();
  });

  /// Advances the clock until the game waits for the player again. The Temple
  /// wheel is resolved by the UI, so it is answered here on its behalf.
  void settle(TowerGame game) {
    for (var i = 0; i < 1200 && !game.canBuild; i++) {
      game.tick(1 / 60);
      if (game.templeSpinning) game.applyTempleResult(3);
    }
    expect(
      game.canBuild,
      isTrue,
      reason: 'game stalled in phase ${game.phase}',
    );
  }

  test('one BUILD press never adds more than three floors', () {
    final game = TowerGame();
    game.setViewport(const Size(400, 700));

    for (var press = 0; press < 400; press++) {
      if (!game.canBuild) settle(game);
      final before = game.floorsBuilt;
      game.build();
      settle(game);
      if (game.roundActive) {
        expect(game.floorsBuilt - before, inInclusiveRange(1, 3));
      }
    }
  });

  test('the tower never walks away from the centre', () {
    final game = TowerGame();
    game.setViewport(const Size(400, 700));

    for (var press = 0; press < 400; press++) {
      if (!game.canBuild) settle(game);
      game.build();
      settle(game);
      for (final block in game.tower) {
        expect(block.x.abs(), lessThan(0.2));
      }
    }
  });

  test('cashout pays the current multiplier and closes the round', () {
    final game = TowerGame();
    game.setViewport(const Size(400, 700));
    final start = game.balance;

    game.build();
    settle(game);
    if (!game.roundActive) return; // first floor missed, nothing to cash out
    final expected = game.cashoutAmount;
    game.cashout();
    expect(game.balance, closeTo(start - game.bet + expected, 0.001));
    settle(game);
    expect(game.roundActive, isFalse);
  });
}
