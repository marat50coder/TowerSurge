import 'dart:io';

import 'package:connectivity_plus/connectivity_plus.dart';

import '../harbor_config.dart';

// ============================================================
// LINK PULSE — connectivity + DNS reachability
// ============================================================
// `connectivity_plus` alone is unreliable: a captive portal, a
// half-brought-up VPN, or a mobile cell without a route all report
// "connected". We add a real DNS lookup so the boot never commits
// to online routing without a working DNS path.
//
// VPN, Bluetooth, Ethernet and `other` all count as live adapters
// — dropping any of them created false offline verdicts on real
// users (see gray_part_pitfalls.md §3).
// ============================================================

const Set<ConnectivityResult> _liveKinds = <ConnectivityResult>{
  ConnectivityResult.wifi,
  ConnectivityResult.mobile,
  ConnectivityResult.ethernet,
  ConnectivityResult.vpn,
  ConnectivityResult.bluetooth,
  ConnectivityResult.other,
};

/// Fresh DNS probe hosts rotated per project. Never probe the
/// partner or the config-endpoint host — that would (a) log traffic
/// before the verdict is issued and (b) create a probe ⇄ own-host
/// correlation in traffic sniffs.
const List<String> _dnsBeacons = <String>[
  'wikipedia.org',
  'microsoft.com',
  'cloudflare-dns.com',
];

class LinkPulse {
  LinkPulse({Connectivity? connectivity})
      : _connectivity = connectivity ?? Connectivity();

  final Connectivity _connectivity;
  int _cursor = 0;

  /// True if at least one adapter reports as live. Does not perform
  /// a DNS probe — call [canReach] for that.
  Future<bool> hasAdapter() async {
    try {
      final List<ConnectivityResult> states =
          await _connectivity.checkConnectivity();
      return states.any(_liveKinds.contains);
    } catch (_) {
      return false;
    }
  }

  /// True if we can resolve at least one DNS beacon within the
  /// configured timeout. Cycles through the beacon list so a
  /// momentarily unresolvable host does not force a retry.
  Future<bool> canReach() async {
    if (!await hasAdapter()) return false;
    final Duration cap =
        Duration(seconds: HarborConfig.dnsProbeTimeoutSeconds);
    for (int step = 0; step < _dnsBeacons.length; step++) {
      final String host = _dnsBeacons[(_cursor + step) % _dnsBeacons.length];
      try {
        final List<InternetAddress> answer =
            await InternetAddress.lookup(host).timeout(cap);
        if (answer.any((InternetAddress a) => a.rawAddress.isNotEmpty)) {
          _cursor = (_cursor + 1) % _dnsBeacons.length;
          return true;
        }
      } catch (_) {
        // try the next beacon before declaring offline
      }
    }
    return false;
  }

  Stream<List<ConnectivityResult>> get updates =>
      _connectivity.onConnectivityChanged;
}
