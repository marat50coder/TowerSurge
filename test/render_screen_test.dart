import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:towersurgegame/core/game_images.dart';
import 'package:towersurgegame/core/store.dart';
import 'package:towersurgegame/screens/game_screen.dart';

/// Renders the whole game screen (scene + HUD) to PNG files for review.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    await Store.init();
    for (final weight in ['Bold', 'ExtraBold', 'Black']) {
      final loader = FontLoader('Nunito')
        ..addFont(rootBundle.load('assets/fonts/Nunito-$weight.ttf'));
      await loader.load();
    }
    await GameImages.i.load();
  });

  testWidgets('game screen renders', (tester) async {
    tester.view.physicalSize = const Size(1080, 2340);
    tester.view.devicePixelRatio = 2.625;
    addTearDown(tester.view.resetPhysicalSize);

    final key = GlobalKey();

    Future<void> shoot(String name) async {
      final boundary =
          key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
      final image = await tester.runAsync(
        () => boundary.toImage(pixelRatio: 1.2),
      );
      final data = await tester.runAsync(
        () => image!.toByteData(format: ui.ImageByteFormat.png),
      );
      File(
        '/tmp/screen_$name.png',
      ).writeAsBytesSync(data!.buffer.asUint8List());
    }

    Future<void> wait(int ms) async {
      for (var elapsed = 0; elapsed < ms; elapsed += 16) {
        await tester.pump(const Duration(milliseconds: 16));
      }
    }

    await tester.pumpWidget(
      RepaintBoundary(
        key: key,
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: ThemeData(fontFamily: 'Nunito'),
          home: const GameScreen(),
        ),
      ),
    );
    await wait(200);
    await shoot('idle');

    for (var round = 1; round <= 4; round++) {
      final build = find.text('BUILD');
      if (build.evaluate().isEmpty) break;
      await tester.tap(build);
      await wait(260);
      await shoot('drop$round');
      await wait(500);
      await shoot('landed$round');
      await wait(600);
    }
    await shoot('final');
  });
}
