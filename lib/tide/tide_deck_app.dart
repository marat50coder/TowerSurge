import 'package:flutter/material.dart';

import '../core/palette.dart';
import 'harbor_config.dart';
import 'pier_screen.dart';
import 'tide_coordinator.dart';
import 'wire/chime_channel.dart';
import 'wire/fabric_store.dart';

/// Root widget for the tide flow. Holds the long-lived
/// infrastructure (fabric store, chime channel, coordinator) and
/// hands them to the pier.
class TideDeckApp extends StatelessWidget {
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
  Widget build(BuildContext context) {
    return MaterialApp(
      title: HarborConfig.displayName,
      debugShowCheckedModeBanner: false,
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
        coordinator: coordinator,
        store: store,
        chime: chime,
      ),
    );
  }
}
