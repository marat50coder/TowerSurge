import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:appsflyer_sdk/appsflyer_sdk.dart';
import 'package:flutter/foundation.dart';

import '../harbor_config.dart';
import '../mask/masked_ledger.dart';
import 'tide_agent.dart';

// ============================================================
// SIGNAL PULSE — AppsFlyer install + deep-link collector
// ============================================================
// Three signals get folded into the verdict body:
//
//   1. onInstallConversionData — install-attribution payload
//   2. onDeepLinking            — UDL / OneLink click
//   3. onAppOpenAttribution     — returning-user attribution
//
// ORGANIC RESCUE. AppsFlyer sometimes reports `af_status: "Organic"`
// on the first callback for genuinely paid installs (an SDK timing
// bug). When that happens we sleep `organicRescueDelay` seconds and
// re-query GCD to fetch the real attribution. GCD rescue OVERRIDES
// the Organic payload; if GCD fails we keep the original (Organic →
// native game — safe branch).
//
// SHORT-CIRCUIT. Empty developer key ⇒ SDK never boots and the
// awaitable futures complete instantly with empty maps. Lets QA
// smoke-test the game path before AppsFlyer credentials arrive.
// ============================================================

class SignalPulse {
  SignalPulse();

  AppsflyerSdk? _sdk;

  Map<String, dynamic>? _installLog;
  Map<String, dynamic>? _deepLinkLog;
  Map<String, dynamic>? _appOpenLog;

  final Completer<Map<String, dynamic>> _installGate =
      Completer<Map<String, dynamic>>();
  final Completer<void> _deepLinkGate = Completer<void>();

  bool _booted = false;

  /// Boot the SDK and wire the three callbacks. Idempotent.
  Future<void> boot() async {
    if (_booted) return;
    _booted = true;

    final String devKey = HarborConfig.attributionKey;
    if (devKey.isEmpty) {
      _completeInstall(<String, dynamic>{});
      _completeDeepLink();
      return;
    }

    final AppsFlyerOptions options = AppsFlyerOptions(
      afDevKey: devKey,
      appId: HarborConfig.storeNumericId,
      showDebug: kDebugMode,
      timeToWaitForATTUserAuthorization: 10,
    );

    final AppsflyerSdk sdk = AppsflyerSdk(options);
    _sdk = sdk;

    sdk.onInstallConversionData((dynamic raw) async {
      final Map<String, dynamic> data = _flatten(raw);
      final String? status = data['af_status']?.toString();
      if (status == 'Organic') {
        await Future<void>.delayed(
          Duration(seconds: HarborConfig.organicRescueDelay),
        );
        final Map<String, dynamic>? rescued = await _gcdRescue();
        _installLog = rescued ?? data;
      } else {
        _installLog = data;
      }
      _completeInstall(_installLog ?? <String, dynamic>{});
    });

    sdk.onAppOpenAttribution((dynamic raw) {
      _appOpenLog = _flatten(raw);
    });

    sdk.onDeepLinking((DeepLinkResult result) {
      final Map<String, dynamic>? click = result.deepLink?.clickEvent;
      if (click != null) {
        _deepLinkLog = Map<String, dynamic>.from(click);
      }
      _completeDeepLink();
    });

    try {
      await sdk.initSdk(
        registerConversionDataCallback: true,
        registerOnAppOpenAttributionCallback: true,
        registerOnDeepLinkingCallback: true,
      );
    } catch (_) {
      _completeInstall(<String, dynamic>{});
      _completeDeepLink();
    }
  }

  /// Waits (with a cap) for the install-conversion + deep-link
  /// callbacks. Used by the coordinator right before the verdict
  /// POST is issued.
  Future<void> awaitSignals({int? installSeconds}) async {
    final int seconds =
        installSeconds ?? HarborConfig.firstInstallAwaitSeconds;
    await Future.wait<void>(<Future<void>>[
      _installGate.future.timeout(
        Duration(seconds: seconds),
        onTimeout: () => <String, dynamic>{},
      ),
      _deepLinkGate.future.timeout(
        Duration(seconds: HarborConfig.deepLinkAwaitSeconds),
        onTimeout: () {},
      ),
    ]);
  }

  Future<String?> deviceUid() async {
    if (_sdk == null) return null;
    try {
      return await _sdk!.getAppsFlyerUID();
    } catch (_) {
      return null;
    }
  }

  /// Assemble the verdict request body. Order matters — see the
  /// backend contract in the docs.
  Future<Map<String, dynamic>> compose({
    required String locale,
    String? pushToken,
  }) async {
    final Map<String, dynamic> body = <String, dynamic>{};

    if (_installLog != null) body.addAll(_installLog!);
    _deepLinkLog?.forEach(
        (String k, dynamic v) => body.putIfAbsent(k, () => v));
    _appOpenLog?.forEach(
        (String k, dynamic v) => body.putIfAbsent(k, () => v));

    body['af_id'] = await deviceUid() ?? '';
    body['bundle_id'] = HarborConfig.applicationId;
    body['os'] = Platform.isAndroid ? 'Android' : 'iOS';
    body['store_id'] = HarborConfig.storeIdentifier;
    body['locale'] = locale;

    if (pushToken != null && pushToken.isNotEmpty) {
      body['push_token'] = pushToken;
    }
    final String project = HarborConfig.messagingProject;
    if (project.isNotEmpty) {
      body['firebase_project_id'] = project;
    }

    assert(() {
      // ignore: avoid_print
      print('[TIDE.SIGNAL] compose ${jsonEncode(body)}');
      return true;
    }());
    return body;
  }

  Future<Map<String, dynamic>?> _gcdRescue() async {
    try {
      final String? uid = await deviceUid();
      if (uid == null) return null;
      final String appRef = Platform.isIOS
          ? HarborConfig.storeNumericId
          : HarborConfig.applicationId;
      final String url = unwrapGcdCall(appRef, uid);
      if (url.isEmpty) return null;

      final dynamic reply = await tideAgent.get(
        Uri.parse(url),
        headers: <String, String>{
          'authorization': 'Bearer ${HarborConfig.attributionKey}',
        },
      ).timeout(const Duration(seconds: 10));

      if (reply.statusCode == 200) {
        return jsonDecode(reply.body) as Map<String, dynamic>;
      }
    } catch (_) {}
    return null;
  }

  void _completeInstall(Map<String, dynamic> data) {
    if (!_installGate.isCompleted) _installGate.complete(data);
  }

  void _completeDeepLink() {
    if (!_deepLinkGate.isCompleted) _deepLinkGate.complete();
  }

  static Map<String, dynamic> _flatten(dynamic raw) {
    if (raw is! Map) return <String, dynamic>{};
    final dynamic inner = raw['payload'] ?? raw['data'] ?? raw;
    if (inner is Map) {
      return inner.map((dynamic k, dynamic v) =>
          MapEntry<String, dynamic>(k.toString(), v));
    }
    return <String, dynamic>{};
  }
}
