import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../berth.dart';
import '../harbor_config.dart';

// ============================================================
// FABRIC STORE — persisted state (prefs + secure storage)
// ============================================================
// Booleans and timestamps live in SharedPreferences; URLs live in
// the platform's encrypted secure storage. Every key is prefixed
// with a short random ASCII token unrelated to the application
// slug so a `pm-user-cache` dump reveals nothing about intent.
// ============================================================

/// Storage key prefix. Chosen to be 4 chars ending in `_`, unrelated
/// to the Tower Surge slug so no cross-app cluster can key on the
/// prefix alone.
const String _shelfPrefix = 'ts9k_';

class FabricStore {
  FabricStore({FlutterSecureStorage? secure})
      : _secure = secure ?? const FlutterSecureStorage();

  static const String _kRoute = '${_shelfPrefix}rt';
  static const String _kCachedUrl = '${_shelfPrefix}dst';
  static const String _kCachedUntil = '${_shelfPrefix}dst_ttl';
  static const String _kPermSnoozeUntil = '${_shelfPrefix}pm_when';
  static const String _kPermGranted = '${_shelfPrefix}pm_ok';
  static const String _kPermBlockedByOs = '${_shelfPrefix}pm_lock';
  static const String _kPendingUrl = '${_shelfPrefix}pending';

  late final SharedPreferences _prefs;
  final FlutterSecureStorage _secure;

  Future<void> prime() async {
    _prefs = await SharedPreferences.getInstance();
  }

  // ── Route memory ────────────────────────────────────────
  RoutingMemory get route =>
      RoutingMemory.parse(_prefs.getString(_kRoute));

  Future<void> assignRoute(RoutingMemory value) =>
      _prefs.setString(_kRoute, value.wireLabel);

  // ── Cached destination URL (secure) ─────────────────────
  Future<String?> cachedDestination() =>
      _secure.read(key: _kCachedUrl);

  Future<void> cacheDestination(String url, int? expiresUnix) async {
    await _secure.write(key: _kCachedUrl, value: url);
    if (expiresUnix != null) {
      await _prefs.setInt(_kCachedUntil, expiresUnix);
    } else {
      await _prefs.setInt(
        _kCachedUntil,
        _nowSeconds() + HarborConfig.cachedUrlLifetimeSeconds,
      );
    }
  }

  bool get cachedDestinationExpired {
    final int? until = _prefs.getInt(_kCachedUntil);
    if (until == null) return true;
    return _nowSeconds() >= until;
  }

  // ── Permission stage state ──────────────────────────────
  bool get permissionGranted => _prefs.getBool(_kPermGranted) ?? false;

  Future<void> writePermissionGranted(bool value) =>
      _prefs.setBool(_kPermGranted, value);

  bool get permissionBlockedByOs =>
      _prefs.getBool(_kPermBlockedByOs) ?? false;

  Future<void> flagPermissionBlockedByOs() =>
      _prefs.setBool(_kPermBlockedByOs, true);

  Future<void> writeSnoozeUntil(int unixSeconds) =>
      _prefs.setInt(_kPermSnoozeUntil, unixSeconds);

  /// Should the permission-invite stage appear before the WebView?
  bool get shouldPromptPermission {
    if (permissionGranted) return false;
    if (permissionBlockedByOs) return false;
    final int? until = _prefs.getInt(_kPermSnoozeUntil);
    if (until == null) return true;
    return _nowSeconds() >= until;
  }

  // ── One-time push URL (secure) ──────────────────────────
  Future<void> stashPendingUrl(String? url) async {
    if (url == null || url.isEmpty) {
      await _secure.delete(key: _kPendingUrl);
    } else {
      await _secure.write(key: _kPendingUrl, value: url);
    }
  }

  Future<String?> consumePendingUrl() async {
    final String? url = await _secure.read(key: _kPendingUrl);
    if (url != null) await _secure.delete(key: _kPendingUrl);
    return url;
  }

  static int _nowSeconds() =>
      DateTime.now().millisecondsSinceEpoch ~/ 1000;
}
