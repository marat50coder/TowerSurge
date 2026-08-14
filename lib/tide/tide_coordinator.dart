import 'dart:async';
import 'dart:io';

import 'berth.dart';
import 'harbor_config.dart';
import 'wire/chime_channel.dart';
import 'wire/fabric_store.dart';
import 'wire/launch_note.dart';
import 'wire/link_pulse.dart';
import 'wire/ruling_call.dart';
import 'wire/signal_pulse.dart';

// ============================================================
// TIDE COORDINATOR — single boot-decision entry point
// ============================================================
// One method: [decide]. The pier screen calls it, then switches on
// the returned `Berth`. No other file emits a Berth. The pipeline
// branches on the persisted `RoutingMemory`:
//
//   pending (first launch)
//     ├─ no adapter        → AdriftBerth(returnsToGame: false)
//     ├─ DNS probe fails   → AdriftBerth(returnsToGame: false)
//     ├─ ruling approved   → save harbor → HarborBerth(url)
//     └─ ruling rejected   → save homeGame → HomeGameBerth
//
//   harbor (was in the WebView)
//     ├─ no adapter        → AdriftBerth(returnsToGame: false)
//     ├─ pending push URL  → HarborBerth(url, pushOrigin: true)
//     ├─ fresh cached URL  → HarborBerth(cachedUrl)
//     ├─ ruling approved   → HarborBerth(freshUrl)
//     ├─ ruling rejected but cache exists
//     │                    → HarborBerth(cachedUrl)  (last-known-good)
//     └─ otherwise         → AdriftBerth(returnsToGame: false)
//
//   homeGame (was in the game)
//     ├─ no adapter        → HomeGameBerth (never blocks)
//     ├─ ruling approved   → save harbor → HarborBerth(url)
//     └─ ruling rejected   → HomeGameBerth
//
// Concurrent calls are de-duplicated — a synchronous double invoke
// (e.g. the pier screen briefly building twice) will not fire two
// verdict POSTs. Cache clears on completion so an Adrift retry
// re-runs the pipeline in full.
// ============================================================

class TideCoordinator {
  TideCoordinator({
    required this.store,
    required this.pulse,
    required this.signal,
    required this.ruling,
    required this.chime,
  });

  final FabricStore store;
  final LinkPulse pulse;
  final SignalPulse signal;
  final RulingCall ruling;
  final ChimeChannel chime;

  Future<Berth>? _pending;

  Future<Berth> decide({void Function(double)? onProgress}) {
    return _pending ??= _decide(onProgress ?? (_) {})
        .whenComplete(() => _pending = null);
  }

  Future<Berth> _decide(void Function(double) onProgress) async {
    if (!HarborConfig.harborReady) {
      onProgress(1);
      return const HomeGameBerth();
    }

    chime.onTokenRotate = _reruleOnTokenRotate;

    // Raise the FCM channel FIRST so `getInitialMessage()` runs, its
    // callback populates the in-memory cold-tap URL, and the message
    // listeners are wired for the rest of the session. Doing this
    // before the routing switch also means a pending URL stashed by
    // a previous session's warm-tap is now guaranteed to be readable
    // before the switch, and this session's cold-tap URL doesn't get
    // lost to a race with the secure-storage write.
    try {
      await chime.raise();
    } catch (_) {}

    // A cold-boot push tap wins over any cached state.
    final String coldTap = chime.consumeColdTapUrl() ?? '';
    final String stashed = (await LaunchNote.consume(store)) ?? '';
    final String coldUrl = coldTap.isNotEmpty ? coldTap : stashed;
    if (coldUrl.isNotEmpty) {
      await store.assignRoute(RoutingMemory.harbor);
      unawaited(_fireAndForget());
      onProgress(1);
      return HarborBerth(coldUrl, pushOrigin: true);
    }

    onProgress(0.14);
    return switch (store.route) {
      RoutingMemory.pending => _decidePending(onProgress),
      RoutingMemory.harbor => _decideReturningHarbor(onProgress),
      RoutingMemory.homeGame => _decideReturningGame(onProgress),
    };
  }

