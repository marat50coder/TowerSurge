import 'dart:convert';

import '../berth.dart';
import '../harbor_config.dart';
import 'fabric_store.dart';
import 'tide_agent.dart';

// ============================================================
// RULING CALL — POST the verdict body, cache the answer
// ============================================================
// The backend is the sole authority on the routing decision. On an
// approved reply we cache both the URL AND its expiry so returning
// launches can skip the network hop while the URL is fresh. Any
// failure (HTTP error, timeout, malformed JSON) turns into a
// rejected ruling; the coordinator translates that into a native
// game landing (or an offline landing when the network is down).
// ============================================================

class RulingCall {
  RulingCall(this._store);

  final FabricStore _store;

  Future<Ruling> ask(Map<String, dynamic> body) async {
    final String endpoint = HarborConfig.endpointUrl;
    if (endpoint.isEmpty) {
      return Ruling.rejected('endpoint_missing');
    }

    try {
      final dynamic reply = await tideAgent
          .post(
            Uri.parse(endpoint),
            headers: const <String, String>{
              'Accept': 'application/json',
              'Content-Type': 'application/json',
            },
            body: jsonEncode(body),
          )
          .timeout(Duration(seconds: HarborConfig.rulingTimeoutSeconds));

      if (reply.statusCode != 200) {
        return Ruling.rejected('http_${reply.statusCode}');
      }

      final dynamic decoded = jsonDecode(reply.body);
      if (decoded is! Map) return Ruling.rejected('malformed');
      final Ruling ruling = Ruling.fromJson(
        Map<String, dynamic>.from(decoded),
      );

      if (ruling.hasDestination) {
        await _store.cacheDestination(
            ruling.destination!, ruling.expiresAt);
      }
      return ruling;
    } catch (e) {
      return Ruling.rejected('network:$e');
    }
  }
}
