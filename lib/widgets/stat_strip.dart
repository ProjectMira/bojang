import 'package:flutter/material.dart';
import '../theme/app_tokens.dart';
import 'stat_chip.dart';

class StatStripItem {
  final IconData icon;
  final String value;
  final String label;
  final Color color;

  const StatStripItem({
    required this.icon,
    required this.value,
    required this.label,
    required this.color,
  });
}

/// Single-container, one-line stats summary shown at the top of Home.
/// Tapping it jumps to the Streak tab.
class StatStrip extends StatelessWidget {
  final List<StatStripItem> items;
  final VoidCallback? onTap;

  const StatStrip({super.key, required this.items, this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppTokens.surface(context),
      borderRadius: BorderRadius.circular(AppRadius.card),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadius.card),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppRadius.card),
            border: Border.all(color: AppTokens.cardBorder(context)),
            boxShadow: AppTokens.shadow(context),
          ),
          child: Row(
            children: [
              for (var i = 0; i < items.length; i++) ...[
                if (i > 0)
                  Container(
                    width: 1,
                    height: 32,
                    margin: const EdgeInsets.symmetric(horizontal: 12),
                    color: AppTokens.divider(context),
                  ),
                Expanded(
                  child: StatChip(
                    icon: items[i].icon,
                    value: items[i].value,
                    label: items[i].label,
                    color: items[i].color,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
