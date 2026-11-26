/// A learner's picture: a drawn figure (a yak face or a Tibetan symbol) on a
/// coloured disc. Learners pick one instead of uploading a photo, so the
/// public leaderboard never shows photos of people.
library;

import 'package:flutter/material.dart';

import '../theme/app_tokens.dart';
import 'game_icons.dart';
import 'yak_mascot.dart';

enum AvatarFigure {
  yakHappy('yak_happy', 'Happy yak'),
  yakProud('yak_proud', 'Proud yak'),
  yakLove('yak_love', 'Loving yak'),
  yakSurprised('yak_surprised', 'Surprised yak'),
  conch('conch', 'Conch'),
  prayerWheel('prayer_wheel', 'Prayer wheel'),
  letter('letter', 'Tibetan letter');

  const AvatarFigure(this.key, this.label);
  final String key;
  final String label;
}

enum AvatarColour {
  blue('blue', AppColors.primary),
  green('green', AppColors.green),
  orange('orange', AppColors.orange),
  purple('purple', AppColors.purple),
  red('red', AppColors.red),
  gold('gold', AppColors.goldLip);

  const AvatarColour(this.key, this.color);
  final String key;
  final Color color;
}

/// Parsed avatar key ("yak_love:red"); the server accepts the same set.
class AvatarChoice {
  const AvatarChoice(this.figure, this.colour);

  final AvatarFigure figure;
  final AvatarColour colour;

  static const AvatarChoice fallback = AvatarChoice(
    AvatarFigure.yakHappy,
    AvatarColour.blue,
  );

  String get key => '${figure.key}:${colour.key}';

  static AvatarChoice? parse(String? key) {
    if (key == null || key.isEmpty) return null;
    final parts = key.split(':');
    AvatarFigure? figure;
    for (final f in AvatarFigure.values) {
      if (f.key == parts.first) figure = f;
    }
    if (figure == null) return null;
    var colour = AvatarColour.blue;
    if (parts.length > 1) {
      for (final c in AvatarColour.values) {
        if (c.key == parts[1]) colour = c;
      }
    }
    return AvatarChoice(figure, colour);
  }

  @override
  bool operator ==(Object other) =>
      other is AvatarChoice && other.figure == figure && other.colour == colour;

  @override
  int get hashCode => Object.hash(figure, colour);
}

class LearnerAvatar extends StatelessWidget {
  const LearnerAvatar({
    super.key,
    required this.avatar,
    this.size = 40,
    this.border = false,
  });

  /// The key from the server, or null for the default (a yak on blue).
  final String? avatar;
  final double size;
  final bool border;

  @override
  Widget build(BuildContext context) {
    final choice = AvatarChoice.parse(avatar) ?? AvatarChoice.fallback;
    return LearnerAvatarFace(choice: choice, size: size, border: border);
  }
}

class LearnerAvatarFace extends StatelessWidget {
  const LearnerAvatarFace({
    super.key,
    required this.choice,
    this.size = 40,
    this.border = false,
  });

  final AvatarChoice choice;
  final double size;
  final bool border;

  @override
  Widget build(BuildContext context) {
    final figure = choice.figure;
    final Widget art = switch (figure) {
      AvatarFigure.yakHappy => _yak(YakMood.happy),
      AvatarFigure.yakProud => _yak(YakMood.proud),
      AvatarFigure.yakLove => _yak(YakMood.love),
      AvatarFigure.yakSurprised => _yak(YakMood.surprised),
      AvatarFigure.conch => _glyph(GameGlyph.conch),
      AvatarFigure.prayerWheel => _glyph(GameGlyph.prayerWheel),
      AvatarFigure.letter => _glyph(GameGlyph.flashcard),
    };
    return Semantics(
      label: '${figure.label} picture',
      excludeSemantics: true,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: choice.colour.color,
          border:
              border
                  ? Border.all(color: Colors.white, width: size * 0.04)
                  : null,
        ),
        clipBehavior: Clip.antiAlias,
        alignment: Alignment.center,
        child: art,
      ),
    );
  }

  Widget _yak(YakMood mood) => Padding(
    padding: EdgeInsets.only(top: size * 0.08),
    child: YakMascot(
      mood: mood,
      size: size * 0.86,
      showBody: false,
      animate: false,
    ),
  );

  Widget _glyph(GameGlyph glyph) =>
      GameIcon(glyph, color: Colors.white, size: size * 0.56);
}
