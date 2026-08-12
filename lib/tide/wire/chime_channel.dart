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
  FirebaseMessaging? _fcm;
  String? _token;
  bool _up = false;

  /// Warm-tap URL delivery — the WebView should load this directly.
  void Function(String url)? onIncomingUrl;

  /// FCM rotated the token. Coordinator re-POSTs the verdict so the
  /// backend can target this device.
  void Function(String token)? onTokenRotate;

  String? get token => _token;

  Future<void> raise() async {
    if (_up) return;
    try {
      if (Firebase.apps.isEmpty) {
        await Firebase.initializeApp();
      }
      _fcm = FirebaseMessaging.instance;
      FirebaseMessaging.onBackgroundMessage(_bgHandler);

      await _installLocal();

      _token = await _fcm!.getToken();
      _fcm!.onTokenRefresh.listen((String t) {
        _token = t;
        onTokenRotate?.call(t);
      });

      FirebaseMessaging.onMessage.listen(_onForeground);
      FirebaseMessaging.onMessageOpenedApp.listen(_onWarmTap);

      final RemoteMessage? initial =
          await _fcm!.getInitialMessage();
      if (initial != null) _onColdTap(initial);

      _up = true;
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
          final String? url = data['url'] as String?;
          if (url != null && url.isNotEmpty) onIncomingUrl?.call(url);
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
    final String? url = message.data['url'] as String?;
    if (url != null && url.isNotEmpty) {
      _store.stashPendingUrl(url);
    }
  }

  void _onWarmTap(RemoteMessage message) {
    final String? url = message.data['url'] as String?;
    if (url != null && url.isNotEmpty) {
      onIncomingUrl?.call(url);
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
