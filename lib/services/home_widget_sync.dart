import 'dart:async';
import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:home_widget/home_widget.dart';

import '../utils/widget_snapshot.dart';
import 'progress_service.dart';

/// Keeps the home-screen widget (plan #25) in step with the streak.
///
/// Listens to [ProgressService] and writes a [WidgetSnapshot] with
/// `home_widget` whenever the streak, today's practice or the freeze state
/// changes. Android draws it with `BojangStreakWidget` (RemoteViews). The
/// iOS WidgetKit extension is not in the Xcode project yet (it needs an App
/// ID, an App Group and a profile in CI; see docs/IOS_WIDGET_SETUP.md), so
/// on iOS the data is written to the App Group defaults and nothing reads
/// it until the extension ships. Every call is best effort: no widget
/// installed, or no native side, is fine.
class HomeWidgetSync {
  HomeWidgetSync._();

  static final HomeWidgetSync instance = HomeWidgetSync._();

  /// Must match the App Group in docs/IOS_WIDGET_SETUP.md.
  static const String iosAppGroup = 'group.com.bojang.app.widget';
  static const String iosWidgetKind = 'BojangStreakWidget';
  static const String androidProvider =
      'com.projectmira.bojang.BojangStreakWidget';

  ProgressService? _progress;
  String? _lastWritten;
  bool _groupSet = false;

  /// Starts following [progress]. Safe to call more than once.
  void attach(ProgressService progress) {
    if (identical(_progress, progress)) return;
    _progress?.removeListener(_onChange);
    _progress = progress;
    progress.addListener(_onChange);
    _onChange();
  }

  void _onChange() {
    final progress = _progress;
    if (progress == null) return;
    final now = DateTime.now();
    final earnBack = progress.earnBackOn(now);
    unawaited(
      write(
        WidgetSnapshot.build(
          now: now,
          streak: progress.currentStreak,
          lastPlayDate: progress.lastPlayDate,
          frozenDates: progress.frozenDates,
          earnBackStreak: earnBack?.streak,
        ),
      ),
    );
  }

  /// Writes [snapshot] and asks the widgets to redraw. Skips a write that
  /// would change nothing.
  Future<void> write(WidgetSnapshot snapshot) async {
    if (kIsWeb || !(Platform.isAndroid || Platform.isIOS)) return;
    final data = snapshot.toWidgetData();
    final signature = data.toString();
    if (signature == _lastWritten) return;
    try {
      if (Platform.isIOS && !_groupSet) {
        await HomeWidget.setAppGroupId(iosAppGroup);
        _groupSet = true;
      }
      for (final entry in data.entries) {
        await HomeWidget.saveWidgetData<Object>(entry.key, entry.value);
      }
      await HomeWidget.updateWidget(
        qualifiedAndroidName: androidProvider,
        iOSName: iosWidgetKind,
      );
      _lastWritten = signature;
    } catch (e) {
      debugPrint('Home widget not updated: $e');
    }
  }
}
