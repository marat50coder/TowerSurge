import 'dart:async';

import 'package:flutter/services.dart';

// ============================================================
// INTENT BRIDGE — launch-URL absorber
// ============================================================
// AppsFlyer's UDL callback occasionally drops OneLink clicks on the
// floor (adb-installed builds, GAID collection hiccups, unverified
// assetlinks, Chrome App Links routing the intent past the referrer,
// etc). In every one of those cases the URL still sits in
// `getIntent().getData()` — so we mine it directly through this
// channel and inject the query params into the deep-link payload.
//
// The native counterpart is `MainActivity.kt` under the channel
// name `surgefort/tide/intent`. Keep the string in sync there.
// ============================================================

class IntentBridge {
  IntentBridge._();
  static final IntentBridge instance = IntentBridge._();

  static const MethodChannel _channel =
      MethodChannel('surgefort/tide/intent');

  final StreamController<String> _warmTapCtrl =
      StreamController<String>.broadcast();

  bool _wired = false;

  /// Fires whenever a warm-tap paid link opens the app while it's
  /// already running (backed by `onNewIntent` on the Kotlin side).
  Stream<String> get warmTapUrls => _warmTapCtrl.stream;

  /// Attach the callback handler. Idempotent.
  void prime() {
    if (_wired) return;
    _wired = true;
    _channel.setMethodCallHandler((MethodCall call) async {
      if (call.method == 'onNewLaunchUrl') {
        final Object? arg = call.arguments;
        if (arg is String && arg.isNotEmpty) {
          _warmTapCtrl.add(arg);
        }
      }
    });
  }

  /// Reads the launching URL from `getIntent().getData()`. Returns
  /// `null` on non-VIEW intents or when no launch URL is cached.
  Future<String?> pullLaunchUrl() async {
    try {
      final String? url =
          await _channel.invokeMethod<String>('getLaunchUrl');
      if (url == null || url.isEmpty) return null;
      return url;
    } catch (_) {
      return null;
    }
  }

  /// Ask the native side to forget the cached launch URL so it
  /// doesn't re-fire on the next configuration change.
  Future<void> consumeLaunchUrl() async {
    try {
      await _channel.invokeMethod('consumeLaunchUrl');
    } catch (_) {}
  }
}
