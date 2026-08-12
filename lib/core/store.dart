import 'package:shared_preferences/shared_preferences.dart';

/// Persisted player state and preferences.
class Store {
  Store._(this._prefs);

  static const _kBalance = 'balance';
  static const _kBet = 'bet';
  static const _kSound = 'sound';
  static const _kMusic = 'music';

  static const double startingBalance = 100000;

  final SharedPreferences _prefs;
  static Store? _instance;

  static Store get i => _instance!;

  static Future<Store> init() async {
    _instance ??= Store._(await SharedPreferences.getInstance());
    return _instance!;
  }

  double get balance => _prefs.getDouble(_kBalance) ?? startingBalance;
  set balance(double v) => _prefs.setDouble(_kBalance, v);

  double get bet => _prefs.getDouble(_kBet) ?? 100;
  set bet(double v) => _prefs.setDouble(_kBet, v);

  bool get sound => _prefs.getBool(_kSound) ?? true;
  set sound(bool v) => _prefs.setBool(_kSound, v);

  bool get music => _prefs.getBool(_kMusic) ?? true;
  set music(bool v) => _prefs.setBool(_kMusic, v);

  void resetBalance() => balance = startingBalance;
}
