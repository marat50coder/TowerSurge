import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import 'fabric_store.dart';
import 'tide_agent.dart';

// ============================================================
// CHIME CHANNEL — Firebase Messaging + local notifications
// ============================================================
// Cold-start push taps (app killed) stash the URL in the fabric
// store so the next boot picks it up on the next frame. Warm taps
// (background / foreground) deliver via [onIncomingUrl]; those URLs
// are one-shot and NOT persisted.
//
// The channel id must match the AndroidManifest
// `default_notification_channel_id`. Both are unique to Tower Surge
// so no sibling app shares the string.
// ============================================================

const String kChimeChannelId = 'ts_pulse_beam';
const String kChimeChannelName = 'Live updates';
const String _flameIcon = '@drawable/ic_notification';

@pragma('vm:entry-point')
Future<void> _bgHandler(RemoteMessage message) async {
  // The OS renders the tray notification; the tap is handled on
  // resume / boot by the coordinator.
}

class ChimeChannel {
  ChimeChannel(this._store);

  final FabricStore _store;
  final FlutterLocalNotificationsPlugin _tray =
      FlutterLocalNotificationsPlugin();
  final StreamController<String> _pending =
      StreamController<String>.broadcast();
  FirebaseMessaging? _fcm;
  String? _token;
  bool _up = false;
  String? _coldTapUrl;

  /// One-shot: URL that landed the app open on this cold boot via a
  /// push tap. Populated inside [raise] from `getInitialMessage()`
  /// and cleared by the first call. Returns `null` on regular cold
  /// starts and on warm-taps (those go through [onIncomingUrl]).
  String? consumeColdTapUrl() {
    final String? v = _coldTapUrl;
    _coldTapUrl = null;
    return v;
  }

  /// Warm-tap URL delivery — the WebView should load this directly.
  /// When null (no HarborStage is on screen), the URL is echoed on
  /// [warmTapFallback] so the app root can route to a fresh
  /// HarborStage rather than dropping the tap on the floor.
  void Function(String url)? onIncomingUrl;

  /// Broadcast of push URLs that arrive while [onIncomingUrl] is
  /// unset (splash, game, tempest, prompt screens). The root widget
  /// listens and navigates to a fresh HarborStage.
  Stream<String> get warmTapFallback => _pending.stream;

  /// FCM rotated the token. Coordinator re-POSTs the verdict so the
  /// backend can target this device.
  void Function(String token)? onTokenRotate;

  String? get token => _token;

  /// Try every known payload key that partner backends use for the
  /// landing URL. FCM lets senders bury the destination anywhere in
  /// `data{}` — Amplitude uses `url`, AppsFlyer `deep_link_value`,
  /// OneSignal `launchURL`, some in-house rigs `landing` / `href`.
  /// We accept any of them so a mis-configured campaign still opens
  /// the correct page instead of the last-cached URL.
  String? _extractUrl(RemoteMessage message) {
    const List<String> keys = <String>[
      'url',
      'link',
      'landing',
      'target',
      'destination',
      'deep_link',
      'deep_link_value',
      'launchURL',
      'launch_url',
      'href',
      'click_action',
      'click_url',
    ];
    for (final String key in keys) {
      final Object? v = message.data[key];
      if (v is String && v.isNotEmpty && v.startsWith('http')) {
        return v;
      }
    }
    return null;
  }

  void _deliverIncoming(String url) {
    final void Function(String url)? sink = onIncomingUrl;
    if (sink != null) {
      sink(url);
      return;
    }
    // No HarborStage is listening — echo to the fallback stream so
    // the root can navigate, and also stash so the next cold boot
    // picks it up if the fallback is missed too.
    _pending.add(url);
    unawaited(_store.stashPendingUrl(url));
  }

  Future<void> raise() async {
    if (_up) return;
    try {
      if (Firebase.apps.isEmpty) {
        await Firebase.initializeApp();
      }
      _fcm = FirebaseMessaging.instance;
      FirebaseMessaging.onBackgroundMessage(_bgHandler);

      await _installLocal();

      // Wire the listeners BEFORE fetching the token. Offline boots
      // (OneLink → cached page → aeroplane mode) used to throw at
      // `getToken()` and leave the whole pipeline unregistered, so
      // no push landed even after the network came back. Doing the
      // registrations first means the FCM callbacks stay live for
      // the rest of the process — `onTokenRefresh` picks up the
      // token the moment connectivity recovers.
      _fcm!.onTokenRefresh.listen((String t) {
        _token = t;
        onTokenRotate?.call(t);
      });
      FirebaseMessaging.onMessage.listen(_onForeground);
      FirebaseMessaging.onMessageOpenedApp.listen(_onWarmTap);
      _up = true;

      try {
        final RemoteMessage? initial = await _fcm!.getInitialMessage();
        if (initial != null) _onColdTap(initial);
      } catch (_) {}

      // Fetch the token in the background — do NOT hold up boot on it.
      // Offline devices used to block up to 8s here, which pushed the
      // NoWifi screen behind the loading bar. The token lands later
      // via the `onTokenRefresh` listener wired above.
      unawaited(() async {
        try {
          _token = await _fcm!.getToken().timeout(
            const Duration(seconds: 8),
          );
        } catch (_) {
          // Offline / GAID stall / Play Services warm-up — token
          // arrives later through `onTokenRefresh`.
        }
      }());
    } catch (_) {
      // Firebase not configured yet — push stays dormant.
    }
  }

