import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../services/analytics.dart';
import '../services/theme_service.dart';
import '../theme/app_tokens.dart';
import '../theme/motion.dart';
import 'app_text_style.dart';
import 'content_width.dart';

/// Subtitle for the Settings > Animations row.
String animationsSubtitle(BuildContext context, ThemeService theme) {
  final pref = theme.animationPreference;
  if (MediaQuery.maybeDisableAnimationsOf(context) ?? false) {
    return 'Off · your device has Reduce Motion on';
  }
  if (pref == AnimationPreference.full && theme.isLowRamDevice) {
    return 'Reduced · lighter animations for this device';
  }
  return '${pref.title} · ${pref.subtitle}';
}

/// Settings > Animations: full, reduced or off.
Future<void> showAnimationsPicker(BuildContext context) {
  Analytics.screen('settings_animations');
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: AppTokens.background(context),
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (sheetContext) {
      final theme = sheetContext.watch<ThemeService>();
      final ink = AppTokens.ink(sheetContext);
      return SafeArea(
        child: Center(
          heightFactor: 1,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: ContentWidth.reading),
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'Animations',
                    textAlign: TextAlign.center,
                    style: AppTextStyles.poppins(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: ink,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Less motion is calmer and easier on older phones.',
                    textAlign: TextAlign.center,
                    style: AppTextStyles.poppins(fontSize: 13, color: ink),
                  ),
                  const SizedBox(height: 16),
                  for (final pref in AnimationPreference.values) ...[
                    _PreferenceCard(
                      preference: pref,
                      selected: theme.animationPreference == pref,
                      onTap: () {
                        theme.setAnimationPreference(pref);
                        Navigator.of(sheetContext).pop();
                      },
                    ),
                    const SizedBox(height: 10),
                  ],
                ],
              ),
            ),
          ),
        ),
      );
    },
  );
}

class _PreferenceCard extends StatelessWidget {
  final AnimationPreference preference;
  final bool selected;
  final VoidCallback onTap;

  const _PreferenceCard({
    required this.preference,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final ink = AppTokens.ink(context);
    final accent = AppTokens.accent(AppPalette.blue, context);
    return Semantics(
      selected: selected,
      button: true,
      child: Material(
        color: AppTokens.surface(context),
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onTap,
          child: Container(
            constraints: const BoxConstraints(minHeight: 56),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: selected ? accent : AppTokens.cardBorder(context),
                width: selected ? 2 : 1,
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        preference.title,
                        style: AppTextStyles.poppins(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: ink,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        preference.subtitle,
                        style: AppTextStyles.poppins(fontSize: 13, color: ink),
                      ),
                    ],
                  ),
                ),
                if (selected) Icon(Icons.check_circle, color: accent),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
