import 'dart:async';
import 'dart:io';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:webview_flutter_android/webview_flutter_android.dart';

import '../../core/palette.dart';
import '../harbor_config.dart';
import '../wire/chime_channel.dart';
import '../wire/fabric_store.dart';
import '../wire/fingerprint_tag.dart';
import '../wire/link_pulse.dart';
import '../wire/page_enhancers.dart';
import 'adrift_stage.dart';

// ============================================================
// HARBOR STAGE — the WebView shell (gray content)
// ============================================================
// Renders the verdict destination with:
//   • forged UA identical to the HTTP client's
//   • both orientations + immersive system UI
//   • external-scheme handoff (tel: / mailto: / intent://)
//   • redirect-loop recovery on -1007 / -9 (bounded)
//   • connectivity-drop guard (debounced)
//   • warm push URL delivery via `ChimeChannel.onIncomingUrl`
//   • native file chooser over MethodChannel (no file_picker dep)
//   • JS enhancer stack via `PageEnhancers.installAll`
//
// There is NO client-side classification of the partner site (no
// deposit / cashier / register regex). Any funnel needs live on
// the server; the client stays a dumb shell.
// ============================================================

class HarborStage extends StatefulWidget {
  const HarborStage({
    super.key,
    required this.url,
    required this.store,
    required this.chime,
  });

  final String url;
  final FabricStore store;
  final ChimeChannel chime;

  @override
  State<HarborStage> createState() => _HarborStageState();
}

