import 'dart:async';

import 'package:flutter/material.dart';

import '../core/palette.dart';
import 'harbor_config.dart';
import 'pier_screen.dart';
import 'stage/harbor_stage.dart';
import 'tide_coordinator.dart';
import 'wire/chime_channel.dart';
import 'wire/fabric_store.dart';

/// Root widget for the tide flow. Holds the long-lived
/// infrastructure (fabric store, chime channel, coordinator) and
/// hands them to the pier.
class TideDeckApp extends StatefulWidget {
  const TideDeckApp({
    super.key,
    required this.coordinator,
    required this.store,
    required this.chime,
  });

  final TideCoordinator coordinator;
  final FabricStore store;
  final ChimeChannel chime;

  @override
  State<TideDeckApp> createState() => _TideDeckAppState();
}

class _TideDeckAppState extends State<TideDeckApp> {
  final GlobalKey<NavigatorState> _navKey = GlobalKey<NavigatorState>();
  StreamSubscription<String>? _pushSub;

  @override
  void initState() {
    super.initState();
    // Warm-tap fallback: a push arrived while HarborStage isn't on
    // screen (splash, tempest, prompt, game). Rebuild the tree to a
    // HarborStage on the URL so the notification always opens the
    // correct page — the bug the user reported as "notifications
    // don't always take you to the right page".
    _pushSub = widget.chime.warmTapFallback.listen(_openHarborFor);
  }

  void _openHarborFor(String url) {
    final NavigatorState? nav = _navKey.currentState;
    if (nav == null) return;
    nav.pushReplacement(
      MaterialPageRoute<void>(
        builder: (_) => HarborStage(
          url: url,
          store: widget.store,
          chime: widget.chime,
        ),
      ),
    );
  }

  @override
  void dispose() {
    _pushSub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: HarborConfig.displayName,
      debugShowCheckedModeBanner: false,
      navigatorKey: _navKey,
      theme: ThemeData(
        useMaterial3: true,
        fontFamily: T.family,
        scaffoldBackgroundColor: P.skyTop,
        colorScheme: ColorScheme.fromSeed(
          seedColor: P.blue,
          brightness: Brightness.dark,
        ),
      ),
      builder: (BuildContext context, Widget? child) =>
          MediaQuery.withNoTextScaling(child: child ?? const SizedBox.shrink()),
      home: PierScreen(
        coordinator: widget.coordinator,
        store: widget.store,
        chime: widget.chime,
      ),
    );
  }
}
