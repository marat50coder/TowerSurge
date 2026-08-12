import 'dart:convert';
import 'dart:typed_data';

// ============================================================
// DRIFT CODEC — chained rotate/XOR/prime-multiply byte hider
// ============================================================
// Every masked byte array in `masked_ledger.dart` is turned back
// into a UTF-8 string by [unmask]. The bytes at rest in the compiled
// AAB are NEVER the plaintext; they are only meaningful after this
// state machine finishes.
//
// The loop shape is deliberately dissimilar from the shapes used in
// sibling apps (no long precomputed keystream, no RC4-style KSA/PRGA
// permutation, no Weyl-additive position mask). Each byte re-derives
// its mask from the previous state via a rotate-left-5, salt XOR,
// and an FNV-prime multiply — a signature no shipped sibling shares.
//
// Contract:
//   • [unmask] is the ONLY decoder — callers must never touch the
//     byte arrays directly.
//   • Empty input returns "" so `credentialsReady` gates can key on
//     `.isEmpty` when the operator has not yet supplied a value.
// ============================================================

const List<int> _tideSalt = <int>[
  0xA4, 0x37, 0xF2, 0x8B, 0x51, 0x0C, 0xEE, 0x69,
  0x1D, 0xB5, 0x48, 0xC7, 0x92, 0x3A, 0xDD, 0x66,
];

const int _fnvOffset = 0x811C9DC5;
const int _fnvPrime = 0x01000193;
const int _mask32 = 0xFFFFFFFF;

int _seedFromSalt() {
  int h = _fnvOffset;
  for (int i = 0; i < _tideSalt.length; i++) {
    h ^= _tideSalt[i];
    h = (h * _fnvPrime) & _mask32;
  }
  return h;
}

int _rotl5(int x) {
  x &= _mask32;
  return ((x << 5) | (x >> 27)) & _mask32;
}

/// Reveals the plaintext hidden behind an encoded byte array.
String unmask(List<int> hidden) {
  if (hidden.isEmpty) return '';
  final Uint8List raw = Uint8List(hidden.length);
  int state = _seedFromSalt();
  for (int i = 0; i < hidden.length; i++) {
    state = _rotl5(state);
    state ^= _tideSalt[i % _tideSalt.length];
    state = (state * _fnvPrime) & _mask32;
    raw[i] = (hidden[i] ^ (state & 0xFF)) & 0xFF;
  }
  return utf8.decode(raw);
}
