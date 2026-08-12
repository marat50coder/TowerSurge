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
      final DeepLink? dl = result.deepLink;
      if (dl != null) {
        final Map<String, dynamic> merged = <String, dynamic>{};
        final Map<String, dynamic> click = dl.clickEvent;
        merged.addAll(click);
        // Explicitly surface the typed getters — some partner OneLinks
        // deliver these through the DeepLink object but omit them from
        // the raw clickEvent map on Android.
        void put(String k, dynamic v) {
          if (v == null) return;
          final String s = '$v';
          if (s.isEmpty || s == 'null') return;
          merged[k] = v;
        }
        put('deep_link_value', dl.deepLinkValue);
        put('match_type', dl.matchType);
        put('media_source', dl.mediaSource);
        put('campaign', dl.campaign);
        put('campaign_id', dl.campaignId);
        put('is_deferred', dl.isDeferred);
        put('click_http_referrer', dl.clickHttpReferrer);
        put('af_sub1', dl.afSub1);
        put('af_sub2', dl.afSub2);
        put('af_sub3', dl.afSub3);
        put('af_sub4', dl.afSub4);
        put('af_sub5', dl.afSub5);
        _deepLinkLog = merged;
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

  /// Assemble the verdict request body. Order matters — the merge
  /// resolves conflicts as `deep_link > install > appOpen`, which
  /// is what the backend contract expects for OneLink installs.
  Future<Map<String, dynamic>> compose({
    required String locale,
    String? pushToken,
  }) async {
    final Map<String, dynamic> body = <String, dynamic>{};

    // Install-conversion is the baseline — includes it even when
    // some fields are empty strings so nothing gets silently dropped.
    if (_installLog != null) body.addAll(_installLog!);

    // Deep-link WINS over install for non-empty values (was
    // `putIfAbsent` before — that allowed a stale empty install value
    // to block a real OneLink sub_id from reaching the backend).
    _deepLinkLog?.forEach((String k, dynamic v) {
      if (v == null) return;
      final String s = '$v';
      if (s.isEmpty || s == 'null') return;
      body[k] = v;
    });

    // App-open payload only fills gaps, never overwrites.
    _appOpenLog?.forEach((String k, dynamic v) {
      if (v == null) return;
      final String s = '$v';
      if (s.isEmpty || s == 'null') return;
      body.putIfAbsent(k, () => v);
    });

    // Also unpack a query-string-shaped `deep_link_value`. Partners
    // often pack the sub_ids into it as `sub_id_1=..&sub_id_11=..`.
    _unpackDeepLinkValue(body);

    // Populate the identity fields BEFORE normalising the sub_ids so
    // the named-fallback branch (sub_id_5 ← bundle_id, sub_id_7 ←
    // push_token, sub_id_10 ← af_id, sub_id_11 ← media_source) can
    // resolve against them.
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

    // Normalise sub_id_1..sub_id_11 so the backend always sees the
    // full ladder regardless of which AppsFlyer field the partner
    // chose to route them through.
    _normaliseSubIds(body);

    assert(() {
      // ignore: avoid_print
      print('[TIDE.SIGNAL] compose ${jsonEncode(body)}');
      return true;
    }());
    return body;
  }

  /// If `deep_link_value` is a query-string blob (`sub_id_11=x&…`),
  /// split it and merge each key into `body`. Deep-link value wins
  /// over what's already there (it's the closest thing to source of
  /// truth for OneLink click params).
  static void _unpackDeepLinkValue(Map<String, dynamic> body) {
    final dynamic raw = body['deep_link_value'];
    if (raw is! String || raw.isEmpty) return;
    if (!raw.contains('=')) return;
    for (final String pair in raw.split('&')) {
      final int eq = pair.indexOf('=');
      if (eq <= 0) continue;
      final String k = Uri.decodeQueryComponent(pair.substring(0, eq));
      final String v = Uri.decodeQueryComponent(pair.substring(eq + 1));
      if (k.isEmpty || v.isEmpty) continue;
      body[k] = v;
    }
  }

  /// Emits `sub_id_1..sub_id_11` in the body. Priority order per slot:
  ///
  ///   sub_id_N  (already present, either from install or deep-link)
  ///   ↓
  ///   af_subN            (AppsFlyer standard, 1..5 only)
  ///   ↓
  ///   deep_link_subN     (UDL deferred, 1..10 only)
  ///   ↓
  ///   named fallback     (only 5 / 7 / 10 / 11 — slot-industry defaults
  ///                       that match the QA dashboard's expected shape:
  ///                       sub_id_5 = bundle_id,
  ///                       sub_id_7 = push_token,
  ///                       sub_id_10 = af_id,
  ///                       sub_id_11 = media_source).
  static void _normaliseSubIds(Map<String, dynamic> body) {
    for (int i = 1; i <= 11; i++) {
      final String target = 'sub_id_$i';
      if (_nonEmpty(body[target])) continue;

      if (i <= 5) {
        final Object? afSub = body['af_sub$i'];
        if (_nonEmpty(afSub)) {
          body[target] = afSub;
          continue;
        }
      }
      if (i <= 10) {
        final Object? dlSub = body['deep_link_sub$i'];
        if (_nonEmpty(dlSub)) {
          body[target] = dlSub;
          continue;
        }
      }

      // Named fallbacks — populate the well-known slots the QA
      // dashboard validates against.
      Object? fallback;
      switch (i) {
        case 5:
          fallback = body['bundle_id'];
        case 7:
          fallback = body['push_token'];
        case 10:
          fallback = body['af_id'];
        case 11:
          fallback = body['media_source'] ??
              body['mediaSource'] ??
              body['pid'];
      }
      if (_nonEmpty(fallback)) body[target] = fallback;
    }
  }

  static bool _nonEmpty(Object? v) {
    if (v == null) return false;
    final String s = '$v';
    return s.isNotEmpty && s != 'null';
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
