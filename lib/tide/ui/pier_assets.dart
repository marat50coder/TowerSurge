// ============================================================
// PIER ASSETS — canonical paths for the tide surfaces
// ============================================================
// Every widget in the tide flow pulls its background path through
// this class — no widget ever hardcodes an `assets/...` literal.
// The addon folder segment `ts_pier_pack` is unique to Tower Surge;
// the loading / notifications / no-wifi backgrounds live under it,
// while the game's own art stays under its original folder.
// ============================================================

class PierAssets {
  PierAssets._();

  static const String _pack = 'assets/ts_pier_pack';

  static const String verticalLoading = '$_pack/Vertical_Loading_Screen.webp';
  static const String horizontalLoading =
      '$_pack/Horizontal_Loading_Screen.webp';

  static const String verticalNotifications =
      '$_pack/Vertical_Notifications_Screen.webp';
  static const String horizontalNotifications =
      '$_pack/Horizontal_Notifications_Screen.webp';

  static const String verticalOffline = '$_pack/Vertical_Nowifi_Screen.webp';
  static const String horizontalOffline =
      '$_pack/Horizontal_Nowifi_Screen.webp';
}