class _HarborStageState extends State<HarborStage>
    with WidgetsBindingObserver {
  late final WebViewController _web;
  bool _busy = true;
  bool _offlinePushed = false;
  String? _lastMainFrame;
  int _retryCount = 0;
  Timer? _dropDebounce;
  StreamSubscription<List<ConnectivityResult>>? _connSub;

  /// Native file chooser bridge — Kotlin-side handler lives in
  /// `MainActivity.kt`. Keep the string in sync there.
  static const MethodChannel _pickerChannel =
      MethodChannel('surgefort/harbor/pickfile');

  final LinkPulse _pulse = LinkPulse();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    SystemChrome.setPreferredOrientations(const <DeviceOrientation>[
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    _enterImmersive();
    _wireController();

    widget.chime.onIncomingUrl = (String url) {
      if (mounted) _web.loadRequest(Uri.parse(url));
    };

    // Debounce connectivity drops — a VPN reconnect or a brief cell
    // switch spits out a burst of `none` events that must not flip
    // us to the offline stage.
    _connSub = _pulse.updates.listen((List<ConnectivityResult> r) {
      final bool allNone = r.isNotEmpty &&
          r.every((ConnectivityResult e) => e == ConnectivityResult.none);
      if (!allNone) {
        _dropDebounce?.cancel();
        return;
      }
      _dropDebounce?.cancel();
      _dropDebounce = Timer(
        Duration(milliseconds: HarborConfig.dropDebounceMs),
        _pushOffline,
      );
    });
  }

  void _enterImmersive() {
    SystemChrome.setEnabledSystemUIMode(
      SystemUiMode.manual,
      overlays: const <SystemUiOverlay>[SystemUiOverlay.bottom],
    );
    SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
      systemNavigationBarColor: Colors.transparent,
      systemNavigationBarDividerColor: Colors.transparent,
      systemNavigationBarIconBrightness: Brightness.light,
      systemNavigationBarContrastEnforced: false,
    ));
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _enterImmersive();
  }

  void _wireController() {
    _web = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setUserAgent(FingerprintTag.userAgent)
      ..setBackgroundColor(Colors.black)
      ..enableZoom(false)
      ..setNavigationDelegate(NavigationDelegate(
        onPageStarted: (_) {
          if (mounted) setState(() => _busy = true);
        },
        onPageFinished: (_) {
          if (mounted) setState(() => _busy = false);
          _retryCount = 0;
          PageEnhancers.installAll(_web);
        },
        onWebResourceError: _handleError,
        onNavigationRequest: _handleNavigation,
      ));

    _configureAndroid();
    _web.loadRequest(Uri.parse(widget.url));
  }

  void _handleError(WebResourceError err) {
    if (err.isForMainFrame != true) return;

    final String desc = err.description.toLowerCase();
    final bool loop = desc.contains('too_many_redirects') ||
        desc.contains('too many redirects') ||
        err.errorCode == -1007 ||
        err.errorCode == -9;

    if (loop &&
        _lastMainFrame != null &&
        _retryCount < HarborConfig.redirectLoopRetries) {
      _retryCount++;
      _web.loadRequest(Uri.parse(_lastMainFrame!));
      return;
    }

    // Cover the WebView's own error page with our spinner
    // immediately so the Android chrome robot never leaks.
    if (mounted) setState(() => _busy = true);

    final bool disconnected = desc.contains('name_not_resolved') ||
        desc.contains('address_unreachable') ||
        desc.contains('internet_disconnected') ||
        desc.contains('network_changed') ||
        err.errorCode == -105 ||
        err.errorCode == -106 ||
        err.errorCode == -21 ||
        err.errorCode == -2 ||
        err.errorCode == -6;

    if (disconnected) {
      _pushOffline();
    } else {
      _guardOffline();
    }
  }

  NavigationDecision _handleNavigation(NavigationRequest req) {
    final Uri? uri = Uri.tryParse(req.url);
    if (uri == null) return NavigationDecision.prevent;
    const Set<String> inline = <String>{
      'http',
      'https',
      'about',
      'data',
      'blob',
    };
    if (inline.contains(uri.scheme)) {
      if (req.isMainFrame) _lastMainFrame = req.url;
      return NavigationDecision.navigate;
    }
    _handOff(uri);
    return NavigationDecision.prevent;
  }

  void _configureAndroid() {
    if (!Platform.isAndroid) return;
    if (_web.platform is! AndroidWebViewController) return;
    final AndroidWebViewController controller =
        _web.platform as AndroidWebViewController;

    controller.setMediaPlaybackRequiresUserGesture(false);
    controller.setOnPlatformPermissionRequest(
      (PlatformWebViewPermissionRequest r) => r.grant(),
    );
    controller.setOnShowFileSelector(_pickFiles);

    final AndroidWebViewCookieManager cookies =
        AndroidWebViewCookieManager(
      AndroidWebViewCookieManagerCreationParams
          .fromPlatformWebViewCookieManagerCreationParams(
        const PlatformWebViewCookieManagerCreationParams(),
      ),
    );
    cookies.setAcceptThirdPartyCookies(controller, true);
  }

  Future<List<String>> _pickFiles(FileSelectorParams params) async {
    try {
      final List<Object?>? picked = await _pickerChannel
          .invokeMethod<List<Object?>>('pick', <String, Object>{
        'multiple': params.mode == FileSelectorMode.openMultiple,
        'mimeTypes': params.acceptTypes
            .where((String t) => t.trim().isNotEmpty)
            .toList(),
      });
      if (picked == null) return const <String>[];
      return picked.whereType<String>().toList();
    } catch (_) {
      return const <String>[];
    }
  }

  Future<void> _handOff(Uri uri) async {
    try {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {}
  }

  Future<void> _guardOffline() async {
    if (_offlinePushed) return;
    final bool alive = await _pulse.canReach();
    if (alive) return;
    _pushOffline();
  }

  void _pushOffline() {
    if (_offlinePushed || !mounted) return;
    _offlinePushed = true;
    final String snapshot = _lastMainFrame ?? widget.url;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute<void>(
        builder: (_) => AdriftStage(
          onRebuild: (_) => HarborStage(
            url: snapshot,
            store: widget.store,
            chime: widget.chime,
          ),
        ),
      ),
    );
  }

  Future<void> _stepBack() async {
    if (await _web.canGoBack()) await _web.goBack();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _dropDebounce?.cancel();
    _connSub?.cancel();
    widget.chime.onIncomingUrl = null;
    SystemChrome.setEnabledSystemUIMode(
      SystemUiMode.manual,
      overlays: SystemUiOverlay.values,
    );
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final MediaQueryData mq = MediaQuery.of(context);
    final bool landscape = mq.orientation == Orientation.landscape;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (bool didPop, _) async {
        if (!didPop) await _stepBack();
      },
      child: Scaffold(
        backgroundColor: Colors.black,
        resizeToAvoidBottomInset: false,
        body: Stack(
          fit: StackFit.expand,
          children: <Widget>[
            Padding(
              padding: mq.viewPadding,
              child: WebViewWidget(controller: _web),
            ),
            if (_busy && !landscape)
              const ColoredBox(
                color: Color(0x88000000),
                child: Center(
                  child: CircularProgressIndicator(
                    valueColor:
                        AlwaysStoppedAnimation<Color>(P.gold),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
