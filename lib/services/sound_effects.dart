import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'theme_service.dart';

/// The right/wrong chimes for the games, on their own player so they never
/// cut off a word's pronunciation. Follows the sound-effects switch and
/// volume in Settings; failures are logged and ignored.
class SoundEffects {
  SoundEffects._();

  static final SoundEffects instance = SoundEffects._();

  AudioPlayer? _player;

  Future<void> _play(String asset, ThemeService theme) async {
    if (!theme.soundEffectsEnabled) return;
    try {
      final player = _player ??= AudioPlayer(playerId: 'game_sfx');
      await player.stop();
      await player.setVolume(theme.soundEffectsVolume.clamp(0.0, 1.0));
      await player.play(AssetSource(asset));
    } catch (e) {
      debugPrint('Sound effect failed: $e');
    }
  }

  Future<void> correct(ThemeService theme) {
    HapticFeedback.lightImpact();
    return _play('audio/correct.mp3', theme);
  }

  Future<void> wrong(ThemeService theme) => _play('audio/incorrect.mp3', theme);
}
