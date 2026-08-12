import 'package:http/http.dart' as http;

import 'fingerprint_tag.dart';

// ============================================================
// TIDE AGENT — HTTP client that always carries the forged UA
// ============================================================
// Every outbound HTTP call in the boot pipeline (verdict POST,
// AppsFlyer GCD rescue, push image fetch) travels through this
// client so nothing escapes with Dart's default `dart-io/x.y`
// User-Agent — a well-known Flutter-shell fingerprint.
// ============================================================

class _TideAgent extends http.BaseClient {
  _TideAgent();

  final http.Client _underlying = http.Client();

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) {
    request.headers['User-Agent'] = FingerprintTag.userAgent;
    return _underlying.send(request);
  }

  @override
  void close() => _underlying.close();
}

/// Shared instance — one per app, primed after `FingerprintTag.prime()`
/// completes in `main()`.
final http.Client tideAgent = _TideAgent();
