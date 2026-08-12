import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:towersurgegame/core/game_images.dart';
import 'package:towersurgegame/core/store.dart';
import 'package:towersurgegame/game/scene_painter.dart';
import 'package:towersurgegame/game/tower_game.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('sprites load and the scene paints without throwing', () async {
    SharedPreferences.setMockInitialValues({});
    await Store.init();
    await GameImages.i.load();
    expect(GameImages.i.loaded, isTrue);
    expect(GameImages.i.blocks.length, 4);

    final game = TowerGame();
    game.setViewport(const Size(400, 700));
    game.tick(0.016);

    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    ScenePainter(game).paint(canvas, const Size(400, 700));
    recorder.endRecording();

    expect(game.tower.length, 1);
    expect(game.tower.first.heightUnits, greaterThan(0));
  });
}
