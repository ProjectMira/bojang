import 'package:flutter/material.dart';

import '../services/analytics.dart';
import '../services/learner_profile.dart';

/// "Show my city on the leaderboard" (off by default). Turning it on looks
/// up the city on the phone from approximate location (asking for the same
/// approximate-location permission as Settings › Privacy) and sends only the
/// city and country; turning it off deletes them on the server. Used in the
/// name + picture sheet and in Settings › Privacy.
class ShowPlaceSwitch extends StatefulWidget {
  const ShowPlaceSwitch({super.key, required this.source});

  /// Where it is (profile_setup / settings), for analytics.
  final String source;

  @override
  State<ShowPlaceSwitch> createState() => _ShowPlaceSwitchState();
}

class _ShowPlaceSwitchState extends State<ShowPlaceSwitch> {
  bool _busy = false;

  Future<void> _toggle(bool on) async {
    setState(() => _busy = true);
    final result = await LearnerProfile.instance.setShowPlace(on);
    Analytics.track('leaderboard_place_toggled', {
      'enabled': on,
      'source': widget.source,
      'result': result.name,
    });
    if (!mounted) return;
    setState(() => _busy = false);
    final message = switch (result) {
      PlaceResult.ok => null,
      PlaceResult.noLocation =>
        "Couldn't find your city. Allow approximate location for Bojang in "
            'your device Settings.',
      PlaceResult.offline => "You're offline. Try again with a connection.",
    };
    if (message != null) {
      ScaffoldMessenger.maybeOf(
        context,
      )?.showSnackBar(SnackBar(content: Text(message)));
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: LearnerProfile.instance,
      builder:
          (context, _) => Switch.adaptive(
            key: Key('show-place-switch-${widget.source}'),
            value: LearnerProfile.instance.showPlace,
            onChanged: _busy ? null : _toggle,
          ),
    );
  }
}

/// The subtitle under the switch: the city others see, or what it does.
String showPlaceSubtitle(LearnerProfile profile) {
  if (profile.showPlace && profile.placeHidden) {
    return 'Hidden from others while we review reports';
  }
  if (profile.showPlace && profile.place != null) {
    return 'Others see: ${profile.place}';
  }
  return 'City and country from your approximate location (about 10 km). '
      'Off unless you turn it on.';
}
