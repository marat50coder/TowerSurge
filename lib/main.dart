import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'core/palette.dart';
import 'core/store.dart';
import 'tide/tide_coordinator.dart';
import 'tide/tide_deck_app.dart';
import 'tide/wire/chime_channel.dart';
import 'tide/wire/fabric_store.dart';
import 'tide/wire/fingerprint_tag.dart';
import 'tide/wire/link_pulse.dart';
import 'tide/wire/ruling_call.dart';
import 'tide/wire/signal_pulse.dart';

// ============================================================
// Bootstrap sequence — order matters:
//   1. WidgetsFlutterBinding                — plugin channels ready.
//   2. Firebase + AppCheck (best-effort)    — never blocks startup;
//      failures here silently fall through to the game path via
//      `HarborConfig.harborReady == false`.
//   3. System UI + orientation              — set once so the pier
//      renders edge-to-edge on frame one.
//   4. Local `Store` (white-game prefs)     — must exist before the
//      game screen boots.
//   5. `FingerprintTag.prime`               — forged UA is built
//      before any HTTP client or WebView is constructed.
//   6. `FabricStore.prime`                  — reads shared_preferences
//      into memory so the coordinator can decide synchronously.
//   7. Assemble the tide pipeline and hand it to `TideDeckApp`.
// ============================================================

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    if (Firebase.apps.isEmpty) {
      await Firebase.initializeApp();
    }
    await FirebaseAppCheck.instance.activate(
      providerAndroid: kDebugMode
          ? const AndroidDebugProvider()
          : const AndroidPlayIntegrityProvider(),
    );
  } catch (_) {
    // Missing google-services.json or unsupported platform — the
    // tide pipeline degrades gracefully to the native game path.
  }

  SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
      systemNavigationBarColor: P.bottomPanel,
      systemNavigationBarIconBrightness: Brightness.light,
    ),
  );

  // The pier is orientation-flexible; the game locks portrait once
  // the pier hands off.
  await SystemChrome.setPreferredOrientations(const <DeviceOrientation>[
    DeviceOrientation.portraitUp,
    DeviceOrientation.landscapeLeft,
    DeviceOrientation.landscapeRight,
  ]);

  await Store.init();
  await FingerprintTag.prime();

  final FabricStore store = FabricStore();
  await store.prime();

  final LinkPulse pulse = LinkPulse();
  final SignalPulse signal = SignalPulse();
  final RulingCall ruling = RulingCall(store);
  final ChimeChannel chime = ChimeChannel(store);

  final TideCoordinator coordinator = TideCoordinator(
    store: store,
    pulse: pulse,
    signal: signal,
    ruling: ruling,
    chime: chime,
  );

  runApp(TideDeckApp(
    coordinator: coordinator,
    store: store,
    chime: chime,
  ));
}
