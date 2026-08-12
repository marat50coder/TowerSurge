import 'package:webview_flutter/webview_flutter.dart';

import '../mask/masked_ledger.dart';

// ============================================================
// PAGE ENHANCERS — assembled JavaScript payloads
// ============================================================
// Each enhancer body lives as an encoded byte array in
// `masked_ledger.dart`; nothing greppable ships in the compiled
// binary. The forge regenerates every body per project with a
// different sentinel window flag and different control flow so no
// two apps share a body hash.
//
// On `onPageFinished` the WebView receives the ordered sequence.
// Each enhancer is idempotent via its own sentinel window flag so
// running the whole stack on every page load is safe.
// ============================================================

class PageEnhancers {
  PageEnhancers._();

  /// Install the enhancer stack on the given controller.
  static Future<void> installAll(WebViewController controller) async {
    for (final String body in _bodies) {
      if (body.isEmpty) continue;
      try {
        await controller.runJavaScript(body);
      } catch (_) {
        // A partner site with a strict CSP may refuse — the enhancers
        // are cosmetic, so a rejection must never abort the boot.
      }
    }
  }

  static List<String> get _bodies => <String>[
        unwrapSafeAreaScript(),
        unwrapKeyboardScript(),
        unwrapAutoplayScript(),
      ];
}
