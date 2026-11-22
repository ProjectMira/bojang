import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../screens/force_update_screen.dart';
import '../services/analytics.dart';
import '../services/app_update_service.dart';

/// Covers the whole app with [ForceUpdateScreen] while an update is required:
/// the App Store has a newer version (iOS), or the build is below the server
/// config's minimum (iOS and Android).
///
/// It sits above the navigator (via `MaterialApp.builder`), so no route,
/// dialog or start-up redirect can escape it. The app underneath keeps its
/// state but takes no taps, focus or screen-reader attention.
///
/// The store is asked on launch and again when the app returns to the
/// foreground, at most hourly, or every time while the notice is up.
class UpdateGate extends StatefulWidget {
  const UpdateGate({
    super.key,
    required this.child,
    this.service,
    this.openUrl,
  });

  final Widget child;

  /// Defaults to a real [AppUpdateService].
  final AppUpdateService? service;

  /// Defaults to opening the URL outside the app.
  final Future<bool> Function(Uri uri)? openUrl;

  static const Duration recheckAfter = Duration(hours: 1);

  @override
  State<UpdateGate> createState() => _UpdateGateState();
}

class _UpdateGateState extends State<UpdateGate> with WidgetsBindingObserver {
  late final AppUpdateService _service = widget.service ?? AppUpdateService();
  RequiredUpdate? _update;
  DateTime? _lastCheck;
  bool _checking = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _check();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) return;
    final last = _lastCheck;
    final stale =
        last == null ||
        DateTime.now().difference(last) >= UpdateGate.recheckAfter;
    if (_update != null || stale) _check();
  }

  Future<void> _check() async {
    if (_checking) return;
    _checking = true;
    try {
      final update = await _service.check();
      _lastCheck = DateTime.now();
      if (!mounted) return;
      if (update != null &&
          (_update?.storeVersion != update.storeVersion ||
              _update?.reason != update.reason)) {
        Analytics.track('force_update_shown', {
          'installed_version': update.installedVersion,
          'store_version': update.storeVersion,
          'reason': update.reason.name,
        });
      }
      setState(() => _update = update);
    } finally {
      _checking = false;
    }
  }

  Future<void> _openStore() async {
    final update = _update;
    if (update == null) return;
    final open =
        widget.openUrl ??
        (Uri uri) => launchUrl(uri, mode: LaunchMode.externalApplication);
    var opened = false;
    for (final uri in update.storeUris) {
      try {
        if (await open(uri)) {
          opened = true;
          break;
        }
      } catch (e) {
        debugPrint('Could not open $uri: $e');
      }
    }
    Analytics.track('force_update_tapped', {
      'installed_version': update.installedVersion,
      'store_version': update.storeVersion,
      'reason': update.reason.name,
      'opened': opened,
    });
  }

  @override
  Widget build(BuildContext context) {
    final update = _update;
    final blocked = update != null;
    return Stack(
      fit: StackFit.expand,
      children: [
        ExcludeFocus(
          excluding: blocked,
          child: ExcludeSemantics(
            excluding: blocked,
            child: IgnorePointer(ignoring: blocked, child: widget.child),
          ),
        ),
        if (update != null)
          Positioned.fill(
            child: ForceUpdateScreen(update: update, onUpdate: _openStore),
          ),
      ],
    );
  }
}
