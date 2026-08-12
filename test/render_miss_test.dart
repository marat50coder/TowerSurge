import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:towersurgegame/core/game_images.dart';
import 'package:towersurgegame/core/store.dart';
import 'package:towersurgegame/game/scene_painter.dart';
import 'package:towersurgegame/game/tower_game.dart';

/// Renders the frames of a missed floor so the impact can be reviewed without
/// a device: the floor clips the tower, tumbles off and the tower stays up.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const size = Size(411, 690);

  test('missed floor sequence', () async {
    SharedPreferences.setMockInitialValues({});
    await Store.init();
    for (final weight in ['Bold', 'ExtraBold', 'Black']) {
      final loader = FontLoader('Nunito')
        ..addFont(rootBundle.load('assets/fonts/Nunito-$weight.ttf'));
      await loader.load();
    }
    await GameImages.i.load();

    final game = TowerGame();
    game.setViewport(size);

    Future<void> shoot(String name) async {
      final recorder = ui.PictureRecorder();
      ScenePainter(game).paint(Canvas(recorder), size);
      final image = await recorder.endRecording().toImage(
        size.width.round(),
        size.height.round(),
      );
      final data = await image.toByteData(format: ui.ImageByteFormat.png);
      File('/tmp/miss_$name.png').writeAsBytesSync(data!.buffer.asUint8List());
    }

    void settle() {
      for (var i = 0; i < 600 && !game.canBuild; i++) {
        game.tick(1 / 60);
        if (game.templeSpinning) game.applyTempleResult(3);
      }
    }

    // Stack a few floors, then keep building until a floor misses.
    var guard = 0;
    while (game.floorsBuilt < 3 && guard++ < 60) {
      if (!game.canBuild) settle();
      game.build();
      settle();
    }
    await shoot('before');

    guard = 0;
    while (game.roundActive && guard++ < 60) {
      game.build();
      // Watch the drop frame by frame; stop as soon as the floor is loose.
      for (var i = 0; i < 200; i++) {
        game.tick(1 / 60);
        if (game.debris.isNotEmpty) break;
      }
      if (game.debris.isNotEmpty) break;
      settle();
    }

    expect(game.debris, isNotEmpty, reason: 'no missed floor in 60 tries');
    expect(game.tower.length, greaterThan(1), reason: 'tower must stay up');

    await shoot('impact');
    for (var i = 0; i < 18; i++) {
      game.tick(1 / 60);
    }
    await shoot('falling');
    for (var i = 0; i < 30; i++) {
      game.tick(1 / 60);
    }
    await shoot('gone');
  });
}
