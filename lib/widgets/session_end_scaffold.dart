import 'package:flutter/material.dart';

import '../theme/app_tokens.dart';
import 'app_text_style.dart';
import 'content_width.dart';

/// Layout shared by every screen after a lesson (result, streak, goal), so
/// the Continue button sits in exactly the same place on each: pinned to
/// the bottom, the same size, with a slot under it for a quieter second
/// action that keeps its height even when empty.
class SessionEndScaffold extends StatelessWidget {
  const SessionEndScaffold({
    super.key,
    required this.body,
    required this.primaryLabel,
    required this.onPrimary,
    this.primaryColor,
    this.secondaryLabel,
    this.onSecondary,
    this.overlays = const [],
    this.primaryKey,
  });

  static const double buttonHeight = 56;
  static const double secondaryHeight = 48;

  /// The screen's content; it scrolls when it doesn't fit.
  final Widget body;
  final String primaryLabel;
  final VoidCallback onPrimary;
  final Color? primaryColor;
  final String? secondaryLabel;
  final VoidCallback? onSecondary;

  /// Drawn over everything (confetti).
  final List<Widget> overlays;
  final Key? primaryKey;

  @override
  Widget build(BuildContext context) {
    final tablet = Breakpoints.isTablet(context);
    return Scaffold(
      backgroundColor: AppTokens.background(context),
      body: SafeArea(
        child: Stack(
          children: [
            Column(
              children: [
                Expanded(
                  child: ContentWidth(
                    maxWidth: ContentWidth.reading,
                    child: Center(
                      child: SingleChildScrollView(
                        padding: EdgeInsets.symmetric(
                          horizontal: 24,
                          vertical: tablet ? 48 : 24,
                        ),
                        child: body,
                      ),
                    ),
                  ),
                ),
                ContentWidth(
                  maxWidth: ContentWidth.reading,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(24, 8, 24, 12),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        SizedBox(
                          width: double.infinity,
                          height: buttonHeight,
                          child: FilledButton(
                            key: primaryKey,
                            onPressed: onPrimary,
                            style: FilledButton.styleFrom(
                              backgroundColor:
                                  primaryColor ?? AppColors.primary,
                              foregroundColor: Colors.white,
                              elevation: 0,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(
                                  AppRadius.button,
                                ),
                              ),
                            ),
                            child: Text(
                              primaryLabel,
                              style: AppTextStyles.poppins(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ),
                        SizedBox(
                          height: secondaryHeight,
                          child:
                              secondaryLabel == null
                                  ? null
                                  : Center(
                                    child: TextButton(
                                      onPressed: onSecondary,
                                      child: Text(
                                        secondaryLabel!,
                                        style: AppTextStyles.poppins(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w600,
                                          color: AppTokens.inkSoft(context),
                                        ),
                                      ),
                                    ),
                                  ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            ...overlays,
          ],
        ),
      ),
    );
  }
}
