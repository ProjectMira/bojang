import 'package:flutter/material.dart';
import '../theme/app_tokens.dart';
import 'app_text_style.dart';

/// Colorful flat shortcut tile used in the home page's 2x2 grid (top
/// topics + Memory game).
class ShortcutCard extends StatefulWidget {
  final String emoji;
  final String title;
  final String subtitle;
  final Color color;
  final VoidCallback onTap;

  /// Overrides the default emoji squircle with a custom leading visual
  /// (e.g. the fanned-card treatment used for the Memory Match tile).
  final Widget? leading;

  const ShortcutCard({
    super.key,
    required this.emoji,
    required this.title,
    required this.subtitle,
    required this.color,
    required this.onTap,
    this.leading,
  });

  @override
  State<ShortcutCard> createState() => _ShortcutCardState();
}

class _ShortcutCardState extends State<ShortcutCard> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppTokens.tint(widget.color, context),
      borderRadius: BorderRadius.circular(AppRadius.card),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadius.card),
        splashColor: widget.color.withOpacity(0.12),
        highlightColor: widget.color.withOpacity(0.08),
        onTap: widget.onTap,
        onHighlightChanged: (value) => setState(() => _pressed = value),
        child: AnimatedScale(
          scale: _pressed ? 0.97 : 1.0,
          duration: const Duration(milliseconds: 150),
          curve: Curves.easeOut,
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                widget.leading ??
                    Container(
                      width: 40,
                      height: 40,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: AppTokens.surface(context),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        widget.emoji,
                        style: const TextStyle(fontSize: 22),
                      ),
                    ),
                const SizedBox(height: 10),
                Text(
                  widget.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: AppTextStyles.poppins(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: AppTokens.ink(context),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  widget.subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: AppTextStyles.caption(context),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