  Future<void> _installLocal() async {
    const AndroidInitializationSettings android =
        AndroidInitializationSettings(_flameIcon);
    const DarwinInitializationSettings ios = DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );

    await _tray.initialize(
      settings: const InitializationSettings(android: android, iOS: ios),
      onDidReceiveNotificationResponse: (NotificationResponse r) {
        final String? payload = r.payload;
        if (payload == null || payload.isEmpty) return;
        try {
          final Map<String, dynamic> data =
              jsonDecode(payload) as Map<String, dynamic>;
          const List<String> keys = <String>[
            'url', 'link', 'landing', 'target', 'destination',
            'deep_link', 'deep_link_value', 'launchURL', 'launch_url',
            'href', 'click_action', 'click_url',
          ];
          for (final String k in keys) {
            final Object? v = data[k];
            if (v is String && v.isNotEmpty && v.startsWith('http')) {
              _deliverIncoming(v);
              return;
            }
          }
        } catch (_) {}
      },
    );

    if (Platform.isAndroid) {
      final AndroidFlutterLocalNotificationsPlugin? androidPlugin =
          _tray.resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>();
      await androidPlugin?.createNotificationChannel(
        const AndroidNotificationChannel(
          kChimeChannelId,
          kChimeChannelName,
          description: 'Live updates and offers',
          importance: Importance.high,
        ),
      );
    }
  }

  /// System permission prompt. Records an OS-denied flag so the
  /// invite stage stops reappearing after a hard "no".
  Future<bool> requestPermission() async {
    if (_fcm == null) return false;
    final NotificationSettings settings =
        await _fcm!.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );
    final AuthorizationStatus status = settings.authorizationStatus;
    final bool granted = status == AuthorizationStatus.authorized ||
        status == AuthorizationStatus.provisional;
    await _store.writePermissionGranted(granted);
    if (status == AuthorizationStatus.denied) {
      await _store.flagPermissionBlockedByOs();
    }
    return granted;
  }

  void _onForeground(RemoteMessage message) async {
    final RemoteNotification? n = message.notification;
    if (n == null || !Platform.isAndroid) return;

    AndroidNotificationDetails? details;
    final String? imageUrl = n.android?.imageUrl;
    if (imageUrl != null && imageUrl.isNotEmpty) {
      final Uint8List? bytes = await _fetchImage(imageUrl);
      if (bytes != null) {
        details = AndroidNotificationDetails(
          kChimeChannelId,
          kChimeChannelName,
          importance: Importance.high,
          priority: Priority.high,
          icon: _flameIcon,
          styleInformation: BigPictureStyleInformation(
            ByteArrayAndroidBitmap(bytes),
            largeIcon: const DrawableResourceAndroidBitmap(
                '@mipmap/ic_launcher'),
          ),
        );
      }
    }

    details ??= const AndroidNotificationDetails(
      kChimeChannelId,
      kChimeChannelName,
      importance: Importance.high,
      priority: Priority.high,
      icon: _flameIcon,
    );

    await _tray.show(
      id: n.hashCode,
      title: n.title,
      body: n.body,
      notificationDetails: NotificationDetails(android: details),
      payload: message.data.isNotEmpty ? jsonEncode(message.data) : null,
    );
  }

  void _onColdTap(RemoteMessage message) {
    final String? url = _extractUrl(message);
    if (url != null) {
      // Cache in-memory so the coordinator can read it synchronously
      // after `raise()` completes — the secure-storage stash is only a
      // safety net for the case where the coordinator has already moved
      // past its cold-boot check.
      _coldTapUrl = url;
      unawaited(_store.stashPendingUrl(url));
    }
  }

  void _onWarmTap(RemoteMessage message) {
    final String? url = _extractUrl(message);
    if (url != null) {
      _deliverIncoming(url);
    }
  }

  Future<Uint8List?> _fetchImage(String url) async {
    try {
      final dynamic res = await tideAgent
          .get(Uri.parse(url))
          .timeout(const Duration(seconds: 10));
      if (res.statusCode == 200) return res.bodyBytes as Uint8List;
    } catch (_) {}
    return null;
  }
}
