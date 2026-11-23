import 'dart:io';

import 'package:flutter/material.dart';

import '../services/analytics.dart';
import '../services/offline_mode.dart';
import '../theme/app_tokens.dart';
import '../theme/motion.dart';
import 'app_text_style.dart';

/// Home's offline line (plan item #23). Offline: "You're offline" with the
/// lessons ready to play and a note that progress syncs later. Online with
/// lessons prefetched: a quiet "2 lessons ready offline". Hidden otherwise,
/// and whenever the `offline_mode` kill switch is off.
class OfflineLessonsBanner extends StatefulWidget {
  const OfflineLessonsBanner({
    super.key,
    this.online,
    this.ready,
    this.pending,
    this.enabled,
  });

  // Injectable for tests; default to OfflineMode.instance.
  final ValueNotifier<bool>? online;
  final ValueNotifier<int>? ready;
  final ValueNotifier<int>? pending;
  final bool? enabled;

  @override
  State<OfflineLessonsBanner> createState() => _OfflineLessonsBannerState();
}

class _OfflineLessonsBannerState extends State<OfflineLessonsBanner> {
  late final ValueNotifier<bool> _online =
      widget.online ?? OfflineMode.instance.online;
  late final ValueNotifier<int> _ready =
      widget.ready ?? OfflineMode.instance.prefetcher.ready;
  late final ValueNotifier<int> _pending =
      widget.pending ?? OfflineMode.instance.queue.pending;
  String? _shown;

  bool get _enabled => widget.enabled ?? OfflineMode.instance.enabled;

  @override
  void initState() {
    super.initState();
    if (widget.ready == null && _enabled) {
      // Loads the stored sessions so the count is right on first paint.
      OfflineMode.instance.prefetcher.activeLevel().catchError((_) => null);
    }
  }

  static String lessonsReady(int n) =>
      n == 1 ? '1 lesson ready offline' : '$n lessons ready offline';

  @override
  Widget build(BuildContext context) {
    final motion = Motion.of(context);
    return AnimatedBuilder(
      animation: Listenable.merge([_online, _ready, _pending]),
      builder: (context, _) {
        final online = _online.value;
        final ready = _ready.value;
        final pending = _pending.value;
        final visible = _enabled && (!online || ready > 0);
        Widget child = const SizedBox.shrink(key: ValueKey('none'));
        if (visible) {
          final state = online ? 'ready' : 'offline';
          if (_shown != state) {
            _shown = state;
            Analytics.track('offline_banner_viewed', {
              'state': state,
              'lessons_ready': ready,
              'pending': pending,
            });
          }
          child = _card(
            context,
            online: online,
            ready: ready,
            pending: pending,
          );
        }
        return AnimatedSwitcher(
          duration: motion.scale(const Duration(milliseconds: 220)),
          switchInCurve: Curves.easeOut,
          switchOutCurve: Curves.easeIn,
          child: child,
        );
      },
    );
  }

  Widget _card(
    BuildContext context, {
    required bool online,
    required int ready,
    required int pending,
  }) {
    final accent = online ? AppColors.green : AppColors.orange;
    final title = online ? lessonsReady(ready) : "You're offline";
    final details = <String>[
      if (!online)
        ready > 0 ? lessonsReady(ready) : 'No lessons saved for offline yet',
      if (pending > 0)
        pending == 1
            ? '1 result will sync when you’re back online'
            : '$pending results will sync when you’re back online',
    ];
    return Padding(
      key: ValueKey('offline-$online'),
      padding: const EdgeInsets.only(bottom: AppSpacing.xl),
      child: Semantics(
        liveRegion: true,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.lg,
            vertical: AppSpacing.md,
          ),
          decoration: BoxDecoration(
            color: AppTokens.tint(accent, context),
            borderRadius: BorderRadius.circular(AppRadius.card),
          ),
          child: Row(
            children: [
              Icon(
                online ? Icons.download_done_rounded : Icons.cloud_off_rounded,
                color: AppTokens.textOnTint(accent, context),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: AppTextStyles.poppins(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: AppTokens.ink(context),
                      ),
                    ),
                    for (final line in details) ...[
                      const SizedBox(height: 2),
                      Text(
                        line,
                        style: AppTextStyles.poppins(
                          fontSize: 13,
                          color: AppTokens.inkSoft(context),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// A lesson picture that plays from the offline cache when it was
/// prefetched, else from the network. Drop-in for `Image.network`.
Widget offlineImage(
  String url, {
  double? height,
  BoxFit? fit,
  ImageLoadingBuilder? loadingBuilder,
  ImageErrorWidgetBuilder? errorBuilder,
}) {
  final File? local = OfflineMode.instance.media.fileForSync(url);
  if (local != null && local.existsSync()) {
    return Image.file(
      local,
      height: height,
      fit: fit,
      errorBuilder: errorBuilder,
    );
  }
  return Image.network(
    url,
    height: height,
    fit: fit,
    loadingBuilder: loadingBuilder,
    errorBuilder: errorBuilder,
  );
}
