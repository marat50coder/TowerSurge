// ============================================================
// BERTH — sealed outcome of the boot decision
// ============================================================
// The tide coordinator emits exactly one `Berth`. The pier screen
// destructures via a `switch` and only there decides which route
// to push. This shape (sealed subclasses + exhaustive switch) is
// intentionally different from the enum + if-chain shape shipped by
// sibling apps: the compiled dispatch has a distinct code-gen
// footprint.
// ============================================================

/// Persisted routing memory across launches.
enum RoutingMemory {
  pending,
  harbor,
  homeGame;

  String get wireLabel => switch (this) {
        RoutingMemory.pending => 'pending',
        RoutingMemory.harbor => 'harbor',
        RoutingMemory.homeGame => 'homegame',
      };

  static RoutingMemory parse(String? raw) => switch (raw) {
        'harbor' || 'portal' || 'web' => RoutingMemory.harbor,
        'homegame' || 'native' || 'game' => RoutingMemory.homeGame,
        _ => RoutingMemory.pending,
      };
}

/// Parsed response from the verdict endpoint.
///
/// Wire keys are `{ok, url, expires, message}` — mapped verbatim.
class Ruling {
  const Ruling({
    required this.approved,
    this.destination,
    this.expiresAt,
    this.note,
  });

  factory Ruling.fromJson(Map<String, dynamic> json) {
    final dynamic rawExpiry = json['expires'];
    return Ruling(
      approved: json['ok'] == true,
      destination:
          json['url'] is String ? json['url'] as String : null,
      expiresAt: rawExpiry is num
          ? rawExpiry.toInt()
          : int.tryParse(rawExpiry?.toString() ?? ''),
      note: json['message']?.toString(),
    );
  }

  factory Ruling.rejected(String note) =>
      Ruling(approved: false, note: note);

  final bool approved;
  final String? destination;
  final int? expiresAt;
  final String? note;

  bool get hasDestination =>
      approved && destination != null && destination!.isNotEmpty;
}

sealed class Berth {
  const Berth();
}

/// Send the user to the native game (white part).
final class HomeGameBerth extends Berth {
  const HomeGameBerth();
}

/// Show the WebView portal at [url].
final class HarborBerth extends Berth {
  const HarborBerth(this.url, {this.pushOrigin = false});

  final String url;

  /// True only when the destination came from a cold-boot push tap,
  /// so the pier animation can skip a portion of its warm-up delay.
  final bool pushOrigin;
}

/// Show the offline stage. Retry rebuilds the pier from scratch.
final class AdriftBerth extends Berth {
  const AdriftBerth({required this.returnsToGame});

  final bool returnsToGame;
}
