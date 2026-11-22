import 'package:flutter/material.dart';

import '../services/app_update_service.dart';
import '../theme/app_tokens.dart';
import '../utils/yak_lines.dart';
import '../widgets/app_text_style.dart';
import '../widgets/content_width.dart';
import '../widgets/yak_mascot.dart';

/// Full-screen notice that a newer Bojang is in the App Store. There is no
/// way past it except updating.
class ForceUpdateScreen extends StatelessWidget {
  const ForceUpdateScreen({
    super.key,
    required this.update,
    required this.onUpdate,
  });

  final RequiredUpdate update;
  final VoidCallback onUpdate;

  @override
  Widget build(BuildContext context) {
    final tablet = Breakpoints.isTablet(context);
    return AnnotatedRegion(
      value: AppTokens.statusBar(context),
      child: Scaffold(
        backgroundColor: AppTokens.background(context),
        body: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(AppSpacing.gutter),
              child: ContentWidth(
                maxWidth: 440,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    YakMascot(
                      mood: YakMood.waving,
                      size: tablet ? 200 : 160,
                      semanticLabel: '${YakLines.name} the yak waving',
                    ),
                    const SizedBox(height: AppSpacing.xxl),
                    Text(
                      update.title ?? 'Time to update',
                      textAlign: TextAlign.center,
                      style: AppTextStyles.display(context),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    Text(
                      update.message ??
                          'A new version of Bojang is in the '
                              '${update.storeName}. Update to keep learning. '
                              'Your progress stays with you.',
                      textAlign: TextAlign.center,
                      style: AppTextStyles.body(
                        context,
                        color: AppTokens.inkSoft(context),
                      ).copyWith(fontSize: 16, height: 1.5),
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.md,
                        vertical: AppSpacing.xs + 2,
                      ),
                      decoration: BoxDecoration(
                        color: AppTokens.tint(AppColors.primary, context),
                        borderRadius: BorderRadius.circular(AppRadius.chip),
                      ),
                      child: Text(
                        update.storeVersion.isEmpty
                            ? 'You have version ${update.installedVersion}'
                            : 'Version ${update.storeVersion}  ·  '
                                'you have ${update.installedVersion}',
                        textAlign: TextAlign.center,
                        style: AppTextStyles.caption(
                          context,
                          color:
                              AppTokens.isDark(context)
                                  ? Colors.white
                                  : AppColors.primaryDeep,
                        ),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xxxl),
                    SizedBox(
                      width: double.infinity,
                      height: 56,
                      child: ElevatedButton(
                        onPressed: onUpdate,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: Colors.white,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(
                              AppRadius.button,
                            ),
                          ),
                        ),
                        child: Text(
                          'Update now',
                          style: AppTextStyles.poppins(
                            fontSize: 17,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