  Future<Berth> _decidePending(void Function(double) onProgress) async {
    if (!await pulse.hasAdapter()) {
      return const AdriftBerth(returnsToGame: false);
    }
    onProgress(0.28);
    try {
      await chime.raise();
    } catch (_) {}
    if (!await pulse.canReach()) {
      return const AdriftBerth(returnsToGame: false);
    }
    onProgress(0.48);
    await signal.boot();
    await signal.awaitSignals(
      installSeconds: HarborConfig.firstInstallAwaitSeconds,
    );
    onProgress(0.72);
    final Ruling reply = await _askRuling();
    onProgress(1);
    if (reply.hasDestination) {
      await store.assignRoute(RoutingMemory.harbor);
      return HarborBerth(reply.destination!);
    }
    await store.assignRoute(RoutingMemory.homeGame);
    return const HomeGameBerth();
  }

  Future<Berth> _decideReturningHarbor(
    void Function(double) onProgress,
  ) async {
    if (!await pulse.hasAdapter()) {
      return const AdriftBerth(returnsToGame: false);
    }
    // `chime.raise()` is already awaited at the top of `_decide`, so
    // the FCM listeners are wired even when this path returns the
    // cached URL early. No additional call needed here — the
    // duplicate would be a no-op (idempotent guard inside `raise`).
    final String? pending = await store.consumePendingUrl();
    if (pending != null && pending.isNotEmpty) {
      onProgress(1);
      return HarborBerth(pending);
    }
    final String? cached = await store.cachedDestination();
    if (cached != null && !store.cachedDestinationExpired) {
      onProgress(1);
      return HarborBerth(cached);
    }

    await Future.wait<void>(<Future<void>>[
      chime.raise(),
      signal.boot(),
    ]);
    if (!await pulse.canReach()) {
      if (cached != null) {
        return HarborBerth(cached);
      }
      return const AdriftBerth(returnsToGame: false);
    }
    onProgress(0.58);
    await signal.awaitSignals(
      installSeconds: HarborConfig.returningInstallAwaitSeconds,
    );
    final Ruling reply = await _askRuling();
    onProgress(1);
    if (reply.hasDestination) return HarborBerth(reply.destination!);
    if (cached != null) return HarborBerth(cached);
    return const AdriftBerth(returnsToGame: false);
  }

  Future<Berth> _decideReturningGame(
    void Function(double) onProgress,
  ) async {
    if (!await pulse.hasAdapter()) {
      onProgress(1);
      return const HomeGameBerth();
    }
    await Future.wait<void>(<Future<void>>[
      chime.raise(),
      signal.boot(),
    ]);
    if (!await pulse.canReach()) {
      onProgress(1);
      return const HomeGameBerth();
    }
    onProgress(0.53);
    await signal.awaitSignals(
      installSeconds: HarborConfig.returningInstallAwaitSeconds,
    );
    final Ruling reply = await _askRuling();
    onProgress(1);
    if (!reply.hasDestination) return const HomeGameBerth();
    await store.assignRoute(RoutingMemory.harbor);
    return HarborBerth(reply.destination!);
  }

  Future<Ruling> _askRuling({String? token}) async {
    final Map<String, dynamic> body = await signal.compose(
      locale: Platform.localeName.replaceAll('-', '_'),
      pushToken: token ?? chime.token,
    );
    return ruling.ask(body);
  }

  Future<void> _fireAndForget() async {
    try {
      await Future.wait<void>(<Future<void>>[
        chime.raise(),
        signal.boot(),
      ]);
      await signal.awaitSignals(
        installSeconds: HarborConfig.returningInstallAwaitSeconds,
      );
      await _askRuling();
    } catch (_) {}
  }

  Future<void> _reruleOnTokenRotate(String token) async {
    try {
      await _askRuling(token: token);
    } catch (_) {}
  }
}
