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

/// Renders the game scene straight to PNG files so the artwork can be reviewed
/// without a device. Run with: flutter test test/render_scene_test.dart
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const size = Size(411, 690);

  Future<void> shoot(TowerGame game, String name) async {
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    ScenePainter(game).paint(canvas, size);
    final picture = recorder.endRecording();
    final image = await picture.toImage(
      size.width.round(),
      size.height.round(),
    );
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    File('/tmp/scene_$name.png').writeAsBytesSync(data!.buffer.asUint8List());
  }

  Future<void> loadFonts() async {
    for (final weight in ['Bold', 'ExtraBold', 'Black']) {
      final loader = FontLoader('Nunito')
        ..addFont(rootBundle.load('assets/fonts/Nunito-$weight.ttf'));
      await loader.load();
    }
  }

  test('render scene snapshots', () async {
    SharedPreferences.setMockInitialValues({});
    await Store.init();
    await loadFonts();
    await GameImages.i.load();

    final game = TowerGame();
    game.setViewport(size);
    for (var i = 0; i < 30; i++) {
      game.tick(1 / 60);
    }
    await shoot(game, 'idle');

    // Build a few floors.
    game.build();
    for (var i = 0; i < 240; i++) {
      game.tick(1 / 60);
    }
    await shoot(game, 'after_first');

    for (var round = 0; round < 3; round++) {
      if (game.phase == Phase.ready) game.build();
      for (var i = 0; i < 120; i++) {
        game.tick(1 / 60);
      }
    }
    await shoot(game, 'stack');

    expect(File('/tmp/scene_idle.png').existsSync(), isTrue);
    expect(File('/tmp/scene_stack.png').existsSync(), isTrue);
  });
}
