import 'dart:io';

import 'package:audioplayers/audioplayers.dart';

import 'store.dart';

/// Small wrapper around audioplayers: one reusable player per effect plus a
/// dedicated looping player for background music.
class Sfx {
  Sfx._();

  static final Sfx i = Sfx._();

  static const _dir = 'Tower_Surge_sounds_assets';

  static const drop = '$_dir/drop.wav';
  static const place = '$_dir/block_place.wav';
  static const click = '$_dir/button_click.wav';
  static const cashout = '$_dir/cashout.wav';
  static const coin = '$_dir/coin.wav';
  static const fail = '$_dir/fail.wav';
  static const levelUp = '$_dir/level_up.wav';
  static const success = '$_dir/success.wav';
  static const win = '$_dir/win.wav';
  static const bgmMenu = '$_dir/bgm_menu.wav';
  static const bgmGame = '$_dir/bgm_game.wav';

  final Map<String, AudioPlayer> _players = {};
  late final AudioPlayer _music = AudioPlayer(playerId: 'bgm');
  String? _currentMusic;

  static final bool _headless = Platform.environment.containsKey(
    'FLUTTER_TEST',
  );

  bool get soundOn => Store.i.sound && !_headless;
  bool get musicOn => Store.i.music && !_headless;

  Future<void> play(String asset, {double volume = 1}) async {
    if (!soundOn) return;
    try {
      final player = _players.putIfAbsent(
        asset,
        () => AudioPlayer(playerId: asset),
      );
      await player.setReleaseMode(ReleaseMode.stop);
      await player.stop();
      await player.setVolume(volume);
      await player.play(AssetSource(asset), volume: volume);
    } catch (_) {
      // Audio must never break gameplay.
    }
  }

  Future<void> music(String asset, {double volume = 0.35}) async {
    _currentMusic = asset;
    if (!musicOn) return;
    try {
      await _music.setReleaseMode(ReleaseMode.loop);
      await _music.stop();
      await _music.play(AssetSource(asset), volume: volume);
    } catch (_) {}
  }

  Future<void> stopMusic() async {
    try {
      await _music.stop();
    } catch (_) {}
  }

  Future<void> applyMusicSetting() async {
    if (musicOn) {
      if (_currentMusic != null) await music(_currentMusic!);
    } else {
      await stopMusic();
    }
  }
}
