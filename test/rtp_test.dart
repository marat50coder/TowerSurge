import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:towersurgegame/core/store.dart';
import 'package:towersurgegame/game/tower_game.dart';
import 'package:towersurgegame/widgets/temple_wheel.dart';

/// Monte Carlo check of the payout model: whatever number of floors the player
/// stops at, the return stays in a sane band. Short and mid strategies sit near
/// the advertised 97%; very long towers return a little less because the x100
/// cap truncates their upside and there is no frozen safety net any more.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'return to player stays in a sane band for every stopping strategy',
    () async {
      SharedPreferences.setMockInitialValues({});
      await Store.init();
      final game = TowerGame();
      final rng = math.Random(7);

      for (final stopAfter in [1, 3, 6, 12]) {
        const rounds = 120000;
        var returned = 0.0;
        for (var round = 0; round < rounds; round++) {
          var total = 1.0;
          var floors = 0;
          var alive = true;
          while (alive && floors < stopAfter) {
            final outcome = game.rollFloor(floors + 1);
            if (outcome.failed) {
              alive = false;
              break;
            }
            floors++;
            total = math.min(
              TowerGame.maxMultiplier,
              total * outcome.multiplier,
            );
            switch (outcome.kind) {
              case FloorKind.temple:
                final segment = TempleWheel
                    .segments[rng.nextInt(TempleWheel.segments.length)];
                total = math.min(TowerGame.maxMultiplier, total * segment);
                break;
              case FloorKind.triple:
                for (var extra = 0; extra < 2 && floors < stopAfter; extra++) {
                  floors++;
                  total = math.min(
                    TowerGame.maxMultiplier,
                    total * game.safeMultiplier(),
                  );
                }
                break;
              case FloorKind.normal:
                break;
            }
          }
          returned += alive ? total : 0;
        }
        final rtp = returned / rounds;
        expect(rtp, greaterThan(0.88), reason: 'stopAfter=$stopAfter rtp=$rtp');
        expect(rtp, lessThan(1.03), reason: 'stopAfter=$stopAfter rtp=$rtp');
        // ignore: avoid_print
        print(
          'stop after $stopAfter floors -> RTP ${(rtp * 100).toStringAsFixed(2)}%',
        );
      }
    },
  );
}
