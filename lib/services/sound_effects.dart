import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'theme_service.dart';

/// The app's short sounds (answer chimes, celebrations, taps), on their own
/// players so they never cut off a word's pronunciation. Follows the
/// sound-effects switch and volume in Settings; failures are logged and
/// ignored.
///
/// Prefer `Feedback.play` (services/feedback.dart), which pairs each sound
/// with its haptic and yak reaction.
class SoundEffects {
  SoundEffects._();

  static final SoundEffects instance = SoundEffects._();

  AudioPlayer? _player;

  /// Taps and selections get their own player so a tap never cuts off the
  /// answer chime still ringing.
  AudioPlayer? _uiPlayer;

  double _volume = 1;

  Future<void> _play(String asset, ThemeService theme) async {
    if (!theme.soundEffectsEnabled) return;
    await playAsset(asset, volume: theme.soundEffectsVolume);
  }

  /// Plays [asset] (relative to `assets/`) at [volume] 0..1. Callers check
  /// the Settings switch; this only plays.
  Future<void> playAsset(
    String asset, {
    required double volume,
    bool ui = false,
  }) async {
    try {
      final player =
          ui
              ? (_uiPlayer ??= AudioPlayer(playerId: 'ui_sfx'))
              : (_player ??= AudioPlayer(playerId: 'game_sfx'));
      await player.stop();
      final v = volume.clamp(0.0, 1.0);
      if (!ui) _volume = v;
      await player.setVolume(v);
      await player.play(AssetSource(asset));
    } catch (e) {
      debugPrint('Sound effect failed: $e');
    }
  }

  /// Turns the ringing answer chime down to [factor] of its volume, so a
  /// word spoken over it stays clear.
  Future<void> duck(double factor) async {
    try {
      await _player?.setVolume((_volume * factor).clamp(0.0, 1.0));
    } catch (_) {}
  }

  Future<void> correct(ThemeService theme) {
    HapticFeedback.lightImpact();
    return _play('audio/correct.mp3', theme);
  }

  Future<void> wrong(ThemeService theme) => _play('audio/incorrect.mp3', theme);
}
