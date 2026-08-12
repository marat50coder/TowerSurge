import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:towersurgegame/core/game_images.dart';
import 'package:towersurgegame/core/store.dart';
import 'package:towersurgegame/widgets/menu_sheet.dart';
import 'package:towersurgegame/widgets/temple_wheel.dart';
import 'package:towersurgegame/game/tower_game.dart';

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

  Future<void> shoot(WidgetTester tester, GlobalKey key, String name) async {
    final boundary =
        key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
    final image = await tester.runAsync(
      () => boundary.toImage(pixelRatio: 1.1),
    );
    final data = await tester.runAsync(
      () => image!.toByteData(format: ui.ImageByteFormat.png),
    );
    File('/tmp/ui_$name.png').writeAsBytesSync(data!.buffer.asUint8List());
  }

  Future<GlobalKey> mount(
    WidgetTester tester,
    Widget home, {
    Size? size,
  }) async {
    tester.view.physicalSize = size ?? const Size(1080, 2340);
    tester.view.devicePixelRatio = 2.625;
    addTearDown(tester.view.resetPhysicalSize);
    final key = GlobalKey();
    await tester.pumpWidget(
      RepaintBoundary(
        key: key,
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: ThemeData(fontFamily: 'Nunito'),
          home: home,
        ),
      ),
    );
    for (var i = 0; i < 40; i++) {
      await tester.pump(const Duration(milliseconds: 16));
    }
    return key;
  }

  testWidgets('temple wheel', (tester) async {
    final key = await mount(
      tester,
      Scaffold(
        backgroundColor: const Color(0xFF3AA0E8),
        body: TempleWheel(onDone: (_) {}),
      ),
    );
    await shoot(tester, key, 'temple_wheel');
  });

  testWidgets('menu and info sheets', (tester) async {
    final game = TowerGame();
    final key = await mount(
      tester,
      Builder(
        builder: (context) => Scaffold(
          backgroundColor: const Color(0xFF3AA0E8),
          body: Center(
            child: ElevatedButton(
              onPressed: () => showGameMenu(context, game),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    for (var i = 0; i < 40; i++) {
      await tester.pump(const Duration(milliseconds: 16));
    }
    await shoot(tester, key, 'menu');

    await tester.tap(find.text('How to play'));
    for (var i = 0; i < 60; i++) {
      await tester.pump(const Duration(milliseconds: 16));
    }
    await shoot(tester, key, 'info');
  });
}
