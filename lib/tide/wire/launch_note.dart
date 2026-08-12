import 'fabric_store.dart';

// ============================================================
// LAUNCH NOTE — cold-boot deep-link consumption
// ============================================================
// A cold-boot push tap on Android delivers the URL through the
// launch intent, which Firebase Messaging surfaces via
// `getInitialMessage()`. `ChimeChannel` writes it into the fabric
// store's pending slot. This helper is a thin one-shot reader so
// the coordinator has one entry point for cold-launch URLs,
// symmetric with the returning-launch code path.
// ============================================================

class LaunchNote {
  LaunchNote._();

  static Future<String?> consume(FabricStore store) =>
      store.consumePendingUrl();
}
