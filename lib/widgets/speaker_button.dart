import 'package:flutter/material.dart';

import '../services/pronunciation_player.dart';
import '../theme/app_tokens.dart';

/// Tap-to-hear button for a word's pronunciation recording. Shows a filled
/// icon while its own recording is playing.
class SpeakerButton extends StatelessWidget {
  final String url;
  final double size;

  const SpeakerButton({super.key, required this.url, this.size = 28});

  @override
  Widget build(BuildContext context) {
    final player = PronunciationPlayer.instance;
    return ValueListenableBuilder<String?>(
      valueListenable: player.playingUrl,
      builder: (context, playing, _) {
        final isPlaying = playing == url;
        final color = AppColors.primary;
        return Semantics(
          button: true,
          label: 'Play pronunciation',
          child: Material(
            color: color.withValues(alpha: isPlaying ? 0.22 : 0.10),
            shape: const CircleBorder(),
            child: InkWell(
              customBorder: const CircleBorder(),
              onTap: () => player.play(url),
              child: Padding(
                padding: const EdgeInsets.all(10),
                child: Icon(
                  isPlaying
                      ? Icons.volume_up_rounded
                      : Icons.volume_up_outlined,
                  size: size,
                  color: color,
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
